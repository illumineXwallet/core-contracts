// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../illuminex/op/celer/safeguard/Ownable.sol";

contract FeesCollector is Ownable {
    uint256 public feesCollected;

    event FeesCollected(address indexed to, uint256 amount);
    event FeesDeposited(uint256 amount);

    function _collectFees(address payable to, uint256 amount) internal {
        require(amount <= feesCollected, "Insufficient fees collected");

        feesCollected -= amount;
        to.transfer(amount);

        emit FeesCollected(to, amount);
    }

    function collectFees(address payable to, uint256 amount) public onlyOwner {
        _collectFees(to, amount);
    }

    function _depositFees(uint256 amount) internal {
        feesCollected += amount;
        emit FeesDeposited(amount);
    }
}
