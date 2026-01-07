// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {RestrictedWallet} from "../src/RestrictedWallet.sol";

/**
 * @title WhitelistTokensBatch
 * @notice Script to whitelist all tokens in batch for a RestrictedWallet
 */
contract WhitelistTokensBatch is Script {
    
    // ============ TOKEN ADDRESSES ============
    address constant MOCK_USDC = 0xc309D45d4119487b30205784efF9abACF20872c0;
    address constant MOCK_ETH = 0x8379372caeE37abEdacA9925a3D4d5aad2975B35;
    address constant MOCK_BTC = 0xb56967f199FF15b098195C6Dcb8e7f3fC26B43D9;
    
    function run() external {
        // Get RestrictedWallet address from environment
        address restrictedWalletAddress = vm.envOr("RESTRICTED_WALLET_ADDRESS", address(0));
        
        if (restrictedWalletAddress == address(0)) {
            console.log("❌ RESTRICTED_WALLET_ADDRESS not set");
            console.log("Usage: RESTRICTED_WALLET_ADDRESS=<address> forge script script/WhitelistTokensBatch.s.sol --rpc-url <RPC> --broadcast");
            return;
        }
        
        console.log("=== Batch Whitelist Tokens ===");
        console.log("Wallet:", restrictedWalletAddress);
        
        vm.startBroadcast();
        
        RestrictedWallet wallet = RestrictedWallet(restrictedWalletAddress);
        
        // Prepare token array
        address[] memory tokens = new address[](3);
        tokens[0] = MOCK_USDC;
        tokens[1] = MOCK_ETH;
        tokens[2] = MOCK_BTC;
        
        console.log("Whitelisting tokens in batch...");
        console.log("Tokens:", MOCK_USDC, MOCK_ETH, MOCK_BTC);
        
        // Batch whitelist
        wallet.addWhitelistedTokensBatch(tokens);
        
        console.log("✅ All tokens whitelisted in batch");
        
        // Verify
        console.log("");
        console.log("Verification:");
        console.log("USDC whitelisted:", wallet.isTokenWhitelisted(MOCK_USDC));
        console.log("ETH whitelisted:", wallet.isTokenWhitelisted(MOCK_ETH));
        console.log("BTC whitelisted:", wallet.isTokenWhitelisted(MOCK_BTC));
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== Batch Whitelist Complete ===");
    }
}

