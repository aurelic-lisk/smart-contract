// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title CollateralManager
 * @notice Virtual margin tracker for Aurelic PoC prefunding model
 * - Tracks 20% user margin (virtual, not real custody)
 * - Only LoanManager can create, clear, or liquidate loan records
 */
contract CollateralManager is ReentrancyGuard {
    // ----------- Constants -----------
    uint256 public constant MARGIN_BPS = 2000; // 20% in basis points
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant LOAN_DURATION = 30 days;

    // ----------- State -----------
    address public loanManager;

    struct LoanRecord {
        uint256 marginAmount; // 20% user margin
        uint256 loanAmount; // Total loan amount
        uint32 startTime; // Loan start timestamp
        bool isActive; // Loan status
    }

    mapping(address => LoanRecord) public loanRecords;

    // ----------- Events -----------
    event LoanRecordCreated(address indexed borrower, uint256 margin, uint256 loan);
    event LoanRepaid(address indexed borrower);
    event LoanLiquidated(address indexed borrower);

    /**
     * @notice Constructor
     * @param _loanManager Address of the LoanManager contract
     */
    constructor(address _loanManager) {
        loanManager = _loanManager;
    }

    /**
     * @notice Update the LoanManager address
     */
    function setLoanManager(address _loanManager) external {
        require(loanManager == address(0x1) || msg.sender == loanManager, "Not authorized");
        require(_loanManager != address(0), "Invalid loan manager");
        loanManager = _loanManager;
    }

    // ----------- Modifiers -----------
    modifier onlyLoanManager() {
        require(msg.sender == loanManager, "Only loan manager");
        _;
    }

    // ----------- Core Functions -----------

    /**
     * @notice Create a new loan record for a borrower
     * @param borrower Address of the borrower
     * @param marginAmount Margin contributed by borrower (20%)
     * @param loanAmount Total loan amount
     */
    function createLoanRecord(address borrower, uint256 marginAmount, uint256 loanAmount) external onlyLoanManager {
        require(borrower != address(0), "Invalid borrower");
        require(!loanRecords[borrower].isActive, "Active loan exists");
        require(validateMargin(marginAmount, loanAmount), "Invalid margin ratio");
        loanRecords[borrower] = LoanRecord({
            marginAmount: marginAmount, loanAmount: loanAmount, startTime: uint32(block.timestamp), isActive: true
        });
        emit LoanRecordCreated(borrower, marginAmount, loanAmount);
    }

    /**
     * @notice Validate margin ratio (must be at least 20% of loan)
     * @param marginAmount Margin amount
     * @param loanAmount Total loan amount
     * @return isValid True if margin is valid
     */
    function validateMargin(uint256 marginAmount, uint256 loanAmount) public pure returns (bool isValid) {
        if (loanAmount == 0) return false;
        uint256 requiredMargin = (loanAmount * MARGIN_BPS) / BASIS_POINTS;
        return marginAmount >= requiredMargin;
    }

    /**
     * @notice Mark a loan as repaid (clear record)
     * @param borrower Address of the borrower
     */
    function repayLoan(address borrower) external onlyLoanManager {
        require(loanRecords[borrower].isActive, "No active loan");
        loanRecords[borrower].isActive = false;
        emit LoanRepaid(borrower);
    }

    /**
     * @notice Mark a loan as liquidated (clear record)
     * @param borrower Address of the borrower
     */
    function liquidateLoan(address borrower) external onlyLoanManager {
        require(loanRecords[borrower].isActive, "No active loan");
        loanRecords[borrower].isActive = false;
        emit LoanLiquidated(borrower);
    }

    // ----------- View Functions -----------

    /**
     * @notice Check if a borrower's loan is liquidatable (30+ days overdue)
     * @param borrower Address of the borrower
     * @return liquidatable True if loan can be liquidated
     */
    function isLiquidatable(address borrower) external view returns (bool liquidatable) {
        LoanRecord storage record = loanRecords[borrower];
        if (!record.isActive) return false;
        return (block.timestamp - record.startTime) >= LOAN_DURATION;
    }

    /**
     * @notice Check if a borrower's loan is due (30+ days)
     * @param borrower Address of the borrower
     * @return isDue True if loan is due
     */
    function isLoanDue(address borrower) external view returns (bool isDue) {
        LoanRecord storage record = loanRecords[borrower];
        if (!record.isActive) return false;
        return (block.timestamp - record.startTime) >= LOAN_DURATION;
    }

    /**
     * @notice Get the loan record for a borrower
     * @param borrower Address of the borrower
     * @return record Loan record struct
     */
    function getLoanRecord(address borrower) external view returns (LoanRecord memory record) {
        return loanRecords[borrower];
    }

    /**
     * @notice Check if a borrower has an active loan
     * @param borrower Address of the borrower
     * @return hasActive True if borrower has active loan
     */
    function hasActiveLoan(address borrower) external view returns (bool hasActive) {
        return loanRecords[borrower].isActive;
    }
}
