// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {LoanManager} from "../src/LoanManager.sol";

/**
 * @title GetUserRestrictedWallet
 * @notice Script to get RestrictedWallet address for a user
 */
contract GetUserRestrictedWallet is Script {
    
    // ============ CONTRACT ADDRESSES ============
    address constant LOAN_MANAGER = 0x93f3766e8a7F7e15e8990406bdBa1247E3A3aCd2;
    
    function run() external {
        // Get user address from environment
        address userAddress = vm.envOr("USER_ADDRESS", address(0));
        
        if (userAddress == address(0)) {
            console.log("❌ USER_ADDRESS not set");
            console.log("Usage: USER_ADDRESS=<address> forge script script/GetUserRestrictedWallet.s.sol --rpc-url <RPC>");
            return;
        }
        
        console.log("=== Get User RestrictedWallet ===");
        console.log("User:", userAddress);
        console.log("LoanManager:", LOAN_MANAGER);
        
        LoanManager loanManager = LoanManager(LOAN_MANAGER);
        
        // Get loan info
        (uint256 loanAmount, uint256 marginAmount, uint256 poolFunding, uint256 startTime, string memory restrictedWallet, bool isActive) = loanManager.getLoanInfo(userAddress);
        
        console.log("");
        console.log("Loan Info:");
        console.log("Loan Amount:", loanAmount);
        console.log("Margin Amount:", marginAmount);
        console.log("Pool Funding:", poolFunding);
        console.log("Start Time:", startTime);
        console.log("Restricted Wallet:", restrictedWallet);
        console.log("Is Active:", isActive);
        
        if (isActive && bytes(restrictedWallet).length > 0) {
            console.log("");
            console.log("✅ Active loan found!");
            console.log("RestrictedWallet Address:", restrictedWallet);
            console.log("");
            console.log("To whitelist tokens for this wallet, run:");
            console.log("RESTRICTED_WALLET_ADDRESS=", restrictedWallet, " forge script script/WhitelistTokensBatch.s.sol --rpc-url <RPC> --broadcast");
        } else {
            console.log("");
            console.log("❌ No active loan found for this user");
            console.log("User needs to create a loan first to get a RestrictedWallet");
        }
    }
}

