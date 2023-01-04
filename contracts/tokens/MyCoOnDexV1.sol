// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../uniswapv2/interfaces/IUniswapV2Router02.sol";
import "../uniswapv2/interfaces/IUniswapV2Factory.sol";

abstract contract MyCoOnDexV1 is
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    ERC20BurnableUpgradeable
{
    using SafeMath for uint256;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    address public WBNB;

    // event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);

    function createPair(address _router) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uniswapV2Router = IUniswapV2Router02(_router);
        WBNB = uniswapV2Router.WETH();
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            WBNB
        );
    }

    //Todo: More research and conclusion needed on Buy back mechnism
    // function swapAndLiquify(uint256 contractTokenBalance) private nonReentrant {
    //     // split the contract balance into halves
    //     uint256 half = contractTokenBalance.div(2);
    //     uint256 otherHalf = contractTokenBalance.sub(half);

    //     // capture the contract's current BNB balance.
    //     // this is so that we can capture exactly the amount of BNB that the
    //     // swap creates, and not make the liquidity event include any BNB that
    //     // has been manually sent to the contract
    //     uint256 initialBalance = address(this).balance;

    //     // swap tokens for BNB
    //     swapTokensForBnb(half);

    //     // how much BNB did we just swap into?
    //     uint256 newBalance = address(this).balance.sub(initialBalance);

    //     // add liquidity to uniswap
    //     addLiquidity(otherHalf, newBalance);

    //     emit SwapAndLiquify(half, newBalance, otherHalf);
    // }

    function swapTokensForBnb(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> wbnb
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        IERC20Upgradeable(address(this)).approve(address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BNB
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // approve token transfer to cover all possible scenarios
        IERC20Upgradeable(address(this)).approve(address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    function updateRouterAndPair(
        address _uniswapV2Router,
        address _uniswapV2Pair
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);
        uniswapV2Pair = _uniswapV2Pair;
        WBNB = uniswapV2Router.WETH();
    }
}
