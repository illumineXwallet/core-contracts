// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IAMLGate.sol";
import "./MultichainEndpoint.sol";
import "./AbstractComplianceManager.sol";

contract AMLGate is Ownable, IAMLGate, AbstractComplianceManager, FeesCollector {
    using SafeERC20 for IERC20;

    struct OFACEntry {
        address addr;
        bool isOfacListed;
    }

    struct Deposit {
        bool exists;

        DepositState state;
        address refundTo;

        address token;
        uint256 amount;
        bytes32 encodedParamsHash;

        uint256 nativeValue;
    }

    event UpdateOFACList(OFACEntry[] list);
    event AMLVerifierToggle(address indexed amlVerifier, bool isSet);

    mapping(address => bool) public ofacBlocklist;
    mapping(bytes32 => bool) public usedDataHashes;
    mapping(uint256 => Deposit) public deposits;

    mapping(address => bool) public amlVerifiers;

    uint256 public depositIdCounter;
    uint256 public amlVerificationCost;

    MultichainEndpoint public immutable multichainEndpoint;

    constructor(address payable _multichainEndpoint) {
        multichainEndpoint = MultichainEndpoint(_multichainEndpoint);
    }

    function _transferTokensTo(address _to, address _token, uint256 _amount) internal {
        if (_token == multichainEndpoint.nativeWrapper()) {
            payable(_to).transfer(_amount);
        } else {
            IERC20(_token).safeTransfer(_to, _amount);
        }
    }

    function proxyPass(address token, uint256 amount, bytes memory encodedParams) public override payable {
        require(msg.value >= amlVerificationCost, "Insufficient funds for AML verification");
        _depositFees(amlVerificationCost);

        require(!ofacBlocklist[msg.sender], "OFAC prohibited");

        bytes32 dataHash = keccak256(abi.encodePacked(token, amount, encodedParams, msg.sender));
        require(!usedDataHashes[dataHash], "Hash collision");

        usedDataHashes[dataHash] = true;

        uint256 msgValue = msg.value - amlVerificationCost;
        if (token == multichainEndpoint.nativeWrapper()) {
            require(msgValue > amount, "Invalid amount");
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        uint256 depositId = depositIdCounter++;
        deposits[depositId] = Deposit(true, DepositState.Initiated, msg.sender, token, amount, keccak256(encodedParams), msgValue);

        emit DepositInitiated(depositId, encodedParams);
    }

    function refund(uint256 depositSeqId) public override {
        Deposit storage _deposit = deposits[depositSeqId];
        require(_deposit.state == DepositState.Initiated && _deposit.exists, "Not allowed");
        require(msg.sender == _deposit.refundTo, "Invalid sender");

        _deposit.state = DepositState.Refunded;
        emit DepositRefunded(depositSeqId);

        uint256 amount = _deposit.amount;
        if (_deposit.token == multichainEndpoint.nativeWrapper()) {
            amount = _deposit.nativeValue;
        }

        _transferTokensTo(_deposit.refundTo, _deposit.token, amount);
    }

    function approveDeposit(uint256 depositSeqId, bytes calldata encodedParams) public override {
        Deposit storage _deposit = deposits[depositSeqId];
        require(_deposit.state == DepositState.Initiated && _deposit.exists, "Not allowed");
        require(_deposit.encodedParamsHash == keccak256(encodedParams), "Invalid hash");
        require(amlVerifiers[msg.sender], "Invalid sender");

        _deposit.state = DepositState.Approved;
        emit DepositApproved(depositSeqId);

        if (_deposit.token != multichainEndpoint.nativeWrapper()) {
            IERC20(_deposit.token).safeIncreaseAllowance(address(multichainEndpoint), _deposit.amount);
        }

        bytes memory _callData = abi.encodeCall(MultichainEndpoint.proxyPass, (
            _deposit.token,
            _deposit.amount,
            encodedParams
        ));

        (bool success,) = address(multichainEndpoint).call{value: _deposit.nativeValue}(
            abi.encodePacked(_callData, _deposit.refundTo)
        );
        require(success, "ProxyPass failed");

        _collectFees(payable(msg.sender), feesCollected);
    }

    function updateOFACList(OFACEntry[] memory list) public onlyComplianceManager {
        emit UpdateOFACList(list);

        for (uint i = 0; i < list.length; i++) {
            ofacBlocklist[list[i].addr] = list[i].isOfacListed;
        }
    }

    function toggleAmlVerifier(address _verifier) public onlyComplianceManager {
        emit AMLVerifierToggle(_verifier, !amlVerifiers[_verifier]);
        amlVerifiers[_verifier] = !amlVerifiers[_verifier];
    }

    function setAmlVerificationCost(uint256 cost) public onlyComplianceManager {
        amlVerificationCost = cost;
    }

    receive() external payable {}
}
