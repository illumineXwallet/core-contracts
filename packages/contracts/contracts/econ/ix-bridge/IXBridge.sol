// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../illuminex/op/celer/safeguard/Ownable.sol";
import "../../illuminex/op/celer/message/framework/MessageApp.sol";

abstract contract IXBridge is MessageApp, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable ixToken;

    address public counterEndpoint;
    uint256 public nonce;

    uint64 public immutable counterChainId;

    uint256 public relayingFee;

    event BridgeOut(address indexed sender, uint256 amount);
    event BridgeIn(address indexed sender, uint256 amount);

    constructor(address _messageBus, address _ixToken, uint64 _counterChainId) MessageApp(_messageBus) {
        ixToken = IERC20(_ixToken);
        counterChainId = _counterChainId;
    }

    function setRelayingFee(uint256 newFee) public onlyOwner {
        relayingFee = newFee;
    }

    function setBridgeReceiver(address _receiver) public onlyOwner {
        require(counterEndpoint == address(0));
        counterEndpoint = _receiver;
    }

    function withdrawFee(address payable to) public onlyOwner {
        to.transfer(address(this).balance);
    }

    function bridge(uint256 amount) public payable {
        require(msg.value >= relayingFee, "Insufficient fee");

        _consumeTokens(msg.sender, amount);

        bytes memory payload = abi.encode(nonce++, msg.sender, amount);
        sendMessage(counterEndpoint, counterChainId, payload, IMessageBus(messageBus).calcFee(payload));

        emit BridgeOut(msg.sender, amount);
    }

    function _consumeTokens(address sender, uint256 amount) virtual internal;

    function _processIncomingMessage(address sender, uint256 amount) virtual internal;

    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        address
    ) external payable virtual override onlyMessageBus returns (ExecutionStatus) {
        require(_sender == counterEndpoint && _srcChainId == counterChainId, "Invalid sender");

        (, address sender, uint256 amount) = abi.decode(_message, (uint256, address, uint256));
        _processIncomingMessage(sender, amount);

        emit BridgeIn(sender, amount);

        return ExecutionStatus.Success;
    }
}
