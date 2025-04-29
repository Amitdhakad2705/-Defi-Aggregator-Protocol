// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IDEX {
    function swap(address tokenIn, address tokenOut, uint amountIn) external returns (uint amountOut);
    function getAmountOut(address tokenIn, address tokenOut, uint amountIn) external view returns (uint amountOut);
}

interface IERC20 {
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    function transfer(address recipient, uint amount) external returns (bool);
    function approve(address spender, uint amount) external returns (bool);
    function balanceOf(address account) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
}

contract DeFiAggregator {
    address public owner;
    bool public paused;
    bool private locked;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrancy not allowed");
        locked = true;
        _;
        locked = false;
    }

    event SwapExecuted(
        address indexed user,
        address indexed dex,
        address tokenIn,
        address tokenOut,
        uint amountIn,
        uint amountOut
    );

    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event Paused();
    event Unpaused();

    constructor() {
        owner = msg.sender;
    }

    function swapTokens(
        address dex,
        address tokenIn,
        address tokenOut,
        uint amountIn
    ) external whenNotPaused nonReentrant returns (uint) {
        require(amountIn > 0, "Amount must be greater than 0");

        // Transfer tokens to this contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(dex, amountIn);

        // Execute swap
        uint amountOut = IDEX(dex).swap(tokenIn, tokenOut, amountIn);

        // Send output tokens to user
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit SwapExecuted(msg.sender, dex, tokenIn, tokenOut, amountIn, amountOut);
        return amountOut;
    }

    function batchSwap(
        address[] calldata dexes,
        address[] calldata tokenIns,
        address[] calldata tokenOuts,
        uint[] calldata amountsIn
    ) external whenNotPaused nonReentrant {
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

    function rescueTokens(address token, uint amount) external onlyOwner {
        IERC20(token).transfer(owner, amount);
    }

    function emergencyWithdrawToken(address token) external onlyOwner {
        uint balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        IERC20(token).transfer(owner, balance);
    }

    function emergencyWithdrawETH() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function checkAllowance(address token, address user) external view returns (uint) {
        return IERC20(token).allowance(user, address(this));
    }

    function updateOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused();
    }

    receive() external payable {}

    fallback() external payable {}
}


