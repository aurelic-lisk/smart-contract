// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPool
 * @notice Minimal Pool interface for price quotes and reserves
 */
interface IPool {
    /**
     * @notice Get pool reserves
     * @return reserve0 Reserve of token0
     * @return reserve1 Reserve of token1
     * @return blockTimestampLast Last update timestamp
     */
    function getReserves()
        external
        view
        returns (
            uint256 reserve0,
            uint256 reserve1,
            uint256 blockTimestampLast
        );

    /**
     * @notice Get expected output amount
     * @param amountIn Input amount
     * @param tokenIn Input token address
     * @return amountOut Expected output amount
     */
    function getAmountOut(
        uint256 amountIn,
        address tokenIn
    ) external view returns (uint256 amountOut);

    /**
     * @notice Pool tokens
     */
    function token0() external view returns (address);
    function token1() external view returns (address);
    function stable() external view returns (bool);
}
