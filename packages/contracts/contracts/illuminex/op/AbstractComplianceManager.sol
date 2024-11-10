// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

abstract contract AbstractComplianceManager {
    event ChangeComplianceManager(address newManager, address oldManager);

    address public complianceManager;

    constructor() {
        complianceManager = msg.sender;
    }

    modifier onlyComplianceManager() {
        require(msg.sender == complianceManager, "Not a compliance manager");
        _;
    }

    function setComplianceManager(address newManager) public onlyComplianceManager {
        emit ChangeComplianceManager(newManager, complianceManager);
        complianceManager = newManager;
    }
}
