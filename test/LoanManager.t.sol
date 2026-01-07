// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LoanManager.sol";
import "../src/LendingPool.sol";
import "../src/CollateralManager.sol";
import "../src/RestrictedWalletFactory.sol";
import "../src/MockUSDC.sol";

contract LoanManagerTest is Test {
    LoanManager public loanManager;
    LendingPool public lendingPool;
    CollateralManager public collateralManager;
    RestrictedWalletFactory public walletFactory;
    MockUSDC public mockUSDC;
    
    address public borrower;
    address public investor;
    address public liquidator;
    
    // Test constants
    uint256 constant LOAN_AMOUNT = 10000 * 10**6; // 10,000 USDC
    uint256 constant COLLATERAL_AMOUNT = 2000 * 10**6; // 2,000 USDC (20%)
    uint256 constant POOL_FUNDING = 8000 * 10**6; // 8,000 USDC (80%)
    uint256 constant LARGE_AMOUNT = 100000 * 10**6; // 100,000 USDC
    
    // Events untuk testing
    event LoanCreated(
        address indexed borrower,
        uint256 loanAmount,
        uint256 marginAmount,
        uint256 poolFunding,
        address indexed restrictedWallet
    );
    
    event LoanRepaid(
        address indexed borrower,
        uint256 repaidAmount
    );
    
    function setUp() public {
        borrower = makeAddr("borrower");
        investor = makeAddr("investor");
        liquidator = makeAddr("liquidator");
        
        // Deploy MockUSDC
        mockUSDC = new MockUSDC();
        
        // Predict LoanManager address for circular dependency
        address predictedLoanManager = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 3);
        
        // Deploy contracts with predicted LoanManager address
        lendingPool = new LendingPool(address(mockUSDC), predictedLoanManager);
        collateralManager = new CollateralManager(predictedLoanManager);
        walletFactory = new RestrictedWalletFactory(predictedLoanManager);
        
        // Deploy LoanManager
        loanManager = new LoanManager(
            address(lendingPool),
            address(collateralManager),
            address(walletFactory),
            address(mockUSDC)
        );
        
        // Verify address prediction
        require(address(loanManager) == predictedLoanManager, "Address prediction failed");
        
        // Mint USDC for testing
        mockUSDC.mint(borrower, LARGE_AMOUNT);
        mockUSDC.mint(investor, LARGE_AMOUNT);
        
        // Approve LoanManager untuk borrower
        vm.prank(borrower);
        mockUSDC.approve(address(loanManager), type(uint256).max);
        
        // Approve LendingPool untuk investor
        vm.prank(investor);
        mockUSDC.approve(address(lendingPool), type(uint256).max);
        
        // Investor deposits to pool
        vm.prank(investor);
        lendingPool.deposit(LARGE_AMOUNT, investor);
    }
    
    // ============ DEPLOYMENT TESTS ============
    
    function testDeployment() public view {
        assertEq(address(loanManager.lendingPool()), address(lendingPool));
        assertEq(address(loanManager.collateralManager()), address(collateralManager));
        assertEq(address(loanManager.walletFactory()), address(walletFactory));
        assertEq(address(loanManager.usdcToken()), address(mockUSDC));
        assertEq(loanManager.totalLoans(), 0);
        assertEq(loanManager.totalRepaid(), 0);
    }
    
    // ============ CREATE LOAN TESTS ============
    
    function testCreateLoanSuccess() public {
        vm.expectEmit(true, false, false, true);
        emit LoanCreated(borrower, LOAN_AMOUNT, COLLATERAL_AMOUNT, POOL_FUNDING, address(0)); // We don't know wallet address yet
        
        vm.prank(borrower);
        bool success = loanManager.createLoan(LOAN_AMOUNT);
        
        assertTrue(success);
        assertEq(loanManager.totalLoans(), 1);
        
        // Check loan info
        LoanManager.LoanInfo memory loan = loanManager.getLoanInfo(borrower);
        assertEq(loan.loanAmount, LOAN_AMOUNT);
        assertEq(loan.marginAmount, COLLATERAL_AMOUNT);
        assertEq(loan.poolFunding, POOL_FUNDING);
        assertTrue(loan.isActive);
        assertTrue(loan.restrictedWallet != address(0));
        
        // Check borrower has active loan
        assertTrue(loanManager.hasActiveLoan(borrower));
        
        // Check wallet was created
        assertTrue(walletFactory.hasWallet(borrower));
    }
    
    function testCreateLoanZeroAmount() public {
        vm.expectRevert("Loan amount must be greater than 0");
        vm.prank(borrower);
        loanManager.createLoan(0);
    }
    
    function testCreateLoanActiveLoanExists() public {
        // Create first loan
        vm.prank(borrower);
        loanManager.createLoan(LOAN_AMOUNT);
        
        // Try to create second loan
        vm.expectRevert("Active loan exists");
        vm.prank(borrower);
        loanManager.createLoan(LOAN_AMOUNT);
    }
    
    function testCreateLoanInsufficientPoolLiquidity() public {
        // Try to create loan larger than pool liquidity
        uint256 largeLoan = LARGE_AMOUNT * 2;
        
        vm.expectRevert("Insufficient pool liquidity");
        vm.prank(borrower);
        loanManager.createLoan(largeLoan);
    }
    
    function testCreateLoanCalculations() public {
        vm.prank(borrower);
        loanManager.createLoan(LOAN_AMOUNT);
        
        // Check calculations are correct
        assertEq(loanManager.getRequiredMargin(LOAN_AMOUNT), COLLATERAL_AMOUNT);
        assertEq(loanManager.getPoolFunding(LOAN_AMOUNT), POOL_FUNDING);
    }
    
    // ============ REPAY LOAN TESTS ============
    
    function testRepayLoanSuccess() public {
        // Setup: create loan
        vm.prank(borrower);
        loanManager.createLoan(LOAN_AMOUNT);
        
        // Add some funds to RestrictedWallet to simulate trading
        LoanManager.LoanInfo memory loan = loanManager.getLoanInfo(borrower);
        mockUSDC.mint(loan.restrictedWallet, LOAN_AMOUNT); // Add funds for repayment
        
        vm.expectEmit(true, false, false, true);
        emit LoanRepaid(borrower, LOAN_AMOUNT * 2); // Event will contain total returned amount (original + minted)
        
        vm.prank(borrower);
        bool success = loanManager.repayLoan();
        
        assertTrue(success);
        assertEq(loanManager.totalRepaid(), 1);
        
        // Check loan is no longer active
        assertFalse(loanManager.hasActiveLoan(borrower));
        
        // Check loan info
        LoanManager.LoanInfo memory loanAfter = loanManager.getLoanInfo(borrower);
        assertFalse(loanAfter.isActive);
    }
    
    function testRepayLoanNoActiveLoan() public {
        vm.expectRevert("No active loan");
        vm.prank(borrower);
        loanManager.repayLoan();
    }
    
    // Note: testRepayLoanZeroAmount removed - repayLoan() no longer takes amount parameter
    
    // ============ VIEW FUNCTIONS TESTS ============
    
    function testGetLoanInfoNoLoan() public view {
        LoanManager.LoanInfo memory loan = loanManager.getLoanInfo(borrower);
        assertEq(loan.loanAmount, 0);
        assertEq(loan.marginAmount, 0);
        assertEq(loan.poolFunding, 0);
        assertEq(loan.startTime, 0);
        assertEq(loan.restrictedWallet, address(0));
        assertFalse(loan.isActive);
    }
    
    function testGetLoanInfoWithLoan() public {
        vm.prank(borrower);
        loanManager.createLoan(LOAN_AMOUNT);
        
        LoanManager.LoanInfo memory loan = loanManager.getLoanInfo(borrower);
        assertEq(loan.loanAmount, LOAN_AMOUNT);
        assertEq(loan.marginAmount, COLLATERAL_AMOUNT);
        assertEq(loan.poolFunding, POOL_FUNDING);
        assertGt(loan.startTime, 0);
        assertTrue(loan.restrictedWallet != address(0));
        assertTrue(loan.isActive);
    }
    
    function testHasActiveLoanFalse() public view {
        assertFalse(loanManager.hasActiveLoan(borrower));
    }
    
    function testHasActiveLoanTrue() public {
        vm.prank(borrower);
        loanManager.createLoan(LOAN_AMOUNT);
        
        assertTrue(loanManager.hasActiveLoan(borrower));
    }
    
    function testGetRequiredMargin() public view {
        assertEq(loanManager.getRequiredMargin(LOAN_AMOUNT), COLLATERAL_AMOUNT);
        assertEq(loanManager.getRequiredMargin(5000 * 10**6), 1000 * 10**6); // 20% of 5000
    }
    
    function testGetPoolFunding() public view {
        assertEq(loanManager.getPoolFunding(LOAN_AMOUNT), POOL_FUNDING);
        assertEq(loanManager.getPoolFunding(5000 * 10**6), 4000 * 10**6); // 80% of 5000
    }
    
    function testGetLoanStats() public {
        // Check initial stats
        (uint256 totalCreated, uint256 totalRepaid, uint256 active) = loanManager.getLoanStats();
        assertEq(totalCreated, 0);
        assertEq(totalRepaid, 0);
        assertEq(active, 0);
        
        // Create loan
        vm.prank(borrower);
        loanManager.createLoan(LOAN_AMOUNT);
        
        (totalCreated, totalRepaid, active) = loanManager.getLoanStats();
        assertEq(totalCreated, 1);
        assertEq(totalRepaid, 0);
        assertEq(active, 1);
        
        // Repay loan (add funds first)
        LoanManager.LoanInfo memory loan = loanManager.getLoanInfo(borrower);
        mockUSDC.mint(loan.restrictedWallet, LOAN_AMOUNT);
        
        vm.prank(borrower);
        loanManager.repayLoan();
        
        (totalCreated, totalRepaid, active) = loanManager.getLoanStats();
        assertEq(totalCreated, 1);
        assertEq(totalRepaid, 1);
        assertEq(active, 0);
    }
    
    function testCanCreateLoan() public {
        // Can create loan when no active loan and sufficient liquidity
        assertTrue(loanManager.canCreateLoan(borrower, LOAN_AMOUNT));
        
        // Cannot create loan when amount is 0
        assertFalse(loanManager.canCreateLoan(borrower, 0));
        
        // Cannot create loan when insufficient liquidity
        assertFalse(loanManager.canCreateLoan(borrower, LARGE_AMOUNT * 2));
        
        // Create loan
        vm.prank(borrower);
        loanManager.createLoan(LOAN_AMOUNT);
        
        // Cannot create loan when active loan exists
        assertFalse(loanManager.canCreateLoan(borrower, LOAN_AMOUNT));
    }
    
    // ============ INTEGRATION TESTS ============
    
    function testFullLoanCycle() public {
        // 1. Create loan
        vm.prank(borrower);
        loanManager.createLoan(LOAN_AMOUNT);
        
        // 2. Verify loan was created in all components
        assertTrue(loanManager.hasActiveLoan(borrower));
        assertTrue(walletFactory.hasWallet(borrower));
        
        // 3. Check loan record was created in CollateralManager
        assertTrue(collateralManager.hasActiveLoan(borrower));
        
        // 4. Check total loan amount was allocated to RestrictedWallet
        address wallet = walletFactory.getWallet(borrower);
        assertEq(mockUSDC.balanceOf(wallet), LOAN_AMOUNT); // Total = pool funding + margin
        
        // 5. Repay loan (add funds first)
        mockUSDC.mint(wallet, LOAN_AMOUNT);
        
        vm.prank(borrower);
        loanManager.repayLoan();
        
        // 6. Verify loan was repaid in all components
        assertFalse(loanManager.hasActiveLoan(borrower));
        
        // 7. Check borrower can create new loan
        vm.prank(borrower);
        loanManager.createLoan(LOAN_AMOUNT);
        assertTrue(loanManager.hasActiveLoan(borrower));
    }
    
    function testMultipleBorrowers() public {
        address borrower2 = makeAddr("borrower2");
        mockUSDC.mint(borrower2, LARGE_AMOUNT);
        vm.prank(borrower2);
        mockUSDC.approve(address(loanManager), type(uint256).max);
        
        // Create loans for both borrowers
        vm.prank(borrower);
        loanManager.createLoan(LOAN_AMOUNT);
        
        vm.prank(borrower2);
        loanManager.createLoan(LOAN_AMOUNT);
        
        // Verify both have active loans
        assertTrue(loanManager.hasActiveLoan(borrower));
        assertTrue(loanManager.hasActiveLoan(borrower2));
        
        // Verify different wallets were created
        address wallet1 = walletFactory.getWallet(borrower);
        address wallet2 = walletFactory.getWallet(borrower2);
        assertTrue(wallet1 != wallet2);
        
        // Check loan stats
        (uint256 totalCreated, , uint256 active) = loanManager.getLoanStats();
        assertEq(totalCreated, 2);
        assertEq(active, 2);
    }
    
    // ============ FUZZ TESTS ============
    
    function testFuzzCreateLoan(uint256 loanAmount) public {
        vm.assume(loanAmount > 0 && loanAmount <= LARGE_AMOUNT);
        
        vm.prank(borrower);
        bool success = loanManager.createLoan(loanAmount);
        
        assertTrue(success);
        assertTrue(loanManager.hasActiveLoan(borrower));
        
        // Check calculations match actual implementation
        uint256 expectedCollateral = (loanAmount * 20) / 100;
        uint256 expectedPoolFunding = loanAmount - expectedCollateral; // Use same calculation as implementation
        
        LoanManager.LoanInfo memory loan = loanManager.getLoanInfo(borrower);
        assertEq(loan.marginAmount, expectedCollateral);
        assertEq(loan.poolFunding, expectedPoolFunding);
    }
} 