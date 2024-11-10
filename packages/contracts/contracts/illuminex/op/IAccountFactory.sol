// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IAccountFactory {
    function deployedAccounts(address account) external view returns (bool);
    function createAccount(address accountOwner, bytes32 salt) external;
}
