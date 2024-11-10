// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./LuminexPrivacyPolicy.sol";
import "./SimpleORAM.sol";

contract PrivateERC20 is IERC20, LuminexPrivacyPolicy {
    using SimpleORAMLib for SimpleORAMLib.SimpleORAM;

    struct PrivateERC20Config {
        bool totalSupplyVisible;
        string name;
        string symbol;
        uint8 decimals;
    }

    SimpleORAMLib.SimpleORAM internal _balances;

    mapping(address => mapping(address => uint256)) internal _allowances;

    string public name;
    string public symbol;
    uint8 public decimals;

    bool public immutable totalSupplyVisible;

    uint256 internal _globalTotalSupply;

    constructor(PrivateERC20Config memory _config) {
        name = _config.name;
        symbol = _config.symbol;
        decimals = _config.decimals;
        totalSupplyVisible = _config.totalSupplyVisible;
    }

    function _isAllowedByPrivacyPolicy(address owner) private view returns (bool) {
        return msg.sender == owner
            || msg.sender == address(this) 
            || hasAccess(owner, msg.sender, LuminexPrivacyPolicy.PrivacyPolicy.Reveal);
    }

    function totalSupply() public view virtual override returns (uint256) {
        return totalSupplyVisible ? _globalTotalSupply : 0;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        if (!_isAllowedByPrivacyPolicy(account)) {
            return 0;
        }

        return _balances.get(account);
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        if (!_isAllowedByPrivacyPolicy(owner)) {
            return 0;
        }

        if (_allowances[owner][spender] > 0 && msg.sender == spender) {
            return _allowances[owner][spender];
        }

        return _allowances[owner][spender];
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances.get(from);
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances.set(from, fromBalance - amount);
        }

        uint256 toBalance = _balances.get(to);
        _balances.set(to, toBalance + amount);
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _mint(address to, uint256 amount) internal {
        _balances.set(to, _balances.get(to) + amount);
        _globalTotalSupply += amount;
    }

    function _burn(address from, uint256 amount) internal {
        _balances.set(from, _balances.get(from) - amount);
        _globalTotalSupply -= amount;
    }
}