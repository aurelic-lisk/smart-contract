// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IRouter} from "./interfaces/velodrome/IRouter.sol";
import {IPoolFactory} from "./interfaces/velodrome/IPoolFactory.sol";

/**
 * @title ILoanManager
 * @notice Minimal interface for solvency checks
 */
interface ILoanManager {
    function hasActiveLoan(address borrower) external view returns (bool);
    function getMinimumUSDCRequired(
        address borrower
    ) external view returns (uint256);
}

/**
 * @title RestrictedWallet - Velodrome V2 Integration
 * @notice Secure trading wallet with Velodrome AMM for Aurelic Protocol
 * @dev Single-hop swaps only, volatile pools only, with solvency-aware withdrawals
 *
 * Withdrawal Rules:
 * - LoanManager can always withdraw (for repayment/liquidation)
 * - Owner can withdraw any non-USDC token freely
 * - Owner can withdraw USDC only if remaining balance >= loan repayment amount
 * - Owner can withdraw all USDC if no active loan
 */
contract RestrictedWallet is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ CONSTANTS ============

    /// @notice Maximum deadline extension (15 minutes)
    uint256 public constant MAX_DEADLINE_EXTENSION = 15 minutes;

    // ============ IMMUTABLES ============

    /// @notice Velodrome Router for swaps
    IRouter public immutable veloRouter;

    /// @notice Velodrome PoolFactory
    IPoolFactory public immutable poolFactory;

    /// @notice LoanManager address (authorized for withdrawals)
    address public immutable loanManager;

    /// @notice USDC token address (for solvency checks)
    address public immutable usdcToken;

    // ============ STATE VARIABLES ============

    /// @notice Whitelisted tokens mapping
    mapping(address => bool) public whitelistedTokens;

    // ============ EVENTS ============

    event SwapExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 timestamp
    );

    event TokensWithdrawn(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    // ============ ERRORS ============

    error InvalidAddress();
    error InvalidAmount();
    error TransactionExpired();
    error DeadlineTooLate();
    error TokenNotWhitelisted();
    error Unauthorized();
    error PoolDoesNotExist();
    error InsufficientOutput();
    error InsufficientUSDCForLoan();

    // ============ CONSTRUCTOR ============

    /**
     * @notice Initialize RestrictedWallet with Velodrome integration
     * @param _initialOwner Wallet owner (borrower)
     * @param _veloRouter Velodrome Router address
     * @param _poolFactory Velodrome PoolFactory address
     * @param _loanManager LoanManager address
     * @param _whitelistedTokens Initial token whitelist
     */
    constructor(
        address _initialOwner,
        address _veloRouter,
        address _poolFactory,
        address _loanManager,
        address[] memory _whitelistedTokens
    ) Ownable(_initialOwner) {
        if (_veloRouter == address(0)) revert InvalidAddress();
        if (_poolFactory == address(0)) revert InvalidAddress();
        if (_loanManager == address(0)) revert InvalidAddress();
        if (_whitelistedTokens.length == 0) revert InvalidAddress();

        veloRouter = IRouter(_veloRouter);
        poolFactory = IPoolFactory(_poolFactory);
        loanManager = _loanManager;

        // First whitelisted token is assumed to be USDC (for solvency checks)
        usdcToken = _whitelistedTokens[0];

        // Whitelist tokens in constructor
        for (uint256 i = 0; i < _whitelistedTokens.length; i++) {
            whitelistedTokens[_whitelistedTokens[i]] = true;
        }
    }

    // ============ SWAP FUNCTIONS ============

    /**
     * @notice Execute single-hop swap (exact input)
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Input amount
     * @param amountOutMinimum Minimum output (slippage protection)
     * @param deadline Transaction deadline
     * @return amountOut Actual output amount
     */
    function swapExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 deadline
    ) external onlyOwner nonReentrant returns (uint256 amountOut) {
        // Validate deadline with max extension
        if (block.timestamp > deadline) revert TransactionExpired();
        if (deadline > block.timestamp + MAX_DEADLINE_EXTENSION) {
            revert DeadlineTooLate();
        }

        if (amountIn == 0) revert InvalidAmount();
        if (!whitelistedTokens[tokenIn]) revert TokenNotWhitelisted();
        if (!whitelistedTokens[tokenOut]) revert TokenNotWhitelisted();

        // Check pool exists
        address pool = poolFactory.getPool(tokenIn, tokenOut, false);
        if (pool == address(0)) revert PoolDoesNotExist();

        // Check balance and create token contract reference
        IERC20 tokenInContract = IERC20(tokenIn);
        if (tokenInContract.balanceOf(address(this)) < amountIn) {
            revert InvalidAmount();
        }

        // Use forceApprove
        tokenInContract.forceApprove(address(veloRouter), amountIn);

        // Build route (single-hop, volatile only)
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({
            from: tokenIn,
            to: tokenOut,
            stable: false, // Volatile only for demo
            factory: address(0) // Use defaultFactory
        });

        // Execute swap
        uint256[] memory amounts = veloRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMinimum,
            routes,
            address(this),
            deadline
        );

        amountOut = amounts[amounts.length - 1];

        // Verify output
        if (amountOut < amountOutMinimum) revert InsufficientOutput();

        // Reset approve after swap (security)
        tokenInContract.forceApprove(address(veloRouter), 0);

        emit SwapExecuted(
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            block.timestamp
        );
    }

    /**
     * @notice Get quote for swap (view function)
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @return amountOut Expected output
     */
    function getQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        if (amountIn == 0) return 0;

        // Check pool exists
        address pool = poolFactory.getPool(tokenIn, tokenOut, false);
        if (pool == address(0)) return 0;

        // Build route
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({
            from: tokenIn,
            to: tokenOut,
            stable: false,
            factory: address(0)
        });

        // Get quote via router
        uint256[] memory amounts = veloRouter.getAmountsOut(amountIn, routes);
        return amounts[amounts.length - 1];
    }

    // ============ TOKEN MANAGEMENT ============

    /**
     * @notice Withdraw tokens with solvency enforcement for USDC
     * @param token Token address
     * @param amount Amount to withdraw
     * @dev LoanManager can always withdraw (for repayment/liquidation)
     * @dev Owner can withdraw non-USDC freely
     * @dev Owner can only withdraw USDC if remaining balance >= loan repayment
     */
    function withdraw(address token, uint256 amount) external {
        if (msg.sender != owner() && msg.sender != loanManager) {
            revert Unauthorized();
        }
        if (amount == 0) revert InvalidAmount();

        // LoanManager can always withdraw (for loan repayment/liquidation)
        if (msg.sender == loanManager) {
            IERC20(token).safeTransfer(msg.sender, amount);
            emit TokensWithdrawn(token, msg.sender, amount);
            return;
        }

        // Owner withdrawal logic
        // Non-USDC tokens: always allowed
        if (token != usdcToken) {
            IERC20(token).safeTransfer(msg.sender, amount);
            emit TokensWithdrawn(token, msg.sender, amount);
            return;
        }

        // USDC withdrawal: enforce solvency check
        ILoanManager loanMgr = ILoanManager(loanManager);

        // If no active loan, allow full withdrawal
        if (!loanMgr.hasActiveLoan(owner())) {
            IERC20(token).safeTransfer(msg.sender, amount);
            emit TokensWithdrawn(token, msg.sender, amount);
            return;
        }

        // Active loan exists: check solvency
        uint256 currentBalance = IERC20(usdcToken).balanceOf(address(this));
        uint256 minimumRequired = loanMgr.getMinimumUSDCRequired(owner());

        // Ensure remaining balance after withdrawal >= minimum required
        if (currentBalance < amount) {
            revert InvalidAmount();
        }

        uint256 remainingBalance = currentBalance - amount;
        if (remainingBalance < minimumRequired) {
            revert InsufficientUSDCForLoan();
        }

        IERC20(token).safeTransfer(msg.sender, amount);
        emit TokensWithdrawn(token, msg.sender, amount);
    }

    /**
     * @notice Get token balance
     * @param token Token address
     * @return balance Token balance
     */
    function getBalance(address token) external view returns (uint256 balance) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Check if token is whitelisted
     * @param token Token address
     * @return isWhitelisted True if whitelisted
     */
    function isTokenWhitelisted(address token) external view returns (bool) {
        return whitelistedTokens[token];
    }

    /**
     * @notice Get maximum withdrawable USDC amount
     * @return maxWithdrawable Maximum USDC that can be withdrawn by owner
     */
    function getMaxWithdrawableUSDC()
        external
        view
        returns (uint256 maxWithdrawable)
    {
        ILoanManager loanMgr = ILoanManager(loanManager);
        uint256 currentBalance = IERC20(usdcToken).balanceOf(address(this));

        // No active loan = can withdraw everything
        if (!loanMgr.hasActiveLoan(owner())) {
            return currentBalance;
        }

        uint256 minimumRequired = loanMgr.getMinimumUSDCRequired(owner());

        if (currentBalance > minimumRequired) {
            return currentBalance - minimumRequired;
        }
        return 0;
    }

    // ============ ADMIN FUNCTIONS ============

    /**
     * @notice Add whitelisted token (owner only)
     * @param token Token address to whitelist
     */
    function addWhitelistedToken(address token) external onlyOwner {
        if (token == address(0)) revert InvalidAddress();
        whitelistedTokens[token] = true;
    }

    /**
     * @notice Remove whitelisted token (owner only)
     * @param token Token address to remove
     */
    function removeWhitelistedToken(address token) external onlyOwner {
        whitelistedTokens[token] = false;
    }
}
