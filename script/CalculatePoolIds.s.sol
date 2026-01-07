// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

/**
 * @title CalculatePoolIds
 * @notice Script untuk menghitung Pool ID baru berdasarkan token addresses
 */
contract CalculatePoolIds is Script {
    
    // ============ NEW TOKEN ADDRESSES ============
    address constant MOCK_USDC = 0xc309D45d4119487b30205784efF9abACF20872c0;
    address constant MOCK_ETH = 0x8379372caeE37abEdacA9925a3D4d5aad2975B35;
    address constant MOCK_BTC = 0xb56967f199FF15b098195C6Dcb8e7f3fC26B43D9;
    
    function run() external {
        console.log("=== Calculate New Pool IDs ===");
        
        // USDC/ETH Pool
        _calculatePoolId(MOCK_USDC, MOCK_ETH, "USDC/ETH");
        
        // USDC/BTC Pool  
        _calculatePoolId(MOCK_USDC, MOCK_BTC, "USDC/BTC");
        
        // ETH/BTC Pool
        _calculatePoolId(MOCK_ETH, MOCK_BTC, "ETH/BTC");
    }
    
    function _calculatePoolId(
        address token0,
        address token1,
        string memory name
    ) internal pure {
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
        
        // Calculate pool ID
        bytes32 poolId = keccak256(abi.encode(poolKey));
        
        console.log(string(abi.encodePacked("=== ", name, " Pool ===")));
        console.log("Currency0:", currency0);
        console.log("Currency1:", currency1);
        console.log("Pool ID:", vm.toString(poolId));
        console.log("");
    }
}

