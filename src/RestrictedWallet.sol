// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {UniversalRouter} from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import {Commands} from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";

/**
 * @title RestrictedWallet - Smart Wallet for Aurelic Protocol
 * @notice Secure DeFi trading wallet with Uniswap V4 integration
 * @dev Built for hackathon demonstration with clean V4-focused architecture
 */
contract RestrictedWallet is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ STATE VARIABLES ============

    /// @notice Universal Router for Uniswap V4 swaps
    UniversalRouter public immutable universalRouter;

    /// @notice Pool Manager for Uniswap V4
    IPoolManager public immutable poolManager;

    /// @notice Permit2 for enhanced token approvals
    IPermit2 public immutable permit2;

    /// @notice Mapping of approved target contracts
    mapping(address => bool) public approvedTargets;

    /// @notice Mapping of approved function selectors
    mapping(bytes4 => bool) public approvedSelectors;

    /// @notice Mapping of whitelisted tokens
    mapping(address => bool) public whitelistedTokens;

    /// @notice Authorized loan manager address
    address public loanManager;

    // ============ EVENTS ============

    event TargetWhitelisted(address indexed target, bool approved);
    event SelectorApproved(bytes4 indexed selector, bool approved);
    event TokenWhitelisted(address indexed token, bool whitelisted);
    event V4TradeExecuted(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event TokensReceived(address indexed token, uint256 amount);
    event TokensWithdrawn(address indexed token, uint256 amount);

    // ============ CONSTRUCTOR ============

    constructor(
        address _initialOwner,
        address _universalRouter,
        address _poolManager,
        address _permit2,
        address _loanManager
    ) Ownable(_initialOwner) {
        require(_universalRouter != address(0), "Invalid Universal Router");
        require(_poolManager != address(0), "Invalid Pool Manager");
        require(_permit2 != address(0), "Invalid Permit2");
        require(_loanManager != address(0), "Invalid Loan Manager");

        universalRouter = UniversalRouter(payable(_universalRouter));
        poolManager = IPoolManager(_poolManager);
        permit2 = IPermit2(_permit2);
        loanManager = _loanManager;

        _setupV4Selectors();
    }

    // ============ V4 SWAP FUNCTIONS ============

    /**
     * @notice Execute exact input single swap using Uniswap V4
     * @param poolKey The pool key for the swap
     * @param amountIn Exact amount of input tokens
     * @param amountOutMinimum Minimum amount of output tokens
     * @param deadline Transaction deadline
     * @return amountOut Amount of tokens received
     */
    function swapExactInputSingleV4(
        PoolKey calldata poolKey,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 deadline
    ) external onlyOwner nonReentrant returns (uint256 amountOut) {
        require(block.timestamp <= deadline, "Transaction expired");
        require(amountIn > 0, "Invalid amount");

        // Validate tokens are whitelisted
        address tokenIn = Currency.unwrap(poolKey.currency0);
        address tokenOut = Currency.unwrap(poolKey.currency1);
        require(whitelistedTokens[tokenIn], "Input token not whitelisted");
        require(whitelistedTokens[tokenOut], "Output token not whitelisted");

        // Check balance
        require(IERC20(tokenIn).balanceOf(address(this)) >= amountIn, "Insufficient token balance");

        // Execute swap
        amountOut = _swapExactInputSingleV4(poolKey, amountIn, amountOutMinimum, deadline);

        emit V4TradeExecuted(tokenIn, tokenOut, amountIn, amountOut);
    }

    /**
     * @notice Execute exact output single swap using Uniswap V4
     * @param poolKey The pool key for the swap
     * @param amountOut Exact amount of output tokens desired
     * @param amountInMaximum Maximum amount of input tokens willing to spend
     * @param deadline Transaction deadline
     * @return amountIn Amount of tokens spent
     */
    function swapExactOutputSingleV4(
        PoolKey calldata poolKey,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint256 deadline
    ) external onlyOwner nonReentrant returns (uint256 amountIn) {
        require(block.timestamp <= deadline, "Transaction expired");
        require(amountOut > 0, "Invalid amount");

        // Validate tokens are whitelisted
        address tokenIn = Currency.unwrap(poolKey.currency0);
        address tokenOut = Currency.unwrap(poolKey.currency1);
        require(whitelistedTokens[tokenIn], "Input token not whitelisted");
        require(whitelistedTokens[tokenOut], "Output token not whitelisted");

        // Execute swap
        amountIn = _swapExactOutputSingleV4(poolKey, amountOut, amountInMaximum, deadline);

        emit V4TradeExecuted(tokenIn, tokenOut, amountIn, amountOut);
    }

    // ============ EXECUTE FUNCTION ============

    /**
     * @notice Execute arbitrary call to approved target
     * @param target Target contract address
     * @param data Call data
     */
    function execute(address target, bytes calldata data) external onlyOwner {
        require(approvedTargets[target], "Target not approved");

        (bool success,) = target.call(data);
        require(success, "Call failed");
    }

    // ============ TOKEN MANAGEMENT ============

    /**
     * @notice Get token balance
     * @param token Token address
     * @return balance Token balance
     */
    function getBalance(address token) external view returns (uint256 balance) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Withdraw tokens (owner or loan manager only)
     * @param token Token address
     * @param amount Amount to withdraw
     */
    function withdrawTokens(address token, uint256 amount) external {
        require(msg.sender == owner() || msg.sender == loanManager, "Not authorized");
        require(amount > 0, "Invalid amount");
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient balance");

        IERC20(token).safeTransfer(owner(), amount);
        emit TokensWithdrawn(token, amount);
    }

    // ============ POOL KEY UTILITIES ============

    /**
     * @notice Create pool key with sorted currencies
     * @param token0 First token address
     * @param token1 Second token address
     * @return poolKey Sorted pool key
     */
    function getPoolKey(address token0, address token1) external pure returns (PoolKey memory poolKey) {
        // Ensure currencies are sorted by address
        if (token0 < token1) {
            return PoolKey({
                currency0: Currency.wrap(token0),
                currency1: Currency.wrap(token1),
                fee: 3000,
                tickSpacing: 60,
                hooks: IHooks(address(0))
            });
        } else {
            return PoolKey({
                currency0: Currency.wrap(token1),
                currency1: Currency.wrap(token0),
                fee: 3000,
                tickSpacing: 60,
                hooks: IHooks(address(0))
            });
        }
    }

    // ============ ADMIN FUNCTIONS ============

    /**
     * @notice Add approved target
     * @param target Target address
     */
    function addApprovedTarget(address target) external onlyOwner {
        require(target != address(0), "Invalid target");
        approvedTargets[target] = true;
        emit TargetWhitelisted(target, true);
    }

    /**
     * @notice Remove approved target
     * @param target Target address
     */
    function removeApprovedTarget(address target) external onlyOwner {
        approvedTargets[target] = false;
        emit TargetWhitelisted(target, false);
    }

    /**
     * @notice Add approved selector
     * @param selector Function selector
     */
    function addApprovedSelector(bytes4 selector) external onlyOwner {
        approvedSelectors[selector] = true;
        emit SelectorApproved(selector, true);
    }

    /**
     * @notice Remove approved selector
     * @param selector Function selector
     */
    function removeApprovedSelector(bytes4 selector) external onlyOwner {
        approvedSelectors[selector] = false;
        emit SelectorApproved(selector, false);
    }

    /**
     * @notice Add whitelisted token
     * @param token Token address
     */
    function addWhitelistedToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token");
        whitelistedTokens[token] = true;
        emit TokenWhitelisted(token, true);
    }

    /**
     * @notice Remove whitelisted token
     * @param token Token address
     */
    function removeWhitelistedToken(address token) external onlyOwner {
        whitelistedTokens[token] = false;
        emit TokenWhitelisted(token, false);
    }

    /**
     * @notice Add multiple whitelisted tokens
     * @param tokens Array of token addresses
     */
    function addWhitelistedTokensBatch(address[] calldata tokens) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokens[i] != address(0), "Invalid token");
            whitelistedTokens[tokens[i]] = true;
            emit TokenWhitelisted(tokens[i], true);
        }
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @notice Check if target is approved
     * @param target Target address
     * @return approved True if approved
     */
    function isTargetApproved(address target) external view returns (bool approved) {
        return approvedTargets[target];
    }

    /**
     * @notice Check if selector is approved
     * @param selector Function selector
     * @return approved True if approved
     */
    function isSelectorApproved(bytes4 selector) external view returns (bool approved) {
        return approvedSelectors[selector];
    }

    /**
     * @notice Check if token is whitelisted
     * @param token Token address
     * @return whitelisted True if whitelisted
     */
    function isTokenWhitelisted(address token) external view returns (bool whitelisted) {
        return whitelistedTokens[token];
    }

    // ============ INTERNAL FUNCTIONS ============

    /**
     * @notice Setup approved selectors for V4 trading
     */
    function _setupV4Selectors() internal {
        // Universal Router selectors
        approvedSelectors[bytes4(keccak256("execute(bytes,bytes[],uint256)"))] = true;

        // Position Manager selectors
        approvedSelectors[IPositionManager.modifyLiquidities.selector] = true;

        // Pool Manager selectors
        approvedSelectors[IPoolManager.initialize.selector] = true;

        // ERC20 selectors
        approvedSelectors[IERC20.approve.selector] = true;
        approvedSelectors[IERC20.transfer.selector] = true;
        approvedSelectors[IERC20.transferFrom.selector] = true;

        // Auto-approve V4 contracts as targets
        approvedTargets[address(universalRouter)] = true;
        approvedTargets[address(poolManager)] = true;
        approvedTargets[address(permit2)] = true;

        emit TargetWhitelisted(address(universalRouter), true);
        emit TargetWhitelisted(address(poolManager), true);
        emit TargetWhitelisted(address(permit2), true);
    }

    /**
     * @notice Internal V4 exact input single swap
     */
    function _swapExactInputSingleV4(
        PoolKey calldata poolKey,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        // Encode V4 swap command
        bytes memory commands = abi.encodePacked(uint8(0x00)); // V4_SWAP

        // Encode actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            poolKey,
            true, // zeroForOne
            uint128(amountIn),
            uint128(amountOutMinimum),
            bytes("") // hookData
        );
        params[1] = abi.encode(poolKey.currency0, amountIn);
        params[2] = abi.encode(poolKey.currency1, amountOutMinimum);

        // Execute swap
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(actions, params);

        universalRouter.execute(commands, inputs, deadline);

        // Return actual amount received
        address tokenOut = Currency.unwrap(poolKey.currency1);
        amountOut = IERC20(tokenOut).balanceOf(address(this));
    }

    /**
     * @notice Internal V4 exact output single swap
     */
    function _swapExactOutputSingleV4(
        PoolKey calldata poolKey,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint256 deadline
    ) internal returns (uint256 amountIn) {
        // Encode V4 swap command
        bytes memory commands = abi.encodePacked(uint8(0x00)); // V4_SWAP

        // Encode actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_OUT_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            poolKey,
            true, // zeroForOne
            uint128(amountOut),
            uint128(amountInMaximum),
            bytes("") // hookData
        );
        params[1] = abi.encode(poolKey.currency0, amountInMaximum);
        params[2] = abi.encode(poolKey.currency1, amountOut);

        // Execute swap
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(actions, params);

        universalRouter.execute(commands, inputs, deadline);

        // Return actual amount spent
        address tokenIn = Currency.unwrap(poolKey.currency0);
        amountIn = amountInMaximum - IERC20(tokenIn).balanceOf(address(this));
    }
}
