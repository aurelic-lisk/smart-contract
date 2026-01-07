// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

/**
 * @title SetupV4Pools
 * @notice Script untuk membuat Uniswap V4 pools pada Lisk Sepolia
 * @dev Setup pools untuk USDC/ETH, USDC/BTC, dan ETH/BTC
 */
contract SetupV4Pools is Script {
    // ============ BASE SEPOLIA ADDRESSES ============
    address constant POOL_MANAGER = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;

    // ============ MOCK TOKEN ADDRESSES ============
    address constant MOCK_USDC = 0xc309D45d4119487b30205784efF9abACF20872c0;
    address constant MOCK_ETH = 0x8379372caeE37abEdacA9925a3D4d5aad2975B35;
    address constant MOCK_BTC = 0xb56967f199FF15b098195C6Dcb8e7f3fC26B43D9;

    function run() external {
        console.log("=== Setup V4 Pools ===");
        console.log("Deployer:", msg.sender);

        // Get token addresses from environment or use defaults
        address usdcAddr = vm.envOr("MOCK_USDC_ADDRESS", MOCK_USDC);
        address ethAddr = vm.envOr("MOCK_ETH_ADDRESS", MOCK_ETH);
        address btcAddr = vm.envOr("MOCK_BTC_ADDRESS", MOCK_BTC);

        console.log("Token addresses:");
        console.log("- USDC:", usdcAddr);
        console.log("- ETH:", ethAddr);
        console.log("- BTC:", btcAddr);

        // Initialize Pool Manager
        IPoolManager poolManager = IPoolManager(POOL_MANAGER);

        // Create pools
        _createPool(poolManager, usdcAddr, ethAddr, "USDC/ETH");
        _createPool(poolManager, usdcAddr, btcAddr, "USDC/BTC");
        _createPool(poolManager, ethAddr, btcAddr, "ETH/BTC");

        console.log("=== Pool Setup Complete ===");
        console.log("All pools created successfully!");
    }

    function _createPool(IPoolManager poolManager, address token0, address token1, string memory name) internal {
        console.log(string(abi.encodePacked("Creating ", name, " pool...")));

        // Ensure currencies are sorted
        address currency0 = token0 < token1 ? token0 : token1;
        address currency1 = token0 < token1 ? token1 : token0;

        // Create pool key
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(currency0),
            currency1: Currency.wrap(currency1),
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        // Initialize pool with 1:1 price
        uint160 sqrtPriceX96 = 79228162514264337593543950336; // 1:1 price
        poolManager.initialize(poolKey, sqrtPriceX96);

        console.log(string(abi.encodePacked(name, " pool created successfully")));
    }
}

