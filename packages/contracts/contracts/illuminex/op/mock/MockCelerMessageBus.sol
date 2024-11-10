// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

contract MockCelerMessageBus {
    event MockCelerMessage();

    function calcFee(bytes calldata) public pure returns (uint256) {
        return 1;
    }

    function sendMessage(address, uint256, bytes calldata) public payable {
        emit MockCelerMessage();
    }
}
