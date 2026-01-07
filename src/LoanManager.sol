// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./LendingPool.sol";
import "./CollateralManager.sol";
import "./RestrictedWalletFactory.sol";
import "./RestrictedWallet.sol";

/**
 * @title LoanManager
 * @notice Core orchestrator for Aurelic PoC (20% margin, 80% pool funding)
 * - Handles loan creation, repayment, and liquidation
 * - All code and documentation in English
 */
contract LoanManager is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ----------- Structs -----------
    struct LoanInfo {
        uint256 loanAmount; // Total loan amount (100%)
        uint256 marginAmount; // User margin (20%)
        uint256 poolFunding; // Pool funding (80%)
        uint32 startTime; // Loan start timestamp
        address restrictedWallet; // User's trading wallet
        bool isActive; // Loan status
    }

    // ----------- State -----------
    LendingPool public immutable lendingPool;
    CollateralManager public immutable collateralManager;
    RestrictedWalletFactory public immutable walletFactory;
    IERC20 public immutable usdcToken;

    mapping(address => LoanInfo) public borrowerLoans;
    uint256 public totalLoans;
    uint256 public totalRepaid;

    // ----------- Events -----------
    event LoanCreated(
        address indexed borrower,
        uint256 loanAmount,
        uint256 marginAmount,
        uint256 poolFunding,
        address indexed restrictedWallet
    );
    event LoanRepaid(address indexed borrower, uint256 returnedAmount);
    event LoanLiquidated(address indexed borrower, address indexed liquidator, uint256 recoveredAmount);

    /**
     * @notice Constructor
     * @param _lendingPool LendingPool address
     * @param _collateralManager CollateralManager address
     * @param _walletFactory RestrictedWalletFactory address
     * @param _usdcToken USDC token address
     */
    constructor(address _lendingPool, address _collateralManager, address _walletFactory, address _usdcToken) {
        require(_lendingPool != address(0), "Invalid lending pool");
        require(_collateralManager != address(0), "Invalid collateral manager");
        require(_walletFactory != address(0), "Invalid wallet factory");
        require(_usdcToken != address(0), "Invalid USDC token");
        lendingPool = LendingPool(_lendingPool);
        collateralManager = CollateralManager(_collateralManager);
        walletFactory = RestrictedWalletFactory(_walletFactory);
        usdcToken = IERC20(_usdcToken);
    }

    // ----------- Core Functions -----------

    /**
     * @notice Create a new loan (20% margin, 80% pool funding)
     * @param loanAmount Total loan amount (100%)
     * @return success True if loan created
     */
    function createLoan(uint256 loanAmount) external nonReentrant returns (bool success) {
        require(loanAmount > 0, "Loan amount must be greater than 0");
        require(!borrowerLoans[msg.sender].isActive, "Active loan exists");
        uint256 marginAmount = (loanAmount * 20) / 100; // 20% margin
        uint256 poolFunding = loanAmount - marginAmount; // 80% pool
        require(usdcToken.balanceOf(msg.sender) >= marginAmount, "Insufficient margin");
        require(lendingPool.canFundLoan(poolFunding), "Insufficient pool liquidity");
        address restrictedWallet = walletFactory.getOrCreateWallet(msg.sender);
        usdcToken.safeTransferFrom(msg.sender, address(this), marginAmount);
        collateralManager.createLoanRecord(msg.sender, marginAmount, loanAmount);
        lendingPool.allocateFunds(restrictedWallet, poolFunding);
        usdcToken.safeTransfer(restrictedWallet, marginAmount);
        borrowerLoans[msg.sender] = LoanInfo({
            loanAmount: loanAmount,
            marginAmount: marginAmount,
            poolFunding: poolFunding,
            startTime: uint32(block.timestamp),
            restrictedWallet: restrictedWallet,
            isActive: true
        });
        totalLoans++;
        emit LoanCreated(msg.sender, loanAmount, marginAmount, poolFunding, restrictedWallet);
        return true;
    }

    /**
     * @notice Repay loan (with dummy 8% annual interest)
     * @return success True if repaid
     */
    function repayLoan() external nonReentrant returns (bool success) {
        require(borrowerLoans[msg.sender].isActive, "No active loan");
        LoanInfo storage loan = borrowerLoans[msg.sender];
        uint256 balanceBefore = usdcToken.balanceOf(address(this));
        // Withdraw USDC from wallet to this contract
        RestrictedWallet(payable(loan.restrictedWallet))
            .withdrawTokens(address(usdcToken), IERC20(usdcToken).balanceOf(loan.restrictedWallet));
        uint256 balanceAfter = usdcToken.balanceOf(address(this));
        uint256 returnedAmount = balanceAfter - balanceBefore;
        uint256 daysElapsed = (block.timestamp - loan.startTime) / 1 days;
        uint256 interest = (loan.loanAmount * 8 * daysElapsed) / (100 * 365); // 8% annual
        uint256 totalRepayment = loan.loanAmount + interest;
        uint256 poolRecovery;
        uint256 userProfit;
        if (returnedAmount >= totalRepayment) {
            poolRecovery = loan.poolFunding + ((interest * 80) / 100); // Pool gets 80% of interest
            userProfit = returnedAmount - totalRepayment + loan.marginAmount;
        } else {
            poolRecovery = (returnedAmount * 80) / 100;
            userProfit = loan.marginAmount > (totalRepayment - returnedAmount)
                ? loan.marginAmount - (totalRepayment - returnedAmount)
                : 0;
        }
        if (poolRecovery > 0) {
            usdcToken.safeTransfer(address(lendingPool), poolRecovery);
            lendingPool.repayFunds(msg.sender, poolRecovery);
        }
        if (userProfit > 0) {
            usdcToken.safeTransfer(msg.sender, userProfit);
        }
        collateralManager.repayLoan(msg.sender);
        loan.isActive = false;
        totalRepaid++;
        emit LoanRepaid(msg.sender, returnedAmount);
        return true;
    }

    /**
     * @notice Liquidate an overdue loan (after 30 days)
     * @param borrower Address to liquidate
     * @return success True if liquidated
     */
    function liquidateLoan(address borrower) external nonReentrant returns (bool success) {
        require(borrowerLoans[borrower].isActive, "No active loan");
        require(collateralManager.isLiquidatable(borrower), "Not liquidatable");
        LoanInfo storage loan = borrowerLoans[borrower];
        // Withdraw USDC from wallet to this contract
        RestrictedWallet(payable(loan.restrictedWallet))
            .withdrawTokens(address(usdcToken), IERC20(usdcToken).balanceOf(loan.restrictedWallet));
        uint256 recoveredAmount = usdcToken.balanceOf(address(this));
        uint256 poolRecovery = recoveredAmount > loan.poolFunding ? loan.poolFunding : recoveredAmount;
        if (poolRecovery > 0) {
            usdcToken.safeTransfer(address(lendingPool), poolRecovery);
            lendingPool.repayFunds(borrower, poolRecovery);
        }
        uint256 liquidatorReward = loan.marginAmount;
        if (liquidatorReward > 0) {
            usdcToken.safeTransfer(msg.sender, liquidatorReward);
        }
        collateralManager.liquidateLoan(borrower);
        loan.isActive = false;
        emit LoanLiquidated(borrower, msg.sender, recoveredAmount);
        return true;
    }

    // ----------- View Functions -----------

    /**
     * @notice Get loan info for a borrower
     * @param borrower Address
     * @return loan LoanInfo struct
     */
    function getLoanInfo(address borrower) external view returns (LoanInfo memory loan) {
        return borrowerLoans[borrower];
    }

    /**
     * @notice Check if a borrower has an active loan
     * @param borrower Address
     * @return hasActive True if active
     */
    function hasActiveLoan(address borrower) external view returns (bool hasActive) {
        return borrowerLoans[borrower].isActive;
    }

    /**
     * @notice Get required margin for a loan amount (20%)
     * @param loanAmount Total loan amount
     * @return margin Required margin
     */
    function getRequiredMargin(uint256 loanAmount) external pure returns (uint256 margin) {
        return (loanAmount * 20) / 100;
    }

    /**
     * @notice Get pool funding for a loan amount (80%)
     * @param loanAmount Total loan amount
     * @return funding Pool funding
     */
    function getPoolFunding(uint256 loanAmount) external pure returns (uint256 funding) {
        return (loanAmount * 80) / 100;
    }

    /**
     * @notice Get loan statistics
     * @return totalLoansCreated Total created
     * @return totalLoansRepaid Total repaid
     * @return activeLoans Active count
     */
    function getLoanStats()
        external
        view
        returns (uint256 totalLoansCreated, uint256 totalLoansRepaid, uint256 activeLoans)
    {
        return (totalLoans, totalRepaid, totalLoans - totalRepaid);
    }

    /**
     * @notice Check if a user can create a loan
     * @param borrower Address
     * @param loanAmount Desired loan amount
     * @return canCreate True if possible
     */
    function canCreateLoan(address borrower, uint256 loanAmount) external view returns (bool canCreate) {
        if (loanAmount == 0) return false;
        if (borrowerLoans[borrower].isActive) return false;
        uint256 poolFunding = (loanAmount * 80) / 100;
        return lendingPool.canFundLoan(poolFunding);
    }
}
