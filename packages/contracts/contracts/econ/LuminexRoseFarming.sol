// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LuminexRoseFarming is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardTime;
        uint256 accROSEPerShare;
        uint256 lockPeriod;
    }

    struct Position {
        bool exists;
        uint256 pid;
        uint256 amount;
        address user;
        uint256 unlockedAt;
    }

    uint256 public rosePerSecond;
    uint256 public BONUS_MULTIPLIER = 1;

    PoolInfo[] public poolInfo;

    mapping(bytes32 => Position) public positions;
    mapping(address => uint256) public positionsPerUser;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(uint256 => uint256) public depositedTokens;

    uint256 public totalAllocPoint = 0;
    uint256 public startTime;

    uint256 public totalReward;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount, bytes32 depositId);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount, bytes32 indexed depositId);
    event Harvest(address indexed user, uint256 indexed pid, uint256 reward);

    constructor(
        uint256 _rosePerSecond,
        uint256 _startTime
    ) {
        rosePerSecond = _rosePerSecond;
        startTime = _startTime;
    }

    function withdrawRewardsPool(address payable to, uint256 amount) public onlyOwner {
        to.transfer(amount);
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        uint256 _lockPeriod,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardTime = block.timestamp > startTime ? block.timestamp : startTime;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({lpToken: _lpToken, allocPoint: _allocPoint, lastRewardTime: lastRewardTime, accROSEPerShare: 0, lockPeriod: _lockPeriod})
        );
    }

    receive() external payable {}

    function set(
        uint256 _pid,
        uint256 _allocPoint,
        uint256 _lockPeriod,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (_pid != 0) {
            poolInfo[_pid].lockPeriod = _lockPeriod;
        }
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(_allocPoint);
        }
    }

    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    function pendingROSE(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accROSEPerShare = pool.accROSEPerShare;
        uint256 lpSupply = depositedTokens[_pid];
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
            uint256 reward = multiplier.mul(rosePerSecond).mul(pool.allocPoint).div(totalAllocPoint);
            accROSEPerShare = accROSEPerShare.add(reward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accROSEPerShare).div(1e12).sub(user.rewardDebt);
    }

    function _harvest(uint256 _pid) private {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount > 0, "harvest: can't harvest");

        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accROSEPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0 && address(this).balance >= pending) {
            payable(msg.sender).transfer(pending);
        }

        user.rewardDebt = user.amount.mul(pool.accROSEPerShare).div(1e12);
        emit Harvest(msg.sender, _pid, pending);
    }

    function harvest(uint256 _pid) external {
        _harvest(_pid);
    }

    function harvestMultiple(uint256[] calldata _pids) external {
        for (uint i = 0; i < _pids.length; i++) {
            _harvest(_pids[i]);
        }
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        uint256 lpSupply = depositedTokens[_pid];
        if (lpSupply == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }

        uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
        uint256 reward = multiplier.mul(rosePerSecond).mul(pool.allocPoint).div(totalAllocPoint);

        if (totalReward + reward > address(this).balance) {
            reward = address(this).balance - totalReward;
        }

        totalReward += reward;

        pool.accROSEPerShare = pool.accROSEPerShare.add(reward.mul(1e12).div(lpSupply));
        pool.lastRewardTime = block.timestamp;
    }

    function computeNextDepositIdFor(address user) public view returns (bytes32) {
        return keccak256(abi.encodePacked(user, positionsPerUser[user] + 1));
    }

    function deposit(uint256 _pid, uint256 _amount) public payable {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accROSEPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0 && address(this).balance >= pending) {
                payable(msg.sender).transfer(pending);
            }
        }

        bytes32 _depositId = computeNextDepositIdFor(msg.sender);
        positionsPerUser[msg.sender]++;

        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }

        positions[_depositId] = Position(true, _pid, _amount, msg.sender, block.timestamp + pool.lockPeriod);

        depositedTokens[_pid] += _amount;
        user.rewardDebt = user.amount.mul(pool.accROSEPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount, _depositId);
    }

    function withdraw(bytes32 _depositId, uint256 _amount) public {
        Position storage pos = positions[_depositId];
        require(pos.exists && pos.amount >= _amount, "Invalid position");
        require(block.timestamp >= pos.unlockedAt, "Time lock");

        uint256 _pid = pos.pid;
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accROSEPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0 && address(this).balance >= pending) {
            payable(msg.sender).transfer(pending);
        }

        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pos.amount = pos.amount.sub(_amount);
            IERC20(pool.lpToken).safeTransfer(msg.sender, _amount);
        }

        depositedTokens[_pid] -= _amount;
        user.rewardDebt = user.amount.mul(pool.accROSEPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount, _depositId);
    }
}
