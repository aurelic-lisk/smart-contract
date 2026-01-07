// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MockUSDC.sol";
import "../src/CollateralManager.sol";
import "../src/LoanManager.sol";

contract CollateralManagerTest is Test {
    MockUSDC public mockUSDC;
    CollateralManager public collateralManager;
    address public loanManager;
    
    address public user1;
    address public user2;
    address public liquidator;
    
    uint256 constant LARGE_AMOUNT = 1_000_000 * 1e6; // 1M USDC
    uint256 constant COLLATERAL_AMOUNT = 200 * 1e6;   // 200 USDC
    uint256 constant LOAN_AMOUNT = 1000 * 1e6;        // 1000 USDC
    
    // Events untuk testing
    event LoanRecordCreated(address indexed borrower, uint256 marginAmount, uint256 loanAmount);
    event LoanRepaid(address indexed borrower);
    event LoanLiquidated(address indexed borrower);
    
    function setUp() public {
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        liquidator = makeAddr("liquidator");
        loanManager = makeAddr("loanManager");
        
        // Deploy MockUSDC
        mockUSDC = new MockUSDC();
        
        // Deploy CollateralManager with loan manager address
        collateralManager = new CollateralManager(loanManager);
        
        // Mint USDC for testing
        mockUSDC.mint(user1, LARGE_AMOUNT);
        mockUSDC.mint(user2, LARGE_AMOUNT);
        mockUSDC.mint(liquidator, LARGE_AMOUNT);
    }
    
    // ============ DEPLOYMENT TESTS ============
    
    function testDeployment() public view {
        assertEq(collateralManager.loanManager(), loanManager);
        assertEq(collateralManager.MARGIN_BPS(), 2000); // 20%
        assertEq(collateralManager.BASIS_POINTS(), 10000);
        assertEq(collateralManager.LOAN_DURATION(), 30 days);
    }
    
    // ============ LOAN RECORD CREATION TESTS ============
    
    function testCreateLoanRecordSuccess() public {
        vm.expectEmit(true, false, false, true);
        emit LoanRecordCreated(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        
        CollateralManager.LoanRecord memory record = collateralManager.getLoanRecord(user1);
        assertEq(record.marginAmount, COLLATERAL_AMOUNT);
        assertEq(record.loanAmount, LOAN_AMOUNT);
        assertTrue(record.isActive);
        assertGt(record.startTime, 0);
    }
    
    function testCreateLoanRecordOnlyLoanManager() public {
        vm.expectRevert("Only loan manager");
        vm.prank(user1);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
    }
    
    function testCreateLoanRecordActiveLoanExists() public {
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        
        vm.expectRevert("Active loan exists");
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
    }
    
    function testCreateLoanRecordInvalidBorrower() public {
        vm.expectRevert("Invalid borrower");
        vm.prank(loanManager);
        collateralManager.createLoanRecord(address(0), COLLATERAL_AMOUNT, LOAN_AMOUNT);
    }
    
    // ============ MARGIN VALIDATION TESTS ============
    
    function testValidateMarginSuccess() public view {
        // 200 USDC margin for 1000 USDC loan = 20% ✓
        assertTrue(collateralManager.validateMargin(COLLATERAL_AMOUNT, LOAN_AMOUNT));
    }
    
    function testValidateMarginInsufficient() public view {
        // 100 USDC margin for 1000 USDC loan = 10% ✗
        assertFalse(collateralManager.validateMargin(100 * 1e6, LOAN_AMOUNT));
    }
    
    function testValidateMarginExact() public view {
        // 200 USDC margin for 1000 USDC loan = exactly 20% ✓
        assertTrue(collateralManager.validateMargin(200 * 1e6, 1000 * 1e6));
    }
    
    function testValidateMarginZeroLoan() public view {
        assertFalse(collateralManager.validateMargin(COLLATERAL_AMOUNT, 0));
    }
    
    // ============ LOAN REPAYMENT TESTS ============
    
    function testRepayLoanSuccess() public {
        // Setup: create loan record
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        
        vm.expectEmit(true, false, false, true);
        emit LoanRepaid(user1);
        
        vm.prank(loanManager);
        collateralManager.repayLoan(user1);
        
        // Check loan is cleared
        CollateralManager.LoanRecord memory record = collateralManager.getLoanRecord(user1);
        assertFalse(record.isActive);
    }
    
    function testRepayLoanOnlyLoanManager() public {
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        
        vm.expectRevert("Only loan manager");
        vm.prank(user1);
        collateralManager.repayLoan(user1);
    }
    
    function testRepayLoanNoActiveLoan() public {
        vm.expectRevert("No active loan");
        vm.prank(loanManager);
        collateralManager.repayLoan(user1);
    }
    
    // ============ LIQUIDATION TESTS ============
    
    function testLiquidateLoanSuccess() public {
        // Setup: create loan record
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        
        vm.expectEmit(true, false, false, true);
        emit LoanLiquidated(user1);
        
        vm.prank(loanManager);
        collateralManager.liquidateLoan(user1);
        
        // Check position is cleared
        CollateralManager.LoanRecord memory record = collateralManager.getLoanRecord(user1);
        assertFalse(record.isActive);
    }
    
    function testLiquidateLoanOnlyLoanManager() public {
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        
        vm.expectRevert("Only loan manager");
        vm.prank(user1);
        collateralManager.liquidateLoan(user1);
    }
    
    function testLiquidateLoanNoActiveLoan() public {
        vm.expectRevert("No active loan");
        vm.prank(loanManager);
        collateralManager.liquidateLoan(user1);
    }
    
    // ============ LIQUIDATION CHECK TESTS ============
    
    function testIsLiquidatableFalse() public {
        // No loan record
        assertFalse(collateralManager.isLiquidatable(user1));
        
        // Active loan but not expired
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        assertFalse(collateralManager.isLiquidatable(user1));
    }
    
    function testIsLiquidatableTrue() public {
        // Setup: create loan record
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        
        // Fast forward 31 days
        vm.warp(block.timestamp + 31 days);
        
        assertTrue(collateralManager.isLiquidatable(user1));
    }
    
    function testIsLiquidatableAfterRepayment() public {
        // Setup: create and repay loan
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        
        vm.prank(loanManager);
        collateralManager.repayLoan(user1);
        
        // Should not be liquidatable after repayment
        assertFalse(collateralManager.isLiquidatable(user1));
    }
    
    // ============ LOAN DUE CHECK TESTS ============
    
    function testIsLoanDueFalse() public {
        // No loan record
        assertFalse(collateralManager.isLoanDue(user1));
        
        // Active loan but not expired
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        assertFalse(collateralManager.isLoanDue(user1));
    }
    
    function testIsLoanDueTrue() public {
        // Setup: create loan record
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        
        // Fast forward 31 days
        vm.warp(block.timestamp + 31 days);
        
        assertTrue(collateralManager.isLoanDue(user1));
    }
    
    // ============ VIEW FUNCTIONS TESTS ============
    
    function testGetLoanRecordNoLoan() public view {
        CollateralManager.LoanRecord memory record = collateralManager.getLoanRecord(user1);
        assertEq(record.marginAmount, 0);
        assertEq(record.loanAmount, 0);
        assertEq(record.startTime, 0);
        assertFalse(record.isActive);
    }
    
    function testGetLoanRecordWithLoan() public {
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        
        CollateralManager.LoanRecord memory record = collateralManager.getLoanRecord(user1);
        assertEq(record.marginAmount, COLLATERAL_AMOUNT);
        assertEq(record.loanAmount, LOAN_AMOUNT);
        assertGt(record.startTime, 0);
        assertTrue(record.isActive);
    }
    
    function testHasActiveLoanFalse() public view {
        assertFalse(collateralManager.hasActiveLoan(user1));
    }
    
    function testHasActiveLoanTrue() public {
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        
        assertTrue(collateralManager.hasActiveLoan(user1));
    }
    
    function testHasActiveLoanAfterRepayment() public {
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        
        vm.prank(loanManager);
        collateralManager.repayLoan(user1);
        
        assertFalse(collateralManager.hasActiveLoan(user1));
    }
    
    // ============ INTEGRATION TESTS ============
    
    function testMultipleUsers() public {
        // Create loans for multiple users
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user2, COLLATERAL_AMOUNT * 2, LOAN_AMOUNT * 2);
        
        // Verify both have active loans
        assertTrue(collateralManager.hasActiveLoan(user1));
        assertTrue(collateralManager.hasActiveLoan(user2));
        
        // Verify different records
        CollateralManager.LoanRecord memory record1 = collateralManager.getLoanRecord(user1);
        CollateralManager.LoanRecord memory record2 = collateralManager.getLoanRecord(user2);
        
        assertEq(record1.marginAmount, COLLATERAL_AMOUNT);
        assertEq(record2.marginAmount, COLLATERAL_AMOUNT * 2);
        assertTrue(record1.isActive);
        assertTrue(record2.isActive);
    }
    
    function testFullLoanLifecycle() public {
        // 1. Create loan record
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        
        assertTrue(collateralManager.hasActiveLoan(user1));
        assertFalse(collateralManager.isLiquidatable(user1));
        
        // 2. Fast forward to liquidation time
        vm.warp(block.timestamp + 31 days);
        
        assertTrue(collateralManager.isLiquidatable(user1));
        assertTrue(collateralManager.isLoanDue(user1));
        
        // 3. Liquidate position
        vm.prank(loanManager);
        collateralManager.liquidateLoan(user1);
        
        assertFalse(collateralManager.hasActiveLoan(user1));
        assertFalse(collateralManager.isLiquidatable(user1));
        
        // 4. Can create new loan
        vm.prank(loanManager);
        collateralManager.createLoanRecord(user1, COLLATERAL_AMOUNT, LOAN_AMOUNT);
        
        assertTrue(collateralManager.hasActiveLoan(user1));
    }
} 