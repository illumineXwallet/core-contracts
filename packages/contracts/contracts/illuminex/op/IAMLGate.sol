// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IAMLGate {
    enum DepositState {
        Initiated,
        Approved,
        Refunded
    }

    event DepositInitiated(uint256 indexed depositSeqId, bytes encodedParams);
    event DepositRefunded(uint256 indexed depositSeqId);
    event DepositApproved(uint256 indexed depositSeqId);

    function proxyPass(address token, uint256 amount, bytes memory encodedParams) external payable;

    function refund(uint256 depositSeqId) external;
    function approveDeposit(uint256 depositSeqId, bytes calldata encodedParams) external;
}
