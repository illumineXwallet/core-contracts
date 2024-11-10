// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../../confidentialERC20/PrivateWrapperFactory.sol";

contract DepositVault is Ownable {
    using SafeERC20 for IERC20;
    using Address for address;

    address public taker;
    PrivateWrapperFactory public immutable wrapperFactory;

    event Deposit(bytes32 indexed id, address token, uint256 amount);

    uint256 public depositCost;

    constructor(address _taker, address payable _factory) {
        taker = _taker;
        wrapperFactory = PrivateWrapperFactory(_factory);
    }

    function setTaker(address _taker) public onlyOwner {
        taker = _taker;
    }

    function setDepositCost(uint256 _depositCost) public onlyOwner {
        depositCost = _depositCost;
    }

    function computeId(address token, uint256 amount, bytes32 entropy) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(token, amount, entropy));
    }

    function deposit(bytes32 id, address token, uint256 amount) public payable {
        require(msg.value >= depositCost, "Insufficient deposit cost value");

        emit Deposit(id, token, amount);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    function unwrapAndCall(address target, address token, bytes calldata data, uint256 value) public {
        require(msg.sender == taker, "Not a taker");

        address _originalToken = wrapperFactory.tokenByWrapper(token);
        IERC20(token).approve(address(wrapperFactory), type(uint256).max);
        wrapperFactory.unwrapERC20(token, IERC20(token).balanceOf(address(this)), address(this));

        IERC20(_originalToken).approve(target, type(uint256).max);
        target.functionCallWithValue(data, value);
    }

    function call(address target, address token, bytes calldata data, uint256 value) public {
        require(msg.sender == taker, "Not a taker");

        IERC20(token).approve(target, type(uint256).max);
        target.functionCallWithValue(data, value);
    }

    receive() external payable {}
}
