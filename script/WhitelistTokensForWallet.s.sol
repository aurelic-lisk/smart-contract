// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {RestrictedWallet} from "../src/RestrictedWallet.sol";

/**
 * @title WhitelistTokensForWallet
 * @notice Script to whitelist tokens in a specific RestrictedWallet
 */
contract WhitelistTokensForWallet is Script {
    
    // ============ TOKEN ADDRESSES ============
    address constant MOCK_USDC = 0xc309D45d4119487b30205784efF9abACF20872c0;
    address constant MOCK_ETH = 0x8379372caeE37abEdacA9925a3D4d5aad2975B35;
    address constant MOCK_BTC = 0xb56967f199FF15b098195C6Dcb8e7f3fC26B43D9;
    
    function run() external {
        // Get RestrictedWallet address from environment or use default
        address restrictedWalletAddress = vm.envOr("RESTRICTED_WALLET_ADDRESS", address(0));
        
        if (restrictedWalletAddress == address(0)) {
            console.log("❌ RESTRICTED_WALLET_ADDRESS not set");
            console.log("Usage: forge script script/WhitelistTokensForWallet.s.sol --rpc-url <RPC> --broadcast --sig 'run(address)' <WALLET_ADDRESS>");
            return;
        }
        
        console.log("=== Whitelist Tokens for RestrictedWallet ===");
        console.log("Wallet:", restrictedWalletAddress);
        
        vm.startBroadcast();
        
        RestrictedWallet wallet = RestrictedWallet(restrictedWalletAddress);
        
        // Check current whitelist status
        console.log("Current whitelist status:");
        console.log("USDC whitelisted:", wallet.isTokenWhitelisted(MOCK_USDC));
        console.log("ETH whitelisted:", wallet.isTokenWhitelisted(MOCK_ETH));
        console.log("BTC whitelisted:", wallet.isTokenWhitelisted(MOCK_BTC));
        
        // Whitelist tokens
        console.log("");
        console.log("Whitelisting tokens...");
        
        if (!wallet.isTokenWhitelisted(MOCK_USDC)) {
            wallet.addWhitelistedToken(MOCK_USDC);
            console.log("✅ USDC whitelisted");
        } else {
            console.log("✅ USDC already whitelisted");
        }
        
        if (!wallet.isTokenWhitelisted(MOCK_ETH)) {
            wallet.addWhitelistedToken(MOCK_ETH);
            console.log("✅ ETH whitelisted");
        } else {
            console.log("✅ ETH already whitelisted");
        }
        
        if (!wallet.isTokenWhitelisted(MOCK_BTC)) {
            wallet.addWhitelistedToken(MOCK_BTC);
            console.log("✅ BTC whitelisted");
        } else {
            console.log("✅ BTC already whitelisted");
        }
        
        // Verify whitelist status
        console.log("");
        console.log("Final whitelist status:");
        console.log("USDC whitelisted:", wallet.isTokenWhitelisted(MOCK_USDC));
        console.log("ETH whitelisted:", wallet.isTokenWhitelisted(MOCK_ETH));
        console.log("BTC whitelisted:", wallet.isTokenWhitelisted(MOCK_BTC));
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== Whitelist Complete ===");
        console.log("All tokens are now whitelisted for trading!");
    }
}

