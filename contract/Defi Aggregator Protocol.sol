// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IDEX {
    function swap(address tokenIn, address tokenOut, uint amountIn) external returns (uint amountOut);
}

contract DeFiAggregator {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function swapTokens(
        address dex,
        address tokenIn,
        address tokenOut,
        uint amountIn
    ) external returns (uint) {
        require(amountIn > 0, "Amount must be greater than 0");

        // Approve DEX to spend tokens
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(dex, amountIn);

        // Execute swap on DEX
        uint amountOut = IDEX(dex).swap(tokenIn, tokenOut, amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        return amountOut;
    }

    function rescueTokens(address token, uint amount) external {
        require(msg.sender == owner, "Not authorized");
        IERC20(token).transfer(owner, amount);
    }
}

interface IERC20 {
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    function transfer(address recipient, uint amount) external returns (bool);
    function approve(address spender, uint amount) external returns (bool);
}

