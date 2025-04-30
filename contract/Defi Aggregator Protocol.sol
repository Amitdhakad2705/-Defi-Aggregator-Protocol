// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

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

contract DeFiAggregator is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    bool public paused;

    event SwapExecuted(
        address indexed user,
        address indexed dex,
        address tokenIn,
        address tokenOut,
        uint amountIn,
        uint amountOut
    );

    event Paused();
    event Unpaused();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); // Disable constructor for proxy-safe upgradeable contract
    }

    function initialize() external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        paused = false;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    function swapTokens(
        address dex,
        address tokenIn,
        address tokenOut,
        uint amountIn
    ) external whenNotPaused nonReentrant returns (uint) {
        require(amountIn > 0, "Amount must be greater than 0");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(dex, amountIn);

        uint amountOut = IDEX(dex).swap(tokenIn, tokenOut, amountIn);

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

    function getEstimatedBatchSwap(
        address[] calldata dexes,
        address[] calldata tokenIns,
        address[] calldata tokenOuts,
        uint[] calldata amountsIn
    ) external view returns (uint[] memory) {
        require(
            dexes.length == tokenIns.length &&
            tokenIns.length == tokenOuts.length &&
            tokenOuts.length == amountsIn.length,
            "Input array lengths must match"
        );

        uint[] memory estimatedOutputs = new uint[](dexes.length);
        for (uint i = 0; i < dexes.length; i++) {
            estimatedOutputs[i] = IDEX(dexes[i]).getAmountOut(tokenIns[i], tokenOuts[i], amountsIn[i]);
        }
        return estimatedOutputs;
    }

    function rescueTokens(address token, uint amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }

    function emergencyWithdrawToken(address token) external onlyOwner {
        uint balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        IERC20(token).transfer(owner(), balance);
    }

    function emergencyWithdrawETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function withdrawMultipleTokens(address[] calldata tokens) external onlyOwner {
        for (uint i = 0; i < tokens.length; i++) {
            uint balance = IERC20(tokens[i]).balanceOf(address(this));
            if (balance > 0) {
                IERC20(tokens[i]).transfer(owner(), balance);
            }
        }
    }

    function getTokenBalance(address token) external view returns (uint) {
        return IERC20(token).balanceOf(address(this));
    }

    function checkAllowance(address token, address user) external view returns (uint) {
        return IERC20(token).allowance(user, address(this));
    }

    function setApprovalForDEX(address token, address dex, uint amount) external onlyOwner {
        IERC20(token).approve(dex, amount);
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused();
    }

    function togglePause() external onlyOwner {
        paused = !paused;
        if (paused) {
            emit Paused();
        } else {
            emit Unpaused();
        }
    }

    receive() external payable {}
    fallback() external payable {}
}
