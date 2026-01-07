// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LendingPool.sol";
import "../src/MockUSDC.sol";

contract LendingPoolTest is Test {
    LendingPool public lendingPool;
    MockUSDC public mockUSDC;
    
    address public investor1;
    address public investor2;
    address public borrower;
    address public loanManager;
    
    // Test constants
    uint256 constant DEPOSIT_AMOUNT = 10000 * 10**6; // 10,000 USDC
    uint256 constant LOAN_AMOUNT = 8000 * 10**6; // 8,000 USDC (80% funding)
    uint256 constant LARGE_AMOUNT = 100000 * 10**6; // 100,000 USDC
    
    // ERC4626 Events
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
    event FundsAllocated(address indexed borrower, uint256 amount);
    event FundsRepaid(address indexed borrower, uint256 amount);
    event YieldAccrued(uint256 yieldAmount, uint256 timestamp);
    
    function setUp() public {
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");
        borrower = makeAddr("borrower");
        loanManager = makeAddr("loanManager");
        
        // Deploy MockUSDC
        mockUSDC = new MockUSDC();
        
        // Deploy LendingPool with loan manager address
        lendingPool = new LendingPool(address(mockUSDC), loanManager);
        
        // Mint USDC for testing
        mockUSDC.mint(investor1, LARGE_AMOUNT);
        mockUSDC.mint(investor2, LARGE_AMOUNT);
        mockUSDC.mint(borrower, LARGE_AMOUNT);
        
        // Approve LendingPool to spend USDC
        vm.prank(investor1);
        mockUSDC.approve(address(lendingPool), type(uint256).max);
        
        vm.prank(investor2);
        mockUSDC.approve(address(lendingPool), type(uint256).max);
        
        vm.prank(borrower);
        mockUSDC.approve(address(lendingPool), type(uint256).max);
    }
    
    // ============ DEPLOYMENT TESTS ============
    
    function testDeployment() public view {
        assertEq(address(lendingPool.asset()), address(mockUSDC));
        assertEq(lendingPool.loanManager(), loanManager);
        assertEq(lendingPool.FIXED_APY(), 600); // 6%
        assertEq(lendingPool.BASIS_POINTS(), 10000);
        assertEq(lendingPool.SECONDS_PER_YEAR(), 365 days);
        assertEq(lendingPool.totalAssets(), 0);
        assertEq(lendingPool.totalSupply(), 0);
        assertEq(lendingPool.totalAllocated(), 0);
    }
    
    // ============ DEPOSIT TESTS ============
    
    function testDepositSuccess() public {
        vm.expectEmit(true, true, false, true);
        emit Deposit(investor1, investor1, DEPOSIT_AMOUNT, DEPOSIT_AMOUNT);
        
        vm.prank(investor1);
        uint256 shares = lendingPool.deposit(DEPOSIT_AMOUNT, investor1);
        
        assertEq(shares, DEPOSIT_AMOUNT); // 1:1 ratio for first deposit
        assertEq(lendingPool.balanceOf(investor1), DEPOSIT_AMOUNT);
        assertEq(lendingPool.totalAssets(), DEPOSIT_AMOUNT);
        assertEq(lendingPool.totalSupply(), DEPOSIT_AMOUNT);
        assertEq(mockUSDC.balanceOf(address(lendingPool)), DEPOSIT_AMOUNT);
        assertEq(mockUSDC.balanceOf(investor1), LARGE_AMOUNT - DEPOSIT_AMOUNT);
    }
    
    function testDepositZeroAmount() public {
        vm.expectRevert("Amount must be greater than 0");
        vm.prank(investor1);
        lendingPool.deposit(0, investor1);
    }
    
    function testDepositWithYieldAccrual() public {
        // First deposit
        vm.prank(investor1);
        lendingPool.deposit(DEPOSIT_AMOUNT, investor1);
        
        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);
        
        // Second deposit should accrue yield first
        vm.prank(investor2);
        uint256 shares = lendingPool.deposit(DEPOSIT_AMOUNT, investor2);
        
        // Check that yield was accrued
        assertGt(lendingPool.totalAssets(), 2 * DEPOSIT_AMOUNT);
        assertGt(lendingPool.getYieldBaseBalance(), DEPOSIT_AMOUNT);
        
        // Second depositor should get fewer shares due to accrued yield
        assertLt(shares, DEPOSIT_AMOUNT);
    }
    
    // ============ WITHDRAW TESTS ============
    
    function testWithdrawSuccess() public {
        // Setup: deposit
        vm.prank(investor1);
        lendingPool.deposit(DEPOSIT_AMOUNT, investor1);
        
        uint256 withdrawAmount = DEPOSIT_AMOUNT / 2;
        uint256 balanceBefore = mockUSDC.balanceOf(investor1);
        
        vm.expectEmit(true, true, true, false);
        emit Withdraw(investor1, investor1, investor1, withdrawAmount, withdrawAmount);
        
        vm.prank(investor1);
        uint256 shares = lendingPool.withdraw(withdrawAmount, investor1, investor1);
        
        assertEq(shares, withdrawAmount); // 1:1 ratio
        assertEq(lendingPool.balanceOf(investor1), DEPOSIT_AMOUNT - withdrawAmount);
        assertEq(mockUSDC.balanceOf(investor1), balanceBefore + withdrawAmount);
    }
    
    function testRedeemSuccess() public {
        // Setup: deposit
        vm.prank(investor1);
        lendingPool.deposit(DEPOSIT_AMOUNT, investor1);
        
        uint256 redeemShares = DEPOSIT_AMOUNT / 2;
        uint256 balanceBefore = mockUSDC.balanceOf(investor1);
        
        vm.prank(investor1);
        uint256 assets = lendingPool.redeem(redeemShares, investor1, investor1);
        
        assertEq(assets, redeemShares); // 1:1 ratio
        assertEq(lendingPool.balanceOf(investor1), DEPOSIT_AMOUNT - redeemShares);
        assertEq(mockUSDC.balanceOf(investor1), balanceBefore + assets);
    }
    
    function testWithdrawWithYield() public {
        // Setup: deposit
        vm.prank(investor1);
        lendingPool.deposit(DEPOSIT_AMOUNT, investor1);
        
        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);
        
        uint256 balanceBefore = mockUSDC.balanceOf(investor1);
        uint256 sharesBefore = lendingPool.balanceOf(investor1);
        
        vm.prank(investor1);
        uint256 assets = lendingPool.redeem(sharesBefore, investor1, investor1);
        
        // For PoC: Only principal is withdrawn, yield is tracked conceptually
        assertEq(assets, DEPOSIT_AMOUNT);
        assertEq(lendingPool.balanceOf(investor1), 0);
        assertEq(mockUSDC.balanceOf(investor1), balanceBefore + assets);
        
        // Verify yield was accrued conceptually
        assertGt(lendingPool.totalAccruedYield(), 0);
    }
    
    function testWithdrawInsufficientBalance() public {
        vm.expectRevert("Insufficient pool liquidity");
        vm.prank(investor1);
        lendingPool.withdraw(DEPOSIT_AMOUNT, investor1, investor1);
    }
    
    // ============ FUND ALLOCATION TESTS ============
    
    function testAllocateFundsSuccess() public {
        // Setup: deposit to pool
        vm.prank(investor1);
        lendingPool.deposit(DEPOSIT_AMOUNT, investor1);
        
        uint256 borrowerBalanceBefore = mockUSDC.balanceOf(borrower);
        
        vm.expectEmit(true, false, false, true);
        emit FundsAllocated(borrower, LOAN_AMOUNT);
        
        vm.prank(loanManager);
        lendingPool.allocateFunds(borrower, LOAN_AMOUNT);
        
        assertEq(lendingPool.totalAllocated(), LOAN_AMOUNT);
        assertEq(mockUSDC.balanceOf(borrower), borrowerBalanceBefore + LOAN_AMOUNT);
        assertEq(lendingPool.getAvailableLiquidity(), DEPOSIT_AMOUNT - LOAN_AMOUNT);
    }
    
    function testAllocateFundsOnlyLoanManager() public {
        vm.prank(investor1);
        lendingPool.deposit(DEPOSIT_AMOUNT, investor1);
        
        vm.expectRevert("Only loan manager");
        vm.prank(investor1);
        lendingPool.allocateFunds(borrower, LOAN_AMOUNT);
    }
    
    function testAllocateFundsInsufficientLiquidity() public {
        vm.expectRevert("Insufficient pool liquidity");
        vm.prank(loanManager);
        lendingPool.allocateFunds(borrower, LOAN_AMOUNT);
    }
    
    // ============ REPAYMENT TESTS ============
    
    function testRepayFundsSuccess() public {
        // Setup: deposit and allocate
        vm.prank(investor1);
        lendingPool.deposit(DEPOSIT_AMOUNT, investor1);
        
        vm.prank(loanManager);
        lendingPool.allocateFunds(borrower, LOAN_AMOUNT);
        
        // Simulate loan manager transferring repayment to pool
        vm.prank(borrower);
        mockUSDC.transfer(address(lendingPool), LOAN_AMOUNT);
        
        vm.expectEmit(true, false, false, true);
        emit FundsRepaid(borrower, LOAN_AMOUNT);
        
        vm.prank(loanManager);
        lendingPool.repayFunds(borrower, LOAN_AMOUNT);
        
        assertEq(lendingPool.totalAllocated(), 0);
        // After repayment, pool balance returns to original deposit amount
        assertEq(lendingPool.getAvailableLiquidity(), DEPOSIT_AMOUNT);
        assertEq(lendingPool.getYieldBaseBalance(), DEPOSIT_AMOUNT + LOAN_AMOUNT);
    }
    
    function testRepayFundsOnlyLoanManager() public {
        vm.expectRevert("Only loan manager");
        vm.prank(borrower);
        lendingPool.repayFunds(borrower, LOAN_AMOUNT);
    }
    
    // ============ YIELD ACCRUAL TESTS ============
    
    function testYieldAccrual() public {
        vm.prank(investor1);
        lendingPool.deposit(DEPOSIT_AMOUNT, investor1);
        
        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);
        
        uint256 pendingYield = lendingPool.getPendingYield();
        uint256 expectedYield = (DEPOSIT_AMOUNT * 600) / 10000; // 6% APY
        
        assertApproxEqRel(pendingYield, expectedYield, 0.01e18); // 1% tolerance
        
        // Manually accrue yield
        vm.expectEmit(false, false, false, true);
        emit YieldAccrued(pendingYield, block.timestamp);
        
        lendingPool.accrueYield();
        
        assertEq(lendingPool.getPendingYield(), 0);
        assertApproxEqRel(lendingPool.getYieldBaseBalance(), DEPOSIT_AMOUNT + expectedYield, 0.01e18);
    }
    
    // ============ VIEW FUNCTIONS TESTS ============
    
    function testGetPoolStats() public {
        vm.prank(investor1);
        lendingPool.deposit(DEPOSIT_AMOUNT, investor1);
        
        vm.prank(loanManager);
        lendingPool.allocateFunds(borrower, LOAN_AMOUNT);
        
        (
            uint256 totalAssetsAmount,
            uint256 totalAllocatedAmount,
            uint256 availableLiquidity,
            uint256 totalShares,
            uint256 currentAPY
        ) = lendingPool.getPoolStats();
        
        // After allocation, pool balance is reduced but shares remain the same
        assertEq(totalAssetsAmount, DEPOSIT_AMOUNT - LOAN_AMOUNT); // 2 USDC remaining
        assertEq(totalAllocatedAmount, LOAN_AMOUNT);
        assertEq(availableLiquidity, DEPOSIT_AMOUNT - LOAN_AMOUNT);
        assertEq(totalShares, DEPOSIT_AMOUNT); // Shares unchanged
        assertEq(currentAPY, 600); // 6%
    }
    
    function testGetUserInfo() public {
        vm.prank(investor1);
        lendingPool.deposit(DEPOSIT_AMOUNT, investor1);
        
        // Fast forward 6 months
        vm.warp(block.timestamp + 182 days);
        
        (
            uint256 shares,
            uint256 assets
        ) = lendingPool.getUserInfo(investor1);
        
        assertEq(shares, DEPOSIT_AMOUNT);
        assertGt(assets, DEPOSIT_AMOUNT); // Should include accrued yield
    }
    
    function testCanFundLoan() public {
        assertFalse(lendingPool.canFundLoan(LOAN_AMOUNT));
        
        vm.prank(investor1);
        lendingPool.deposit(DEPOSIT_AMOUNT, investor1);
        
        assertTrue(lendingPool.canFundLoan(LOAN_AMOUNT));
        assertFalse(lendingPool.canFundLoan(DEPOSIT_AMOUNT + 1));
    }
    
    // ============ PREVIEW FUNCTIONS TESTS ============
    
    function testPreviewFunctions() public {
        // Test with empty pool
        assertEq(lendingPool.previewDeposit(DEPOSIT_AMOUNT), DEPOSIT_AMOUNT);
        
        // Add some deposits
        vm.prank(investor1);
        lendingPool.deposit(DEPOSIT_AMOUNT, investor1);
        
        // Fast forward to accrue yield
        vm.warp(block.timestamp + 365 days);
        
        // Preview should include pending yield
        uint256 previewShares = lendingPool.previewDeposit(DEPOSIT_AMOUNT);
        assertLt(previewShares, DEPOSIT_AMOUNT); // Should get fewer shares due to yield
        
        uint256 previewAssets = lendingPool.previewRedeem(DEPOSIT_AMOUNT);
        assertGt(previewAssets, DEPOSIT_AMOUNT); // Should get more assets due to yield
    }
    
    // ============ INTEGRATION TESTS ============
    
    function testFullLoanCycle() public {
        // 1. Investor deposits
        vm.prank(investor1);
        lendingPool.deposit(DEPOSIT_AMOUNT, investor1);
        
        // 2. Loan manager allocates funds
        vm.prank(loanManager);
        lendingPool.allocateFunds(borrower, LOAN_AMOUNT);
        
        // 3. Some time passes
        vm.warp(block.timestamp + 30 days);
        
        // 4. Loan manager receives repayment
        vm.prank(borrower);
        mockUSDC.transfer(address(lendingPool), LOAN_AMOUNT);
        
        vm.prank(loanManager);
        lendingPool.repayFunds(borrower, LOAN_AMOUNT);
        
        // 5. Investor redeems all shares
        uint256 balanceBefore = mockUSDC.balanceOf(investor1);
        uint256 shares = lendingPool.balanceOf(investor1);
        
        vm.prank(investor1);
        uint256 assets = lendingPool.redeem(shares, investor1, investor1);
        
        // For PoC: Investor receives principal back, yield tracked conceptually
        assertEq(assets, DEPOSIT_AMOUNT);
        assertEq(mockUSDC.balanceOf(investor1), balanceBefore + assets);
        assertEq(lendingPool.balanceOf(investor1), 0);
    }
    
    // ============ FUZZ TESTS ============
    
    function testFuzzDeposit(uint256 amount) public {
        vm.assume(amount > 0 && amount <= LARGE_AMOUNT);
        
        vm.prank(investor1);
        uint256 shares = lendingPool.deposit(amount, investor1);
        
        assertEq(lendingPool.balanceOf(investor1), shares);
        assertEq(lendingPool.totalAssets(), amount);
        assertEq(lendingPool.totalSupply(), shares);
    }
    
    function testFuzzRedeem(uint256 depositAmount, uint256 redeemShares) public {
        vm.assume(depositAmount > 0 && depositAmount <= LARGE_AMOUNT);
        
        vm.prank(investor1);
        uint256 shares = lendingPool.deposit(depositAmount, investor1);
        
        vm.assume(redeemShares > 0 && redeemShares <= shares);
        
        uint256 balanceBefore = mockUSDC.balanceOf(investor1);
        
        vm.prank(investor1);
        uint256 assets = lendingPool.redeem(redeemShares, investor1, investor1);
        
        assertEq(lendingPool.balanceOf(investor1), shares - redeemShares);
        assertEq(mockUSDC.balanceOf(investor1), balanceBefore + assets);
    }
} 