// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../illuminex/op/celer/safeguard/Ownable.sol";
import "./PrivateWrapper.sol";
import '../interfaces/IWROSE.sol';

contract PrivateWrapperFactory {
    using SafeERC20 for ERC20;

    mapping(address => PrivateWrapper) private _wrappers;
    mapping(address => address) private _tokenByWrapper;

    event Wrap(address indexed token, address indexed wrapper, uint256 amount);
    event Unwrap(address indexed token, address indexed wrapper, uint256 amount);

    receive() external payable {}

    function wrappers(address _token) public view returns (PrivateWrapper) {
        return _wrappers[_token];
    }

    function tokenByWrapper(address _wrapper) public view returns (address) {
        return _tokenByWrapper[_wrapper];
    }

    function createWrapper(address token) public returns (address) {
        PrivateWrapper wrapper = wrappers(token);
        if (address(wrapper) == address(0)) {
            wrapper = new PrivateWrapper(ERC20(token));
            _wrappers[token] = wrapper;
            _wrappers[address(wrapper)] = wrapper;
            _tokenByWrapper[address(wrapper)] = token;
        }

        return address(wrapper);
    }

    function _wrap(address token, uint256 amount, address to) private {
        PrivateWrapper wrapper = PrivateWrapper(createWrapper(token));

        ERC20(token).approve(address(wrapper), amount);
        wrapper.wrap(amount, to);
        emit Wrap(token, address(wrapper), amount);
    }

    function wrap(address token, uint256 amount, address to) public payable {
        if (tokenByWrapper(token) != address(0)) {
            return;
        }

        ERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _wrap(token, amount, to);
    }

    function wrapERC20(address token, uint256 amount, address to) public {
        if (tokenByWrapper(token) != address(0)) {
            return;
        }

        ERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _wrap(token, amount, to);
    }

    function _unwrap(address wrapper, uint256 amount) private {
        address token = tokenByWrapper(wrapper);
        require(token != address(0), "Invalid wrapper");

        ERC20(wrapper).safeTransferFrom(msg.sender, address(this), amount);

        PrivateWrapper(wrapper).unwrap(amount, address(this));
        emit Unwrap(token, wrapper, amount);
    }

    function unwrap(address wrapper, uint256 amount, address to) public {
        _unwrap(wrapper, amount);
        ERC20(tokenByWrapper(wrapper)).safeTransfer(to, amount);
    }

    function unwrapERC20(address wrapper, uint256 amount, address to) public {
        _unwrap(wrapper, amount);
        ERC20(tokenByWrapper(wrapper)).safeTransfer(to, amount);
    }
}