// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract IXTokenV2 is ERC20, Ownable {
    mapping(address => bool) private _isExcludedFromFee;
    address payable private _taxWallet;

    uint256 public constant MAX_BUY_TAX = 2;
    uint256 public constant MAX_SELL_TAX = 2;

    uint256 public buyTax = MAX_BUY_TAX;
    uint256 public sellTax = MAX_SELL_TAX;

    uint256 public taxSwapThreshold = 100 ether;
    uint256 public maxTaxSwap = 100 ether;

    mapping(address => bool) public amms;

    IUniswapV2Router02 public uniswapV2Router;

    bool private inSwap = false;

    bool public tradingOpen;
    bool public swapEnabled;

    address public minter;

    event TaxUpdated(uint256 newBuyTax, uint256 newSellTax);

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor() ERC20("illumineX Token", "IX") {
        _taxWallet = payable(msg.sender);
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_taxWallet] = true;
    }

    function toggleAmm(address _amm) public onlyOwner {
        amms[_amm] = !amms[_amm];
    }

    function setMinter(address _minter) public onlyOwner {
        require(minter == address(0));
        minter = _minter;
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function mint(address to, uint256 amount) public {
        require(msg.sender == minter);
        _mint(to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        uint256 fee = 0;

        if (amms[to] && from != address(this)) {
            fee = (amount * sellTax) / 100;
        } else if (amms[from] && to != address(this)) {
            fee = (amount * buyTax) / 100;
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        if (!inSwap && amms[to] && swapEnabled && contractTokenBalance > taxSwapThreshold) {
            swapTokensForEth(min(contractTokenBalance, maxTaxSwap));

            uint256 contractETHBalance = address(this).balance;
            if (contractETHBalance > 0) {
                sendETHToFee(address(this).balance);
            }
        }

        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            fee = 0;
        }

        if (fee > 0) {
            super._transfer(from, address(this), fee);
        }

        super._transfer(from, to, amount - fee);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return (a > b) ? b : a;
    }

    function updateTax(uint256 newBuyTax, uint256 newSellTax) public onlyOwner {
        require(newBuyTax < MAX_BUY_TAX && newSellTax < MAX_SELL_TAX, "Tax too high");
        buyTax = newBuyTax;
        sellTax = newSellTax;

        emit TaxUpdated(newBuyTax, newSellTax);
    }

    function setAutoswapParams(uint256 _maxSwapTax, uint256 _swapThreshold) public onlyOwner {
        maxTaxSwap = _maxSwapTax;
        taxSwapThreshold = _swapThreshold;
    }

    function toggleSwapStatus() public onlyOwner {
        swapEnabled = !swapEnabled;
    }

    function toggleExcludeFromFee(address _user) public onlyOwner {
        _isExcludedFromFee[_user] = !_isExcludedFromFee[_user];
    }

    function setTaxWallet(address payable _newTaxWallet) public onlyOwner {
        _taxWallet = _newTaxWallet;
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        if (tokenAmount == 0 || !tradingOpen) {
            return;
        }

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function sendETHToFee(uint256 amount) private {
        _taxWallet.transfer(amount);
    }

    function enableTrading() public onlyOwner {
        require(!tradingOpen, "Trading has already started");

        address routerAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        if (block.chainid == 56) {
            routerAddress = 0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F;
        }

        uniswapV2Router = IUniswapV2Router02(routerAddress);
        amms[IUniswapV2Factory(uniswapV2Router.factory()).getPair(address(this), uniswapV2Router.WETH())] = true;

        swapEnabled = true;
        tradingOpen = true;
    }

    receive() external payable {}

    function withdraw(address to, uint256 amount) public onlyOwner {
        _transfer(address(this), to, amount);
    }

    function swapBalanceToETH() public onlyOwner {
        uint256 tokenBalance = balanceOf(address(this));
        if (tokenBalance > 0) {
            swapTokensForEth(tokenBalance);
        }

        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            sendETHToFee(ethBalance);
        }
    }
}
