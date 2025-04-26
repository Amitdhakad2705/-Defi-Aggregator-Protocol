// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IDEX {
    function swap(address tokenIn, address tokenOut, uint amountIn) external returns (uint amountOut);
    // Optional estimate function
    function getAmountOut(address tokenIn, address tokenOut, uint amountIn) external view returns (uint amountOut);
}

contract DeFiAggregator {
    address public owner;
    bool public paused;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function swapTokens(
        address dex,
        address tokenIn,
        address tokenOut,
        uint amountIn
    ) external whenNotPaused returns (uint) {
        require(amountIn > 0, "Amount must be greater than 0");

        // Transfer tokens to this contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(dex, amountIn);

        // Execute swap
        uint amountOut = IDEX(dex).swap(tokenIn, tokenOut, amountIn);

        // Send output tokens to user
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        return amountOut;
    }

    function rescueTokens(address token, uint amount) external onlyOwner {
        IERC20(token).transfer(owner, amount);
    }

    function updateOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }

    function batchSwap(
        address[] calldata dexes,
        address[] calldata tokenIns,
        address[] calldata tokenOuts,
        uint[] calldata amountsIn
    ) external whenNotPaused {
        require(
            dexes.length == tokenIns.length && 
            tokenIns.length == tokenOuts.length && 
            tokenOuts.length == amountsIn.length,
            "Input array lengths must match"
        );

        for (uint i = 0; i < dexes.length; i++) {
            swapTokens(dexes[i], tokenIns[i], tokenOuts[i], amountsIn[i]);
        }
    }

    function estimateSwap(
        address dex,
        address tokenIn,
        address tokenOut,
        uint amountIn
    ) external view returns (uint) {
        require(amountIn > 0, "Amount must be greater than 0");
        return IDEX(dex).getAmountOut(tokenIn, tokenOut, amountIn);
    }
}

interface IERC20 {
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    function transfer(address recipient, uint amount) external returns (bool);
    function approve(address spender, uint amount) external returns (bool);
}


