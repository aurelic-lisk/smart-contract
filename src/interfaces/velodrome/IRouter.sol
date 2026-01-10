// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRouter
 * @notice Velodrome Router interface for swap functionality
 * @dev Validated against actual Router.sol (line 319-335 for swaps, 104-116 for quotes)
 */
interface IRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory; // Use address(0) for defaultFactory
    }

    /**
     * @notice Swap exact tokens for tokens
     * @dev Line 319-335 in actual Router.sol
     * @param amountIn Amount of input tokens
     * @param amountOutMin Minimum output amount (slippage protection)
     * @param routes Array of routes for swap path
     * @param to Recipient address
     * @param deadline Transaction deadline
     * @return amounts Array of amounts for each step
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes, // calldata in actual function
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /**
     * @notice Get quote for swap (view function)
     * @dev Line 104-116 in actual Router.sol
     * @param amountIn Amount of input tokens
     * @param routes Array of routes
     * @return amounts Expected output amounts
     */
    function getAmountsOut(
        uint256 amountIn,
        Route[] memory routes // memory in view function
    ) external view returns (uint256[] memory amounts);
}
