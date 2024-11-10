// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./IComplianceManager.sol";
import "./AbstractComplianceManager.sol";

contract ComplianceManager is Ownable, IComplianceManager, AbstractComplianceManager {
    struct ComplianceRecord {
        bool exists;
        uint256 timestamp;
        string _type;
        bytes data;
    }

    event RevealData(bytes32 indexed dataKey);

    mapping(string => mapping(bytes32 => ComplianceRecord)) private _records;
    mapping(string => mapping(bytes32 => bool)) private _revealedRecords;

    mapping(string => mapping(address => bool)) public allowedRecordsPushers;

    function revealRecord(string memory _type, bytes32 recordId) public onlyComplianceManager {
        require(!_revealedRecords[_type][recordId], "Already revealed");
        require(_records[_type][recordId].exists, "Invalid record ID");

        _revealedRecords[_type][recordId] = true;
        emit RevealData(recordId);
    }

    function fetchRevealedRecord(
        string memory _type,
        bytes32 recordId
    ) public view onlyComplianceManager returns (ComplianceRecord memory) {
        require(_revealedRecords[_type][recordId], "Not revealed");
        return _records[_type][recordId];
    }

    function pushRecord(string memory _type, bytes memory data) public override returns (bytes32 recordId) {
        require(allowedRecordsPushers[_type][msg.sender], "Not a pusher");

        recordId = keccak256(abi.encodePacked(block.timestamp, _type, data));

        ComplianceRecord storage _cm = _records[_type][recordId];
        _cm.exists = true;
        _cm.timestamp = block.timestamp;
        _cm.data = data;
        _cm._type = _type;
    }

    function setAllowedPusher(address newPusher, string memory _type) public onlyOwner {
        allowedRecordsPushers[_type][newPusher] = !allowedRecordsPushers[_type][newPusher];
    }
}
