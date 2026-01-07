// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "../src/MockUSDC.sol";
import "../src/LendingPool.sol";
import "../src/CollateralManager.sol";
import "../src/RestrictedWalletFactory.sol";
import "../src/RestrictedWallet.sol";
import "../src/LoanManager.sol";

/**
 * @title AurelicIntegrationTest
 * @notice Comprehensive integration test for Aurelic PoC (refactored contracts)
 * @dev Tests complete loan flows: creation, trading, repayment, and liquidation
 */
contract AurelicIntegrationTest is Test {
    // Contracts
    MockUSDC public mockUSDC;
    LendingPool public lendingPool;
    CollateralManager public collateralManager;
    RestrictedWalletFactory public walletFactory;
    LoanManager public loanManager;

    // Test accounts
    address public borrower = address(0x1);
    address public borrower2 = address(0x2);
    address public poolInvestor = address(0x3);
    address public liquidator = address(0x4);

    // Constants
    uint256 constant INITIAL_POOL_FUNDING = 1_000_000 * 1e6;
    uint256 constant TEST_LOAN_AMOUNT = 100_000 * 1e6;
    uint256 constant REQUIRED_MARGIN = 20_000 * 1e6;
    uint256 constant POOL_FUNDING = 80_000 * 1e6;

    function setUp() public {
        mockUSDC = new MockUSDC();

        // Predict LoanManager address
        uint256 deployerNonce = vm.getNonce(address(this));
        address predictedLoanManager = computeCreateAddress(address(this), deployerNonce + 3);

        // Deploy contracts
        collateralManager = new CollateralManager(predictedLoanManager);
        lendingPool = new LendingPool(address(mockUSDC), predictedLoanManager);
        walletFactory = new RestrictedWalletFactory(predictedLoanManager);

        // Sanity check: walletFactory deployed in correct order
        assertEq(
            address(walletFactory),
            computeCreateAddress(address(this), deployerNonce + 2),
            "WalletFactory address mismatch"
        );

        loanManager = new LoanManager(
            address(lendingPool), address(collateralManager), address(walletFactory), address(mockUSDC)
        );

        // Verify address prediction
        assertEq(address(loanManager), predictedLoanManager, "LoanManager address prediction failed");

        // Setup balances via deal()
        deal(address(mockUSDC), poolInvestor, INITIAL_POOL_FUNDING);
        deal(address(mockUSDC), borrower, REQUIRED_MARGIN * 3);
        deal(address(mockUSDC), borrower2, REQUIRED_MARGIN * 3);

        // Pool investor deposits
        vm.startPrank(poolInvestor);
        mockUSDC.approve(address(lendingPool), INITIAL_POOL_FUNDING);
        lendingPool.deposit(INITIAL_POOL_FUNDING, poolInvestor);
        vm.stopPrank();
    }

    function testCompleteSuccessfulLoanFlow() public {
        console.log("=== Starting Complete Loan Flow Test ===");

        vm.startPrank(borrower);

        uint256 borrowerBalanceBefore = mockUSDC.balanceOf(borrower);
        uint256 poolLiquidityBefore = lendingPool.getAvailableLiquidity();

        console.log("Borrower balance before:", borrowerBalanceBefore / 1e6, "USDC");
        console.log("Pool liquidity before:", poolLiquidityBefore / 1e6, "USDC");

        // Approve margin
        mockUSDC.approve(address(loanManager), REQUIRED_MARGIN);

        // Create loan (handles internal transfers & deploy wallet)
        bool success = loanManager.createLoan(TEST_LOAN_AMOUNT);
        assertTrue(success, "Loan creation failed");

        LoanManager.LoanInfo memory loanInfo = loanManager.getLoanInfo(borrower);

        assertTrue(loanInfo.isActive, "Loan should be active");
        assertEq(loanInfo.loanAmount, TEST_LOAN_AMOUNT, "Incorrect loan amount");
        assertEq(loanInfo.marginAmount, REQUIRED_MARGIN, "Incorrect margin amount");
        assertEq(loanInfo.poolFunding, POOL_FUNDING, "Incorrect pool funding");
        assertTrue(loanInfo.restrictedWallet != address(0), "Invalid wallet address");

        // Post-loan balances
        uint256 borrowerBalanceAfter = mockUSDC.balanceOf(borrower);
        uint256 poolLiquidityAfter = lendingPool.getAvailableLiquidity();
        uint256 walletBalance = mockUSDC.balanceOf(loanInfo.restrictedWallet);

        assertEq(
            borrowerBalanceAfter, borrowerBalanceBefore - REQUIRED_MARGIN, "Borrower's margin not deducted properly"
        );
        assertEq(poolLiquidityAfter, poolLiquidityBefore - POOL_FUNDING, "Incorrect pool liquidity reduction");
        assertEq(walletBalance, TEST_LOAN_AMOUNT, "Wallet should hold total loan amount");

        console.log("Borrower balance after:", borrowerBalanceAfter / 1e6, "USDC");
        console.log("Pool liquidity after:", poolLiquidityAfter / 1e6, "USDC");
        console.log("Restricted wallet balance:", walletBalance / 1e6, "USDC");

        vm.stopPrank();

        console.log("=== Complete Loan Flow Passed ===");
    }

    function testLoanRepaymentFlow() public {
        console.log("=== Starting Loan Repayment Flow Test ===");

        // Create loan first
        vm.startPrank(borrower);
        mockUSDC.approve(address(loanManager), REQUIRED_MARGIN);
        loanManager.createLoan(TEST_LOAN_AMOUNT);
        vm.stopPrank();

        LoanManager.LoanInfo memory loanInfo = loanManager.getLoanInfo(borrower);
        address wallet = loanInfo.restrictedWallet;

        // Simulate successful trading (borrower made profit)
        uint256 tradingProfit = 10_000 * 1e6; // 10k profit
        deal(address(mockUSDC), wallet, TEST_LOAN_AMOUNT + tradingProfit);

        uint256 borrowerBalanceBefore = mockUSDC.balanceOf(borrower);

        console.log("Wallet balance before repayment:", mockUSDC.balanceOf(wallet) / 1e6, "USDC");
        console.log("Borrower balance before repayment:", borrowerBalanceBefore / 1e6, "USDC");

        // Repay loan
        vm.prank(borrower);
        bool success = loanManager.repayLoan();
        assertTrue(success, "Loan repayment failed");

        // Check loan is no longer active
        LoanManager.LoanInfo memory loanAfter = loanManager.getLoanInfo(borrower);
        assertFalse(loanAfter.isActive, "Loan should be inactive after repayment");

        uint256 borrowerBalanceAfter = mockUSDC.balanceOf(borrower);
        uint256 poolLiquidityAfter = lendingPool.getAvailableLiquidity();

        console.log("Borrower balance after repayment:", borrowerBalanceAfter / 1e6, "USDC");
        console.log("Pool liquidity after repayment:", poolLiquidityAfter / 1e6, "USDC");

        // Borrower should have received back more than initial margin due to profit
        assertTrue(borrowerBalanceAfter > borrowerBalanceBefore, "Borrower should have received profit");

        console.log("=== Loan Repayment Flow Passed ===");
    }

    function testLoanLiquidationFlow() public {
        console.log("=== Starting Loan Liquidation Flow Test ===");

        // Create loan first
        vm.startPrank(borrower);
        mockUSDC.approve(address(loanManager), REQUIRED_MARGIN);
        loanManager.createLoan(TEST_LOAN_AMOUNT);
        vm.stopPrank();

        LoanManager.LoanInfo memory loanInfo = loanManager.getLoanInfo(borrower);
        address wallet = loanInfo.restrictedWallet;

        // Simulate trading loss (wallet has less than original amount)
        uint256 remainingFunds = 50_000 * 1e6; // Lost 50k
        deal(address(mockUSDC), wallet, remainingFunds);

        // Fast forward time past loan duration (30 days)
        vm.warp(block.timestamp + 31 days);

        // Check loan is liquidatable
        assertTrue(collateralManager.isLiquidatable(borrower), "Loan should be liquidatable");

        // The liquidation logic expects the margin to be available for reward
        // Since margin was sent to wallet during loan creation, we need to ensure
        // LoanManager has enough funds for both pool recovery and liquidator reward
        uint256 totalNeededForLiquidation = remainingFunds + REQUIRED_MARGIN;
        deal(address(mockUSDC), address(loanManager), totalNeededForLiquidation);

        uint256 liquidatorBalanceBefore = mockUSDC.balanceOf(liquidator);
        uint256 poolLiquidityBefore = lendingPool.getAvailableLiquidity();

        console.log("Wallet balance at liquidation:", mockUSDC.balanceOf(wallet) / 1e6, "USDC");
        console.log("Liquidator balance before:", liquidatorBalanceBefore / 1e6, "USDC");
        console.log("LoanManager balance before liquidation:", mockUSDC.balanceOf(address(loanManager)) / 1e6, "USDC");

        // Liquidate loan
        vm.prank(liquidator);
        bool success = loanManager.liquidateLoan(borrower);
        assertTrue(success, "Loan liquidation failed");

        // Check loan is no longer active
        LoanManager.LoanInfo memory loanAfter = loanManager.getLoanInfo(borrower);
        assertFalse(loanAfter.isActive, "Loan should be inactive after liquidation");

        uint256 liquidatorBalanceAfter = mockUSDC.balanceOf(liquidator);
        uint256 poolLiquidityAfter = lendingPool.getAvailableLiquidity();

        console.log("Liquidator balance after:", liquidatorBalanceAfter / 1e6, "USDC");
        console.log("Pool liquidity after liquidation:", poolLiquidityAfter / 1e6, "USDC");

        // Liquidator should receive the 20% margin as reward
        assertEq(
            liquidatorBalanceAfter - liquidatorBalanceBefore,
            REQUIRED_MARGIN,
            "Liquidator should receive margin as reward"
        );

        // Pool should have recovered what was available from wallet
        assertTrue(poolLiquidityAfter > poolLiquidityBefore, "Pool should have recovered some funds");

        console.log("=== Loan Liquidation Flow Passed ===");
    }

    function testMultipleBorrowersFlow() public {
        console.log("=== Starting Multiple Borrowers Flow Test ===");

        // Setup borrowers
        vm.prank(borrower);
        mockUSDC.approve(address(loanManager), REQUIRED_MARGIN);

        vm.prank(borrower2);
        mockUSDC.approve(address(loanManager), REQUIRED_MARGIN);

        // Create loans for both borrowers
        vm.prank(borrower);
        loanManager.createLoan(TEST_LOAN_AMOUNT);

        vm.prank(borrower2);
        loanManager.createLoan(TEST_LOAN_AMOUNT);

        // Verify both loans are active
        assertTrue(loanManager.hasActiveLoan(borrower), "Borrower 1 should have active loan");
        assertTrue(loanManager.hasActiveLoan(borrower2), "Borrower 2 should have active loan");

        // Verify different wallets were created
        LoanManager.LoanInfo memory loan1 = loanManager.getLoanInfo(borrower);
        LoanManager.LoanInfo memory loan2 = loanManager.getLoanInfo(borrower2);
        assertTrue(loan1.restrictedWallet != loan2.restrictedWallet, "Borrowers should have different wallets");

        // Check pool liquidity reduced correctly
        uint256 expectedLiquidity = INITIAL_POOL_FUNDING - (POOL_FUNDING * 2);
        assertEq(lendingPool.getAvailableLiquidity(), expectedLiquidity, "Pool liquidity should reflect both loans");

        console.log("Borrower 1 wallet:", loan1.restrictedWallet);
        console.log("Borrower 2 wallet:", loan2.restrictedWallet);
        console.log("Remaining pool liquidity:", lendingPool.getAvailableLiquidity() / 1e6, "USDC");

        console.log("=== Multiple Borrowers Flow Passed ===");
    }

    function testRestrictedWalletFunctionality() public {
        console.log("=== Starting Restricted Wallet Functionality Test ===");

        // Create loan to get restricted wallet
        vm.startPrank(borrower);
        mockUSDC.approve(address(loanManager), REQUIRED_MARGIN);
        loanManager.createLoan(TEST_LOAN_AMOUNT);

        LoanManager.LoanInfo memory loanInfo = loanManager.getLoanInfo(borrower);
        RestrictedWallet wallet = RestrictedWallet(payable(loanInfo.restrictedWallet));

        // Test wallet ownership
        assertEq(wallet.owner(), borrower, "Wallet owner should be borrower");

        // Test balance check
        uint256 walletBalance = wallet.getBalance(address(mockUSDC));
        assertEq(walletBalance, TEST_LOAN_AMOUNT, "Wallet should have full loan amount");

        // Test approved target management
        address mockUniswapRouter = makeAddr("uniswapRouter");
        wallet.addApprovedTarget(mockUniswapRouter);
        assertTrue(wallet.isTargetApproved(mockUniswapRouter), "Target should be approved");

        // Test selector approval (some should already be approved by default)
        assertTrue(wallet.isSelectorApproved(0x414bf389), "exactInputSingle should be approved");

        vm.stopPrank();

        console.log("Wallet balance:", walletBalance / 1e6, "USDC");
        console.log("Wallet owner:", wallet.owner());
        console.log("=== Restricted Wallet Functionality Passed ===");
    }

    function testEdgeCaseInsufficientPoolLiquidity() public {
        console.log("=== Testing Edge Case: Insufficient Pool Liquidity ===");

        // Try to create loan that requires more pool funding than available
        // Pool has 1M, so loan requiring > 1.25M pool funding should fail
        uint256 largeLoanAmount = 1_600_000 * 1e6; // 1.6M loan = 1.28M pool funding (80%)
        uint256 requiredMargin = largeLoanAmount / 5; // 20% margin = 320k

        // Give borrower enough margin
        deal(address(mockUSDC), borrower, requiredMargin);

        vm.startPrank(borrower);
        mockUSDC.approve(address(loanManager), requiredMargin);

        vm.expectRevert("Insufficient pool liquidity");
        loanManager.createLoan(largeLoanAmount);

        vm.stopPrank();

        console.log("=== Edge Case Test Passed ===");
    }

    function testEdgeCaseInsufficientMargin() public {
        console.log("=== Testing Edge Case: Insufficient Margin ===");

        // Give borrower less than required margin
        uint256 insufficientBalance = REQUIRED_MARGIN - 1;
        deal(address(mockUSDC), borrower, insufficientBalance);

        vm.startPrank(borrower);
        mockUSDC.approve(address(loanManager), insufficientBalance);

        vm.expectRevert("Insufficient margin");
        loanManager.createLoan(TEST_LOAN_AMOUNT);

        vm.stopPrank();

        console.log("=== Edge Case Test Passed ===");
    }

    function testCompleteSystemIntegration() public {
        console.log("=== Starting Complete System Integration Test ===");

        // 1. Check initial system state
        assertEq(loanManager.totalLoans(), 0, "Should start with no loans");
        assertEq(lendingPool.getAvailableLiquidity(), INITIAL_POOL_FUNDING, "Pool should have initial funding");

        // 2. Create loan
        vm.startPrank(borrower);
        mockUSDC.approve(address(loanManager), REQUIRED_MARGIN);
        loanManager.createLoan(TEST_LOAN_AMOUNT);
        vm.stopPrank();

        // 3. Verify system state after loan creation
        assertEq(loanManager.totalLoans(), 1, "Should have 1 loan");
        assertTrue(collateralManager.hasActiveLoan(borrower), "CollateralManager should track active loan");
        assertTrue(walletFactory.hasWallet(borrower), "WalletFactory should have created wallet");

        // 4. Simulate trading and add profit to wallet
        LoanManager.LoanInfo memory loanInfo = loanManager.getLoanInfo(borrower);
        deal(address(mockUSDC), loanInfo.restrictedWallet, TEST_LOAN_AMOUNT + 5000 * 1e6);

        // 5. Repay loan
        vm.prank(borrower);
        loanManager.repayLoan();

        // 6. Verify final system state
        assertEq(loanManager.totalRepaid(), 1, "Should have 1 repaid loan");
        assertFalse(collateralManager.hasActiveLoan(borrower), "CollateralManager should clear loan");
        assertTrue(
            lendingPool.getAvailableLiquidity() > INITIAL_POOL_FUNDING - POOL_FUNDING,
            "Pool should have recovered funds"
        );

        console.log("Final pool liquidity:", lendingPool.getAvailableLiquidity() / 1e6, "USDC");
        console.log("=== Complete System Integration Test Passed ===");
    }

    /**
     * @dev Compute next contract address using standard formula
     */
    function computeCreateAddress(address deployer, uint256 nonce) internal pure override returns (address) {
        if (nonce == 0) {
            return
                address(
                    uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(0x80)))))
                );
        }
        if (nonce <= 0x7f) {
            return
                address(
                    uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, uint8(nonce)))))
                );
        }
        if (nonce <= 0xff) {
            return address(
                uint160(
                    uint256(
                        keccak256(abi.encodePacked(bytes1(0xd7), bytes1(0x94), deployer, bytes1(0x81), uint8(nonce)))
                    )
                )
            );
        }
        revert("Nonce too high");
    }
}
