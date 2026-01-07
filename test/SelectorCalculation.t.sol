// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

contract SelectorCalculation is Test {
    
    function testCalculateUniswapSelectors() public {
        console.log("=== CALCULATING UNISWAP V3 SELECTORS ===\n");
        
        // 1. exactInputSingle
        string memory exactInputSingleSig = "exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))";
        bytes4 exactInputSingleSelector = bytes4(keccak256(bytes(exactInputSingleSig)));
        console.log("1. exactInputSingle");
        console.log("   Signature:", exactInputSingleSig);
        console.log("   Calculated selector:");
        console.logBytes4(exactInputSingleSelector);
        console.log("   Expected: 0x414bf389");
        console.log("   Match:", exactInputSingleSelector == 0x414bf389 ? "YES" : "NO");
        console.log("");
        
        // 2. exactOutputSingle  
        string memory exactOutputSingleSig = "exactOutputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))";
        bytes4 exactOutputSingleSelector = bytes4(keccak256(bytes(exactOutputSingleSig)));
        console.log("2. exactOutputSingle");
        console.log("   Signature:", exactOutputSingleSig);
        console.log("   Calculated selector:");
        console.logBytes4(exactOutputSingleSelector);
        console.log("   Expected: 0xdb3e2198");
        console.log("   Match:", exactOutputSingleSelector == 0xdb3e2198 ? "YES" : "NO");
        console.log("");
        
        // 3. exactInput
        string memory exactInputSig = "exactInput((bytes,address,uint256,uint256,uint256))";
        bytes4 exactInputSelector = bytes4(keccak256(bytes(exactInputSig)));
        console.log("3. exactInput");
        console.log("   Signature:", exactInputSig);
        console.log("   Calculated selector:");
        console.logBytes4(exactInputSelector);
        console.log("   Expected: 0xc04b8d59");
        console.log("   Match:", exactInputSelector == 0xc04b8d59 ? "YES" : "NO");
        console.log("");
        
        // 4. exactOutput
        string memory exactOutputSig = "exactOutput((bytes,address,uint256,uint256,uint256))";
        bytes4 exactOutputSelector = bytes4(keccak256(bytes(exactOutputSig)));
        console.log("4. exactOutput");
        console.log("   Signature:", exactOutputSig);
        console.log("   Calculated selector:");
        console.logBytes4(exactOutputSelector);
        console.log("   Expected: 0xf28c0498");
        console.log("   Match:", exactOutputSelector == 0xf28c0498 ? "YES" : "NO");
        console.log("");
    }
    
    function testCalculateV2Selectors() public {
        console.log("=== CALCULATING UNISWAP V2 SELECTORS ===\n");
        
        // 5. swapExactTokensForTokens (Uniswap V2 style)
        string memory swapExactTokensForTokensSig = "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)";
        bytes4 swapExactTokensForTokensSelector = bytes4(keccak256(bytes(swapExactTokensForTokensSig)));
        console.log("5. swapExactTokensForTokens");
        console.log("   Signature:", swapExactTokensForTokensSig);
        console.log("   Calculated selector:");
        console.logBytes4(swapExactTokensForTokensSelector);
        console.log("   Expected: 0x38ed1739");
        console.log("   Match:", swapExactTokensForTokensSelector == 0x38ed1739 ? "YES" : "NO");
        console.log("");
        
        // 6. swapTokensForExactTokens (Uniswap V2 style)
        string memory swapTokensForExactTokensSig = "swapTokensForExactTokens(uint256,uint256,address[],address,uint256)";
        bytes4 swapTokensForExactTokensSelector = bytes4(keccak256(bytes(swapTokensForExactTokensSig)));
        console.log("6. swapTokensForExactTokens");
        console.log("   Signature:", swapTokensForExactTokensSig);
        console.log("   Calculated selector:");
        console.logBytes4(swapTokensForExactTokensSelector);
        console.log("   Expected: 0x8803dbee");
        console.log("   Match:", swapTokensForExactTokensSelector == 0x8803dbee ? "YES" : "NO");
        console.log("");
    }
    
    function testStepByStepCalculation() public {
        console.log("=== STEP BY STEP: exactInputSingle ===\n");
        
        // Function signature
        string memory signature = "exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))";
        console.log("Step 1 - Function signature:");
        console.log(signature);
        console.log("");
        
        // Convert to bytes
        bytes memory sigBytes = bytes(signature);
        console.log("Step 2 - Convert to bytes, length:", sigBytes.length);
        console.log("");
        
        // Calculate Keccak-256 hash
        bytes32 hash = keccak256(sigBytes);
        console.log("Step 3 - Keccak-256 hash:");
        console.logBytes32(hash);
        console.log("");
        
        // Take first 4 bytes
        bytes4 selector = bytes4(hash);
        console.log("Step 4 - First 4 bytes (selector):");
        console.logBytes4(selector);
        console.log("");
        
        // Verify
        console.log("Step 5 - Verification:");
        console.log("Expected: 0x414bf389");
        console.log("Got:     ", vm.toString(selector));
        console.log("Match:", selector == 0x414bf389 ? "YES" : "NO");
    }
    
    function testCommonERC20Selectors() public {
        console.log("=== COMMON ERC20 SELECTORS FOR REFERENCE ===\n");
        
        // transfer
        bytes4 transferSelector = bytes4(keccak256("transfer(address,uint256)"));
        console.log("transfer(address,uint256):");
        console.logBytes4(transferSelector);
        
        // approve  
        bytes4 approveSelector = bytes4(keccak256("approve(address,uint256)"));
        console.log("approve(address,uint256):");
        console.logBytes4(approveSelector);
        
        // transferFrom
        bytes4 transferFromSelector = bytes4(keccak256("transferFrom(address,address,uint256)"));
        console.log("transferFrom(address,address,uint256):");
        console.logBytes4(transferFromSelector);
        
        // balanceOf
        bytes4 balanceOfSelector = bytes4(keccak256("balanceOf(address)"));
        console.log("balanceOf(address):");
        console.logBytes4(balanceOfSelector);
    }
    
    function testWhyTheseSpecificValues() public {
        console.log("=== WHY THESE SPECIFIC SELECTOR VALUES? ===\n");
        
        console.log("Selector values are NOT arbitrary! They are:");
        console.log("1. Deterministic - same function signature = same selector");
        console.log("2. Collision-resistant - very unlikely two functions have same selector");
        console.log("3. Standard across all Ethereum contracts");
        console.log("");
        
        console.log("Examples from actual Uniswap contracts:");
        console.log("- Uniswap V3 Router uses these exact selectors");
        console.log("- Any contract implementing ISwapRouter must use these");
        console.log("- That's why RestrictedWallet can safely whitelist them");
        console.log("");
        
        console.log("Security note:");
        console.log("- Whitelisting wrong selector = function won't work");
        console.log("- Missing selector validation = any function can be called");
        console.log("- These values are from official Uniswap interfaces");
    }
}
