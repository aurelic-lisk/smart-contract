// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title LendingPool
 * @notice ERC4626-compliant USDC lending pool for Aurelic PoC
 * - Investors deposit USDC to earn a fixed 6% APY (dummy yield)
 * - Pool provides 80% funding for loans (only callable by LoanManager)
 * - Share-based ownership with automatic yield accrual
 * - No real yield, only conceptual accrual for PoC
 */
contract LendingPool is ERC4626, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Address of the LoanManager contract (authorized to allocate/repay funds)
    address public loanManager;

    /// @notice Total USDC currently allocated to loans
    uint256 public totalAllocated;

    /// @notice Last timestamp when yield was accrued
    uint256 public lastAccrualTime;

    /// @notice Total accrued yield since pool creation
    uint256 public totalAccruedYield;

    /// @notice Base balance for yield calculation (excludes recent repayments)
    uint256 public yieldBaseBalance;

    /// @notice Fixed APY (6% = 600 basis points)
    uint256 public constant FIXED_APY = 600; // 6%

    /// @notice Basis points denominator
    uint256 public constant BASIS_POINTS = 10000;

    /// @notice Seconds per year for APY calculation
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    // ----------- Events -----------
    event FundsAllocated(address indexed recipient, uint256 amount);
    event FundsRepaid(address indexed borrower, uint256 amount);
    event YieldAccrued(uint256 yieldAmount, uint256 timestamp);

    /**
     * @notice Constructor
     * @param _usdcToken Address of the USDC token
     * @param _loanManager Address of the LoanManager contract
     */
    constructor(address _usdcToken, address _loanManager)
        ERC4626(IERC20(_usdcToken))
        ERC20("Aurelic Pool Shares", "IPS")
    {
        require(_usdcToken != address(0), "Invalid USDC token address");
        require(_loanManager != address(0), "Invalid loan manager address");
        loanManager = _loanManager;
        lastAccrualTime = block.timestamp;
        yieldBaseBalance = 0;
    }

    // ----------- ERC4626 Overrides -----------

    /**
     * @notice Returns the total assets in the pool, including accrued yield
     */
    function totalAssets() public view override returns (uint256) {
        uint256 currentBalance = IERC20(asset()).balanceOf(address(this));
        uint256 pendingYield = _calculatePendingYield();
        return currentBalance + pendingYield + totalAccruedYield;
    }

    /**
     * @notice Preview deposit, including pending yield
     */
    function previewDeposit(uint256 assets) public view override returns (uint256 shares) {
        uint256 totalAssetsWithYield = totalAssets();
        uint256 supply = totalSupply();
        if (supply == 0) return assets;
        return (assets * supply) / totalAssetsWithYield;
    }

    /**
     * @notice Preview withdraw, including pending yield
     */
    function previewWithdraw(uint256 assets) public view override returns (uint256 shares) {
        uint256 totalAssetsWithYield = totalAssets();
        uint256 supply = totalSupply();
        if (supply == 0) return assets;
        return (assets * supply + totalAssetsWithYield - 1) / totalAssetsWithYield; // round up
    }

    /**
     * @notice Preview redeem, including pending yield
     */
    function previewRedeem(uint256 shares) public view override returns (uint256 assets) {
        uint256 totalAssetsWithYield = totalAssets();
        uint256 supply = totalSupply();
        if (supply == 0) return shares;
        return (shares * totalAssetsWithYield) / supply;
    }

    /**
     * @notice Deposit USDC and mint pool shares
     */
    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256 shares) {
        require(assets > 0, "Amount must be greater than 0");
        _accrueYield();
        SafeERC20.safeTransferFrom(IERC20(asset()), msg.sender, address(this), assets);
        shares = previewDeposit(assets);
        yieldBaseBalance += assets;
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }

    /**
     * @notice Withdraw USDC by burning pool shares
     */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        nonReentrant
        returns (uint256 shares)
    {
        require(assets > 0, "Amount must be greater than 0");
        require(assets <= getAvailableLiquidity(), "Insufficient pool liquidity");
        _accrueYield();
        shares = previewWithdraw(assets);
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
        if (assets <= yieldBaseBalance) {
            yieldBaseBalance -= assets;
        } else {
            yieldBaseBalance = 0;
        }
        _burn(owner, shares);
        SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return shares;
    }

    /**
     * @notice Redeem pool shares for USDC
     */
    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        nonReentrant
        returns (uint256 assets)
    {
        require(shares > 0, "Shares must be greater than 0");
        _accrueYield();
        assets = previewRedeem(shares);
        uint256 availableBalance = IERC20(asset()).balanceOf(address(this));
        require(availableBalance > 0, "No liquidity available");
        if (assets > availableBalance) {
            assets = availableBalance;
        }
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
        uint256 deducted = assets > yieldBaseBalance ? yieldBaseBalance : assets;
        yieldBaseBalance -= deducted;
        _burn(owner, shares);
        SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return assets;
    }

    // ----------- LoanManager Functions -----------

    /**
     * @notice Allocate funds for a loan (only callable by LoanManager)
     * @param recipient Address to receive funds (RestrictedWallet)
     * @param amount Amount to allocate (80% of total loan)
     */
    function allocateFunds(address recipient, uint256 amount) external {
        require(msg.sender == loanManager, "Only loan manager");
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= getAvailableLiquidity(), "Insufficient pool liquidity");
        totalAllocated += amount;
        SafeERC20.safeTransfer(IERC20(asset()), recipient, amount);
        emit FundsAllocated(recipient, amount);
    }

    /**
     * @notice Repay funds from a loan (only callable by LoanManager)
     * @param borrower Address of the borrower
     * @param amount Amount being repaid
     */
    function repayFunds(address borrower, uint256 amount) external {
        require(msg.sender == loanManager, "Only loan manager");
        require(amount > 0, "Amount must be greater than 0");
        _accrueYield();
        if (amount >= totalAllocated) {
            totalAllocated = 0;
        } else {
            totalAllocated -= amount;
        }
        yieldBaseBalance += amount;
        emit FundsRepaid(borrower, amount);
    }

    // ----------- Yield Accrual -----------

    /**
     * @notice Accrue yield based on time elapsed (internal)
     */
    function _accrueYield() internal {
        uint256 pendingYield = _calculatePendingYield();
        if (pendingYield > 0) {
            totalAccruedYield += pendingYield;
            yieldBaseBalance += pendingYield;
            lastAccrualTime = block.timestamp;
            emit YieldAccrued(pendingYield, block.timestamp);
        }
    }

    /**
     * @notice Calculate pending yield based on time elapsed (internal)
     */
    function _calculatePendingYield() internal view returns (uint256 pendingYield) {
        if (totalSupply() == 0) return 0;
        uint256 timeElapsed = block.timestamp - lastAccrualTime;
        if (timeElapsed == 0) return 0;
        uint256 yieldEligibleBalance = yieldBaseBalance;
        pendingYield = (yieldEligibleBalance * FIXED_APY * timeElapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);
        return pendingYield;
    }

    /**
     * @notice Public function to accrue yield (anyone can call)
     */
    function accrueYield() external {
        _accrueYield();
    }

    // ----------- View Functions -----------

    /**
     * @notice Get available liquidity for loans
     */
    function getAvailableLiquidity() public view returns (uint256 available) {
        uint256 balance = IERC20(asset()).balanceOf(address(this));
        uint256 pendingYield = _calculatePendingYield();
        return balance + pendingYield;
    }

    /**
     * @notice Get pool statistics
     */
    function getPoolStats()
        external
        view
        returns (
            uint256 totalAssetsAmount,
            uint256 totalAllocatedAmount,
            uint256 availableLiquidity,
            uint256 totalShares,
            uint256 currentAPY
        )
    {
        return (totalAssets(), totalAllocated, getAvailableLiquidity(), totalSupply(), FIXED_APY);
    }

    /**
     * @notice Get user information
     */
    function getUserInfo(address user) external view returns (uint256 shares, uint256 assets) {
        shares = balanceOf(user);
        assets = convertToAssets(shares);
    }

    /**
     * @notice Check if pool can fund a loan of given amount
     */
    function canFundLoan(uint256 amount) external view returns (bool sufficient) {
        return amount <= getAvailableLiquidity();
    }

    /**
     * @notice Get pending yield that would be accrued
     */
    function getPendingYield() external view returns (uint256 pendingYield) {
        return _calculatePendingYield();
    }

    /**
     * @notice Get yield base balance (for debugging)
     */
    function getYieldBaseBalance() external view returns (uint256 yieldBase) {
        return yieldBaseBalance;
    }

    // ----------- Admin Functions -----------

    /**
     * @notice Update the LoanManager address (emergency only)
     */
    function setLoanManager(address newLoanManager) external {
        require(msg.sender == loanManager || loanManager == address(0x1), "Only current loan manager");
        require(newLoanManager != address(0), "Invalid address");
        loanManager = newLoanManager;
    }
}
