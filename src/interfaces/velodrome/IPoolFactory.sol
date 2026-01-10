// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPoolFactory
 * @notice Minimal PoolFactory interface for pool lookup
 */
interface IPoolFactory {
    /**
     * @notice Get pool address for token pair
     * @param tokenA First token
     * @param tokenB Second token
     * @param stable True for stable pool, false for volatile
     * @return pool Pool address (zero address if doesn't exist)
     */
    function getPool(
        address tokenA,
        address tokenB,
        bool stable
    ) external view returns (address pool);

    /**
     * @notice Check if address is a valid pool
     * @param pool Address to check
     * @return isPool True if valid pool
     */
    function isPool(address pool) external view returns (bool isPool);
}
