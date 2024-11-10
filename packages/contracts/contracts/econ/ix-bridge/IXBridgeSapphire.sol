// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./IXBridge.sol";

contract IXBridgeSapphire is IXBridge {
    using SafeERC20 for IERC20;

    bool public isEnabled = false;

    constructor(address _messageBus, address _ixToken, bool isEthereum) IXBridge(
    _messageBus,
    _ixToken,
        isEthereum ? 1 : 56
    ) {}

    function enable() public onlyOwner {
        isEnabled = true;
    }

    function _consumeTokens(address sender, uint256 amount) virtual internal override {
        if (!isEnabled) {
            require(msg.sender == owner(), "Not enabled yet");
        }

        ixToken.safeTransferFrom(sender, address(this), amount);
    }

    function _processIncomingMessage(address sender, uint256 amount) virtual internal override {
        ixToken.safeTransfer(sender, amount);
    }
}
