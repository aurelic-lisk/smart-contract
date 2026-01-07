// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title WhitelistTokens
 * @notice Script to whitelist tokens in RestrictedWallet contracts
 */
contract WhitelistTokens is Script {
    
    // ============ TOKEN ADDRESSES ============
    address constant MOCK_USDC = 0xc309D45d4119487b30205784efF9abACF20872c0;
    address constant MOCK_ETH = 0x8379372caeE37abEdacA9925a3D4d5aad2975B35;
    address constant MOCK_BTC = 0xb56967f199FF15b098195C6Dcb8e7f3fC26B43D9;
    
    // ============ CONTRACT ADDRESSES ============
    address constant RESTRICTED_WALLET_FACTORY = 0xeba187f19417DbCDe5DcfF45B5f431c762EF862D;
    
    function run() external {
        console.log("=== Whitelist Tokens in RestrictedWallet ===");
        console.log("Factory:", RESTRICTED_WALLET_FACTORY);
        
        // Get all deployed RestrictedWallet contracts
        // Note: In production, you would need to track deployed wallets
        // For now, we'll assume we have a way to get the wallet addresses
        
        console.log("Token addresses to whitelist:");
        console.log("USDC:", MOCK_USDC);
        console.log("ETH:", MOCK_ETH);
        console.log("BTC:", MOCK_BTC);
        
        console.log("");
        console.log("=== Manual Whitelist Instructions ===");
        console.log("To whitelist tokens, you need to call addWhitelistedToken() on each RestrictedWallet:");
        console.log("");
        console.log("For each RestrictedWallet contract:");
        console.log("1. Call addWhitelistedToken(MOCK_USDC)");
        console.log("2. Call addWhitelistedToken(MOCK_ETH)");
        console.log("3. Call addWhitelistedToken(MOCK_BTC)");
        console.log("");
        console.log("Or use batch function:");
        console.log("Call addWhitelistedTokensBatch([MOCK_USDC, MOCK_ETH, MOCK_BTC])");
        console.log("");
        console.log("=== Verification ===");
        console.log("After whitelisting, verify with:");
        console.log("isTokenWhitelisted(MOCK_USDC)");
        console.log("isTokenWhitelisted(MOCK_ETH)");
        console.log("isTokenWhitelisted(MOCK_BTC)");
    }
}

