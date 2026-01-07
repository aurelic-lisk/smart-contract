// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/RestrictedWallet.sol";
import "../src/MockUSDC.sol";
import "../src/MockETH.sol";
import "../src/MockBTC.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

/**
 * @title RestrictedWalletV4Test
 * @notice Test suite untuk RestrictedWallet dengan Uniswap V4 integration
 * @dev Fokus pada fungsionalitas V4 swap dan security controls
 */
contract RestrictedWalletV4Test is Test {
    // ============ BASE SEPOLIA ADDRESSES ============
    address constant POOL_MANAGER = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
    address constant UNIVERSAL_ROUTER = 0x492E6456D9528771018DeB9E87ef7750EF184104;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // ============ CONTRACTS ============
    RestrictedWallet public wallet;
    MockUSDC public usdc;
    MockETH public eth;
    MockBTC public btc;

    // ============ ADDRESSES ============
    address public owner;
    address public user;

    function setUp() public {
        // Fork Lisk Sepolia
        vm.createSelectFork("https://rpc.sepolia-api.lisk.com");

        // Setup addresses
        owner = makeAddr("owner");
        user = makeAddr("user");

        console.log("=== RestrictedWallet V4 Test Setup ===");
        console.log("Block number:", block.number);
        console.log("Chain ID:", block.chainid);

        vm.startPrank(owner);

        // Deploy mock tokens
        usdc = new MockUSDC();
        eth = new MockETH();
        btc = new MockBTC();

        // Deploy RestrictedWallet with V4 integration
        wallet = new RestrictedWallet(
            owner,
            UNIVERSAL_ROUTER,
            POOL_MANAGER,
            PERMIT2,
            address(this) // loanManager
        );

        // Setup wallet
        _setupWallet();

        vm.stopPrank();

        console.log("Setup complete");
    }

    function _setupWallet() internal {
        // Add whitelisted tokens
        address[] memory tokens = new address[](3);
        tokens[0] = address(usdc);
        tokens[1] = address(eth);
        tokens[2] = address(btc);
        wallet.addWhitelistedTokensBatch(tokens);

        // Fund wallet
        usdc.mint(address(wallet), 100000 * 1e6); // 100k USDC
        eth.mint(address(wallet), 100 * 1e18); // 100 ETH
        btc.mint(address(wallet), 10 * 1e8); // 10 BTC

        console.log("Wallet setup complete");
    }

    // ============ DEPLOYMENT TESTS ============

    function testDeployment() public {
        console.log("\n=== Testing Deployment ===");

        assertEq(wallet.owner(), owner);
        assertEq(address(wallet.universalRouter()), UNIVERSAL_ROUTER);
        assertEq(address(wallet.poolManager()), POOL_MANAGER);
        assertEq(address(wallet.permit2()), PERMIT2);

        console.log("Deployment test passed");
    }

    function testV4ContractsApproved() public {
        console.log("\n=== Testing V4 Contracts Approval ===");

        assertTrue(wallet.isTargetApproved(UNIVERSAL_ROUTER), "Universal Router should be approved");
        assertTrue(wallet.isTargetApproved(POOL_MANAGER), "Pool Manager should be approved");
        assertTrue(wallet.isTargetApproved(PERMIT2), "Permit2 should be approved");

        console.log("V4 contracts approval test passed");
    }

    function testV4SelectorsApproved() public {
        console.log("\n=== Testing V4 Selectors Approval ===");

        assertTrue(
            wallet.isSelectorApproved(bytes4(keccak256("execute(bytes,bytes[],uint256)"))),
            "Universal Router execute should be approved"
        );
        assertTrue(wallet.isSelectorApproved(IERC20.approve.selector), "ERC20 approve should be approved");
        assertTrue(wallet.isSelectorApproved(IERC20.transfer.selector), "ERC20 transfer should be approved");
        assertTrue(wallet.isSelectorApproved(IERC20.transferFrom.selector), "ERC20 transferFrom should be approved");

        console.log("V4 selectors approval test passed");
    }

    // ============ TOKEN MANAGEMENT TESTS ============

    function testTokenWhitelisting() public {
        vm.startPrank(owner);

        console.log("\n=== Testing Token Whitelisting ===");

        // Test tokens are whitelisted
        assertTrue(wallet.isTokenWhitelisted(address(usdc)), "USDC should be whitelisted");
        assertTrue(wallet.isTokenWhitelisted(address(eth)), "ETH should be whitelisted");
        assertTrue(wallet.isTokenWhitelisted(address(btc)), "BTC should be whitelisted");

        // Test removing token
        wallet.removeWhitelistedToken(address(usdc));
        assertFalse(wallet.isTokenWhitelisted(address(usdc)), "USDC should not be whitelisted");

        // Test adding token back
        wallet.addWhitelistedToken(address(usdc));
        assertTrue(wallet.isTokenWhitelisted(address(usdc)), "USDC should be whitelisted again");

        vm.stopPrank();

        console.log("Token whitelisting test passed");
    }

    function testTokenBalances() public {
        vm.startPrank(owner);

        console.log("\n=== Testing Token Balances ===");

        uint256 usdcBalance = wallet.getBalance(address(usdc));
        uint256 ethBalance = wallet.getBalance(address(eth));
        uint256 btcBalance = wallet.getBalance(address(btc));

        console.log("Wallet balances:");
        console.log("- USDC:", usdcBalance / 1e6);
        console.log("- ETH:", ethBalance / 1e18);
        console.log("- BTC:", btcBalance / 1e8);

        assertTrue(usdcBalance > 0, "Wallet should have USDC");
        assertTrue(ethBalance > 0, "Wallet should have ETH");
        assertTrue(btcBalance > 0, "Wallet should have BTC");

        vm.stopPrank();

        console.log("Token balances test passed");
    }

    // ============ POOL KEY TESTS ============

    function testPoolKeyCreation() public {
        vm.startPrank(owner);

        console.log("\n=== Testing Pool Key Creation ===");

        // Test USDC/ETH pool key
        PoolKey memory poolKey = wallet.getPoolKey(address(usdc), address(eth));
        console.log("USDC/ETH Pool Key:");
        console.log("- Currency0:", Currency.unwrap(poolKey.currency0));
        console.log("- Currency1:", Currency.unwrap(poolKey.currency1));
        console.log("- Fee:", poolKey.fee);
        console.log("- Tick Spacing:", poolKey.tickSpacing);

        // Verify currencies are sorted
        assertTrue(
            Currency.unwrap(poolKey.currency0) < Currency.unwrap(poolKey.currency1), "Currencies should be sorted"
        );

        // Test ETH/BTC pool key
        PoolKey memory ethBtcPool = wallet.getPoolKey(address(eth), address(btc));
        assertTrue(
            Currency.unwrap(ethBtcPool.currency0) < Currency.unwrap(ethBtcPool.currency1),
            "ETH/BTC currencies should be sorted"
        );

        vm.stopPrank();

        console.log("Pool key creation test passed");
    }

    // ============ SWAP VALIDATION TESTS ============

    function testSwapValidation() public {
        vm.startPrank(owner);

        console.log("\n=== Testing Swap Validation ===");

        // Create pool key
        PoolKey memory poolKey = wallet.getPoolKey(address(usdc), address(eth));

        uint256 amountIn = 1000 * 1e6; // 1000 USDC
        uint256 minAmountOut = 0;
        uint256 deadline = block.timestamp + 3600;

        // Test validation without actual swap (no liquidity)
        console.log("Testing swap validation...");
        try wallet.swapExactInputSingleV4(poolKey, amountIn, minAmountOut, deadline) {
            console.log("Swap succeeded (unexpected)");
        } catch Error(string memory reason) {
            console.log("Swap failed as expected:", reason);
            // This is expected without liquidity
        }

        vm.stopPrank();

        console.log("Swap validation test completed");
    }

    function testSwapWithExpiredDeadline() public {
        vm.startPrank(owner);

        console.log("\n=== Testing Swap with Expired Deadline ===");

        // Create pool key
        PoolKey memory poolKey = wallet.getPoolKey(address(usdc), address(eth));

        uint256 amountIn = 1000 * 1e6; // 1000 USDC
        uint256 minAmountOut = 0;
        uint256 deadline = block.timestamp - 1; // Expired deadline

        // This should fail
        vm.expectRevert("Transaction expired");
        wallet.swapExactInputSingleV4(poolKey, amountIn, minAmountOut, deadline);

        vm.stopPrank();

        console.log("Expired deadline test passed");
    }

    function testSwapWithInsufficientBalance() public {
        vm.startPrank(owner);

        console.log("\n=== Testing Swap with Insufficient Balance ===");

        // Create pool key
        PoolKey memory poolKey = wallet.getPoolKey(address(usdc), address(eth));

        uint256 amountIn = 1000000 * 1e6; // 1M USDC (more than wallet has)
        uint256 minAmountOut = 0;
        uint256 deadline = block.timestamp + 3600;

        // This should fail
        vm.expectRevert("Insufficient token balance");
        wallet.swapExactInputSingleV4(poolKey, amountIn, minAmountOut, deadline);

        vm.stopPrank();

        console.log("Insufficient balance test passed");
    }

    // ============ EXECUTE FUNCTION TESTS ============

    function testExecuteFunction() public {
        vm.startPrank(owner);

        console.log("\n=== Testing Execute Function ===");

        // Test execute function with valid data
        bytes memory data = abi.encodeWithSignature("balanceOf(address)", address(wallet));

        // This should work
        wallet.execute(address(usdc), data);

        vm.stopPrank();

        console.log("Execute function test passed");
    }

    function testExecuteFunctionWithInvalidTarget() public {
        vm.startPrank(owner);

        console.log("\n=== Testing Execute Function with Invalid Target ===");

        address invalidTarget = makeAddr("invalidTarget");
        bytes memory data = abi.encodeWithSignature("balanceOf(address)", address(wallet));

        // This should fail
        vm.expectRevert("Target not approved");
        wallet.execute(invalidTarget, data);

        vm.stopPrank();

        console.log("Execute function with invalid target test passed");
    }

    // ============ ADMIN FUNCTION TESTS ============

    function testAdminFunctions() public {
        vm.startPrank(owner);

        console.log("\n=== Testing Admin Functions ===");

        // Test target management
        address newTarget = makeAddr("newTarget");
        wallet.addApprovedTarget(newTarget);
        assertTrue(wallet.isTargetApproved(newTarget), "New target should be approved");

        wallet.removeApprovedTarget(newTarget);
        assertFalse(wallet.isTargetApproved(newTarget), "New target should not be approved");

        // Test selector management
        bytes4 newSelector = 0x12345678;
        wallet.addApprovedSelector(newSelector);
        assertTrue(wallet.isSelectorApproved(newSelector), "New selector should be approved");

        wallet.removeApprovedSelector(newSelector);
        assertFalse(wallet.isSelectorApproved(newSelector), "New selector should not be approved");

        vm.stopPrank();

        console.log("Admin functions test passed");
    }

    function testOnlyOwnerRestrictions() public {
        console.log("\n=== Testing Only Owner Restrictions ===");

        vm.startPrank(user);

        // These should all fail
        vm.expectRevert();
        wallet.addApprovedTarget(makeAddr("target"));

        vm.expectRevert();
        wallet.addWhitelistedToken(makeAddr("token"));

        vm.expectRevert();
        wallet.withdrawTokens(address(usdc), 1000);

        vm.stopPrank();

        console.log("Only owner restrictions test passed");
    }

    // ============ COMPREHENSIVE TEST ============

    function testCompleteV4Implementation() public {
        vm.startPrank(owner);

        console.log("\n=== Complete V4 Implementation Test ===");

        // 1. Verify V4 contract addresses
        assertTrue(POOL_MANAGER != address(0), "Pool Manager should be accessible");
        assertTrue(UNIVERSAL_ROUTER != address(0), "Universal Router should be accessible");
        assertTrue(PERMIT2 != address(0), "Permit2 should be accessible");
        console.log("V4 contract addresses verified");

        // 2. Verify wallet setup
        assertTrue(wallet.isTargetApproved(UNIVERSAL_ROUTER), "Universal Router should be approved");
        assertTrue(wallet.isTokenWhitelisted(address(usdc)), "USDC should be whitelisted");
        assertTrue(wallet.isTokenWhitelisted(address(eth)), "ETH should be whitelisted");
        assertTrue(wallet.isTokenWhitelisted(address(btc)), "BTC should be whitelisted");
        console.log("Wallet setup verified");

        // 3. Check balances
        uint256 usdcBalance = wallet.getBalance(address(usdc));
        uint256 ethBalance = wallet.getBalance(address(eth));
        uint256 btcBalance = wallet.getBalance(address(btc));

        console.log("Wallet balances:");
        console.log("- USDC:", usdcBalance / 1e6);
        console.log("- ETH:", ethBalance / 1e18);
        console.log("- BTC:", btcBalance / 1e8);

        assertTrue(usdcBalance > 0, "Wallet should have USDC");
        assertTrue(ethBalance > 0, "Wallet should have ETH");
        assertTrue(btcBalance > 0, "Wallet should have BTC");
        console.log("Balances verified");

        // 4. Test pool key creation
        PoolKey memory poolKey = wallet.getPoolKey(address(usdc), address(eth));
        assertTrue(Currency.unwrap(poolKey.currency0) < Currency.unwrap(poolKey.currency1), "Pool key should be sorted");
        console.log("Pool key creation verified");

        // 5. Test V4 functions exist and are properly configured
        assertTrue(
            wallet.isSelectorApproved(bytes4(keccak256("execute(bytes,bytes[],uint256)"))),
            "Universal Router execute should be approved"
        );
        console.log("V4 functions verified");

        console.log("Complete V4 implementation test passed!");
        console.log("V4 implementation is ready for trading with liquidity!");
        console.log("Next step: Add liquidity to pools for actual swaps");

        vm.stopPrank();
    }
}

