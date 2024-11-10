// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./ICrossChainVault.sol";

contract CrossChainVault is ICrossChainVault, Ownable {
    using SafeERC20 for IERC20;

    struct SetAllowedAssetParams {
        address asset;
        bool isAllowed;
    }

    mapping(address => mapping(address => uint256)) public lockedAssets;
    mapping(address => bool) public allowedAssets;

    event Lock(address indexed user, address indexed asset, uint256 amount);
    event Unlock(address indexed user, address indexed asset, uint256 amount);
    event SetAllowedAsset(address indexed asset, bool isAllowed);

    function setAllowedAssets(SetAllowedAssetParams[] calldata assets) public onlyOwner {
        for (uint i = 0; i < assets.length; i++) {
            emit SetAllowedAsset(assets[i].asset, assets[i].isAllowed);
            allowedAssets[assets[i].asset] = assets[i].isAllowed;
        }
    }

    receive() external payable {}

    function lock(address asset, uint256 amount) public override returns (uint256) {
        require(allowedAssets[asset], "Asset is not allowed");

        uint256 amountAfterFee = amount;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        lockedAssets[msg.sender][asset] += amountAfterFee;
        emit Lock(msg.sender, asset, amount);

        return amountAfterFee;
    }

    function unlock(address asset, uint256 amount) public override {
        require(lockedAssets[msg.sender][asset] >= amount, "Insufficient locked balance");

        lockedAssets[msg.sender][asset] -= amount;
        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Unlock(msg.sender, asset, amount);
    }
}
