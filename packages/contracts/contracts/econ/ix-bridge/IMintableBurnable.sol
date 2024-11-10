// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IMintableBurnable {
    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;
}
