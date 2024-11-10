// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../../../../confidentialERC20/PrivateWrapperFactory.sol";
import "./IVaultBitcoinWalletHook.sol";
import "../../../../op/ILuminexAccount.sol";

contract BtcToPrivateBtcHook is IVaultBitcoinWalletHook {
    using SafeERC20 for IERC20;

    PrivateWrapperFactory public immutable privateFactory;
    IERC20 public immutable btcToken;

    constructor(address _btcToken, address payable _privateFactory) {
        btcToken = IERC20(_btcToken);
        privateFactory = PrivateWrapperFactory(_privateFactory);
    }

    function hook(uint64 value, bytes memory data) public override {
        (address _to) = abi.decode(data, (address));

        btcToken.safeIncreaseAllowance(address(privateFactory), value);
        privateFactory.wrap(address(btcToken), value, _to);
    }

    function resolveOriginalAddress(bytes memory data) public view override returns (address) {
        (address _to) = abi.decode(data, (address));
        return ILuminexAccount(_to).owner();
    }
}