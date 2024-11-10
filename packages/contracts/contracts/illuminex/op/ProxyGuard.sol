// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./SapphireEndpoint.sol";

contract ProxyGuard {
    SapphireEndpoint public immutable ep;

    constructor(address payable _ep) {
        ep = SapphireEndpoint(_ep);
    }

    function proxyPass(address token, uint256 amount, bytes memory encodedParams) public payable {
        SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);
        SafeERC20.safeIncreaseAllowance(IERC20(token), address(ep), amount);

        ep.proxyPass{value: msg.value}(token, amount, encodedParams);
    }
}
