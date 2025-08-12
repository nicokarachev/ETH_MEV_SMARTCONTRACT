// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract SandwichBot {
    
    IUniswapV2Router02 public uniswapRouter;
    address public owner;
    constructor(address _uniswapRouter) {
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        owner = msg.sender;
    }
    function sandwichTrade(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external {
        require(msg.sender == owner, "Only owner");
        // Front-run: Buy tokenIn for tokenOut
        uniswapRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            getPath(tokenIn, tokenOut),
            address(this),
            block.timestamp + 60
        );
        // Back-run: Sell tokenOut for tokenIn (after target tx)
        // Add logic to wait for target tx
    }
    function getPath(
        address tokenIn,
        address tokenOut
    ) private pure returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        return path;
    }
}
