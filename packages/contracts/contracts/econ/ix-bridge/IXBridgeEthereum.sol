// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./IXBridge.sol";
import "./IMintableBurnable.sol";

contract IXBridgeEthereum is IXBridge {
    using SafeERC20 for IERC20;

    constructor(address _messageBus, address _ixToken) IXBridge(
    _messageBus,
    _ixToken,
    23294
    ) {}

    function _consumeTokens(address sender, uint256 amount) virtual internal override {
        ixToken.safeTransferFrom(sender, address(this), amount);
        IMintableBurnable(address(ixToken)).burn(amount);
    }

    function _processIncomingMessage(address sender, uint256 amount) virtual internal override {
        IMintableBurnable(address(ixToken)).mint(sender, amount);
    }
}
