// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RestrictedWalletFactory.sol";
import "../src/RestrictedWallet.sol";

/**
 * @title RestrictedWalletFactoryTest
 * @notice Simplified test focusing on view functions and deployment
 * @dev Most functionality should be tested through LoanManager integration tests
 */
contract RestrictedWalletFactoryTest is Test {
    RestrictedWalletFactory public factory;
    
    address public user1;
    address public user2;
    address public loanManager;
    
    function setUp() public {
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        loanManager = makeAddr("loanManager");
        
        // Deploy RestrictedWalletFactory with loan manager
        factory = new RestrictedWalletFactory(loanManager);
    }
    
    // ============ DEPLOYMENT TESTS ============
    
    function testDeployment() public view {
        assertEq(factory.getWalletCount(), 0);
        assertEq(factory.loanManager(), loanManager);
        assertFalse(factory.hasWallet(user1));
    }
    
    // ============ VIEW FUNCTIONS TESTS ============
    
    function testGetWalletNoWallet() public view {
        assertEq(factory.getWallet(user1), address(0));
    }
    
    function testHasWalletFalse() public view {
        assertFalse(factory.hasWallet(user1));
    }
    
    function testGetAllWalletsEmpty() public view {
        address[] memory wallets = factory.getAllWallets();
        assertEq(wallets.length, 0);
    }
    
    function testGetWalletCountZero() public view {
        assertEq(factory.getWalletCount(), 0);
    }
    
    // ============ ACCESS CONTROL TESTS ============
    
    function testCreateWalletOnlyLoanManager() public {
        vm.expectRevert("Only loan manager");
        vm.prank(user1);
        factory.createWallet(user1);
    }
    
    function testGetOrCreateWalletOnlyLoanManager() public {
        vm.expectRevert("Only loan manager");
        vm.prank(user1);
        factory.getOrCreateWallet(user1);
    }
    
    // ============ LOANMANAGER INTEGRATION TESTS ============
    
    function testCreateWalletAsLoanManager() public {
        vm.prank(loanManager);
        address walletAddress = factory.createWallet(user1);
        
        // Verify wallet was created
        assertTrue(walletAddress != address(0));
        assertEq(factory.getWallet(user1), walletAddress);
        assertTrue(factory.hasWallet(user1));
        assertEq(factory.getWalletCount(), 1);
        
        // Verify wallet ownership
        RestrictedWallet wallet = RestrictedWallet(payable(walletAddress));
        assertEq(wallet.owner(), user1);
    }
    
    function testGetOrCreateWalletAsLoanManager() public {
        // First call should create new wallet
        vm.prank(loanManager);
        address walletAddress1 = factory.getOrCreateWallet(user1);
        
        assertTrue(walletAddress1 != address(0));
        assertEq(factory.getWallet(user1), walletAddress1);
        assertEq(factory.getWalletCount(), 1);
        
        // Second call should return existing wallet
        vm.prank(loanManager);
        address walletAddress2 = factory.getOrCreateWallet(user1);
        
        assertEq(walletAddress1, walletAddress2);
        assertEq(factory.getWalletCount(), 1); // No new wallet created
    }
    
    function testMultipleWalletsAsLoanManager() public {
        // Create wallets for different users via LoanManager
        vm.startPrank(loanManager);
        
        address wallet1 = factory.createWallet(user1);
        address wallet2 = factory.createWallet(user2);
        
        vm.stopPrank();
        
        // Verify both wallets exist and are different
        assertTrue(wallet1 != wallet2);
        assertEq(factory.getWallet(user1), wallet1);
        assertEq(factory.getWallet(user2), wallet2);
        assertEq(factory.getWalletCount(), 2);
        
        // Verify wallet ownership
        RestrictedWallet w1 = RestrictedWallet(payable(wallet1));
        RestrictedWallet w2 = RestrictedWallet(payable(wallet2));
        assertEq(w1.owner(), user1);
        assertEq(w2.owner(), user2);
    }
    
    function testGetAllWalletsAfterCreation() public {
        vm.startPrank(loanManager);
        
        address wallet1 = factory.createWallet(user1);
        address wallet2 = factory.createWallet(user2);
        
        vm.stopPrank();
        
        address[] memory wallets = factory.getAllWallets();
        assertEq(wallets.length, 2);
        assertEq(wallets[0], wallet1);
        assertEq(wallets[1], wallet2);
    }
} 