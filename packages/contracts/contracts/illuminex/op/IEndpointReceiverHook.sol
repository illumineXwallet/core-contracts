// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IEndpointReceiverHook {
    function hook(address asset, uint256 value, bytes memory data) external;
}
