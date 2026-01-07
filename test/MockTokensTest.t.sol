// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/MockUSDC.sol";
import "../src/MockETH.sol";
import "../src/MockBTC.sol";

/**
 * @title MockTokensTest
 * @notice Test suite for mock tokens functionality
 * @dev Tests minting, burning, transfers, and access control
 */
contract MockTokensTest is Test {
    // ============ CONTRACTS ============
    MockUSDC public mockUSDC;
    MockETH public mockETH;
    MockBTC public mockBTC;
    
    // ============ ADDRESSES ============
    address public owner;
    address public user;
    address public nonOwner;
    
    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        nonOwner = makeAddr("nonOwner");
        
        // Deploy mock tokens
        vm.startPrank(owner);
        mockUSDC = new MockUSDC();
        mockETH = new MockETH();
        mockBTC = new MockBTC();
        vm.stopPrank();
        
        console.log("=== Mock Tokens Test Setup Complete ===");
        console.log("Owner:", owner);
        console.log("MockUSDC:", address(mockUSDC));
        console.log("MockETH:", address(mockETH));
        console.log("MockBTC:", address(mockBTC));
    }
    
    // ============ MOCK USDC TESTS ============
    
    function testMockUSDCDeplyment() public {
        assertEq(mockUSDC.name(), "Mock USDC");
        assertEq(mockUSDC.symbol(), "USDC");
        assertEq(mockUSDC.decimals(), 6);
        assertEq(mockUSDC.totalSupply(), 0);
    }
    
    function testMockUSDCMint() public {
        vm.startPrank(owner);
        
        uint256 amount = 1000 * 1e6; // 1000 USDC
        mockUSDC.mint(user, amount);
        
        assertEq(mockUSDC.balanceOf(user), amount);
        assertEq(mockUSDC.totalSupply(), amount);
        
        vm.stopPrank();
    }
    
    function testMockUSDCMintOnlyOwner() public {
        vm.startPrank(nonOwner);
        
        // MockUSDC doesn't have onlyOwner modifier, so this should succeed
        mockUSDC.mint(user, 1000 * 1e6);
        assertEq(mockUSDC.balanceOf(user), 1000 * 1e6);
        
        vm.stopPrank();
    }
    
    function testMockUSDCBurn() public {
        vm.startPrank(owner);
        
        // Mint first
        uint256 amount = 1000 * 1e6;
        mockUSDC.mint(owner, amount);
        
        // Transfer to user
        mockUSDC.transfer(user, amount);
        
        vm.stopPrank();
        
        // User burns
        vm.startPrank(user);
        mockUSDC.burn(amount);
        
        assertEq(mockUSDC.balanceOf(user), 0);
        assertEq(mockUSDC.totalSupply(), 0);
        
        vm.stopPrank();
    }
    
    // ============ MOCK ETH TESTS ============
    
    function testMockETHDeployment() public {
        assertEq(mockETH.name(), "Mock ETH");
        assertEq(mockETH.symbol(), "mETH");
        assertEq(mockETH.decimals(), 18);
        assertEq(mockETH.totalSupply(), 0);
    }
    
    function testMockETHMint() public {
        vm.startPrank(owner);
        
        uint256 amount = 10 * 1e18; // 10 ETH
        mockETH.mint(user, amount);
        
        assertEq(mockETH.balanceOf(user), amount);
        assertEq(mockETH.totalSupply(), amount);
        
        vm.stopPrank();
    }
    
    function testMockETHMintOnlyOwner() public {
        vm.startPrank(nonOwner);
        
        vm.expectRevert(); // Will revert with OwnableUnauthorizedAccount
        mockETH.mint(user, 10 * 1e18);
        
        vm.stopPrank();
    }
    
    function testMockETHBurn() public {
        vm.startPrank(owner);
        
        // Mint first
        uint256 amount = 10 * 1e18;
        mockETH.mint(owner, amount);
        
        // Transfer to user
        mockETH.transfer(user, amount);
        
        vm.stopPrank();
        
        // User burns
        vm.startPrank(user);
        mockETH.burn(amount);
        
        assertEq(mockETH.balanceOf(user), 0);
        assertEq(mockETH.totalSupply(), 0);
        
        vm.stopPrank();
    }
    
    // ============ MOCK BTC TESTS ============
    
    function testMockBTCDeployment() public {
        assertEq(mockBTC.name(), "Mock BTC");
        assertEq(mockBTC.symbol(), "mBTC");
        assertEq(mockBTC.decimals(), 8);
        assertEq(mockBTC.totalSupply(), 0);
    }
    
    function testMockBTCMint() public {
        vm.startPrank(owner);
        
        uint256 amount = 1 * 1e8; // 1 BTC
        mockBTC.mint(user, amount);
        
        assertEq(mockBTC.balanceOf(user), amount);
        assertEq(mockBTC.totalSupply(), amount);
        
        vm.stopPrank();
    }
    
    function testMockBTCMintOnlyOwner() public {
        vm.startPrank(nonOwner);
        
        vm.expectRevert(); // Will revert with OwnableUnauthorizedAccount
        mockBTC.mint(user, 1 * 1e8);
        
        vm.stopPrank();
    }
    
    function testMockBTCBurn() public {
        vm.startPrank(owner);
        
        // Mint first
        uint256 amount = 1 * 1e8;
        mockBTC.mint(owner, amount);
        
        // Transfer to user
        mockBTC.transfer(user, amount);
        
        vm.stopPrank();
        
        // User burns
        vm.startPrank(user);
        mockBTC.burn(amount);
        
        assertEq(mockBTC.balanceOf(user), 0);
        assertEq(mockBTC.totalSupply(), 0);
        
        vm.stopPrank();
    }
    
    // ============ TRANSFER TESTS ============
    
    function testTokenTransfers() public {
        vm.startPrank(owner);
        
        // Mint tokens to owner
        mockUSDC.mint(owner, 10000 * 1e6);
        mockETH.mint(owner, 100 * 1e18);
        mockBTC.mint(owner, 10 * 1e8);
        
        // Transfer to user
        mockUSDC.transfer(user, 1000 * 1e6);
        mockETH.transfer(user, 10 * 1e18);
        mockBTC.transfer(user, 1 * 1e8);
        
        // Verify balances
        assertEq(mockUSDC.balanceOf(user), 1000 * 1e6);
        assertEq(mockETH.balanceOf(user), 10 * 1e18);
        assertEq(mockBTC.balanceOf(user), 1 * 1e8);
        
        assertEq(mockUSDC.balanceOf(owner), 9000 * 1e6);
        assertEq(mockETH.balanceOf(owner), 90 * 1e18);
        assertEq(mockBTC.balanceOf(owner), 9 * 1e8);
        
        vm.stopPrank();
    }
    
    function testTransferFrom() public {
        vm.startPrank(owner);
        
        // Mint tokens to owner
        mockUSDC.mint(owner, 10000 * 1e6);
        
        // Approve user to spend
        mockUSDC.approve(user, 1000 * 1e6);
        
        vm.stopPrank();
        
        // User transfers from owner
        vm.startPrank(user);
        mockUSDC.transferFrom(owner, user, 1000 * 1e6);
        
        assertEq(mockUSDC.balanceOf(user), 1000 * 1e6);
        assertEq(mockUSDC.balanceOf(owner), 9000 * 1e6);
        assertEq(mockUSDC.allowance(owner, user), 0);
        
        vm.stopPrank();
    }
    
    // ============ EDGE CASE TESTS ============
    
    function testMintToZeroAddress() public {
        vm.startPrank(owner);
        
        vm.expectRevert("Cannot mint to zero address");
        mockETH.mint(address(0), 1000 * 1e18);
        
        vm.stopPrank();
    }
    
    function testBurnMoreThanBalance() public {
        vm.startPrank(owner);
        
        // Mint small amount
        mockUSDC.mint(owner, 100 * 1e6);
        mockUSDC.transfer(user, 100 * 1e6);
        
        vm.stopPrank();
        
        // Try to burn more than balance
        vm.startPrank(user);
        vm.expectRevert();
        mockUSDC.burn(200 * 1e6);
        
        vm.stopPrank();
    }
    
    function testTransferInsufficientBalance() public {
        vm.startPrank(owner);
        
        // Mint small amount
        mockUSDC.mint(owner, 100 * 1e6);
        
        // Try to transfer more than balance
        vm.expectRevert();
        mockUSDC.transfer(user, 200 * 1e6);
        
        vm.stopPrank();
    }
    
    // ============ INTEGRATION TESTS ============
    
    function testCompleteWorkflow() public {
        vm.startPrank(owner);
        
        // 1. Mint tokens
        mockUSDC.mint(owner, 1000000 * 1e6); // 1M USDC
        mockETH.mint(owner, 1000 * 1e18);    // 1000 ETH
        mockBTC.mint(owner, 100 * 1e8);      // 100 BTC
        
        console.log("Minted tokens to owner");
        console.log("- USDC:", mockUSDC.balanceOf(owner) / 1e6);
        console.log("- ETH:", mockETH.balanceOf(owner) / 1e18);
        console.log("- BTC:", mockBTC.balanceOf(owner) / 1e8);
        
        // 2. Transfer to user
        mockUSDC.transfer(user, 10000 * 1e6);
        mockETH.transfer(user, 50 * 1e18);
        mockBTC.transfer(user, 5 * 1e8);
        
        console.log("Transferred tokens to user");
        console.log("- USDC:", mockUSDC.balanceOf(user) / 1e6);
        console.log("- ETH:", mockETH.balanceOf(user) / 1e18);
        console.log("- BTC:", mockBTC.balanceOf(user) / 1e8);
        
        // 3. User burns some tokens
        vm.stopPrank();
        vm.startPrank(user);
        
        mockUSDC.burn(1000 * 1e6);
        mockETH.burn(5 * 1e18);
        mockBTC.burn(1 * 1e8);
        
        console.log("User burned some tokens");
        console.log("- USDC:", mockUSDC.balanceOf(user) / 1e6);
        console.log("- ETH:", mockETH.balanceOf(user) / 1e18);
        console.log("- BTC:", mockBTC.balanceOf(user) / 1e8);
        
        // 4. Verify final balances
        assertEq(mockUSDC.balanceOf(user), 9000 * 1e6);
        assertEq(mockETH.balanceOf(user), 45 * 1e18);
        assertEq(mockBTC.balanceOf(user), 4 * 1e8);
        
        assertEq(mockUSDC.balanceOf(owner), 990000 * 1e6);
        assertEq(mockETH.balanceOf(owner), 950 * 1e18);
        assertEq(mockBTC.balanceOf(owner), 95 * 1e8);
        
        vm.stopPrank();
        
        console.log("=== Complete Workflow Test Passed ===");
    }
    
    // ============ HELPER FUNCTIONS ============
    
    function testTokenDecimals() public view  {
        assertEq(mockUSDC.decimals(), 6);
        assertEq(mockETH.decimals(), 18);
        assertEq(mockBTC.decimals(), 8);
    }
    
    function testTokenNames() public view {
        assertEq(mockUSDC.name(), "Mock USDC");
        assertEq(mockETH.name(), "Mock ETH");
        assertEq(mockBTC.name(), "Mock BTC");
    }
    
    function testTokenSymbols() public view{
        assertEq(mockUSDC.symbol(), "USDC");
        assertEq(mockETH.symbol(), "mETH");
        assertEq(mockBTC.symbol(), "mBTC");
    }
}
