// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./RestrictedWallet.sol";

/**
 * @title RestrictedWalletFactory - Velodrome Integration
 * @notice Factory for creating RestrictedWallets with Velodrome  AMM
 */
contract RestrictedWalletFactory is ReentrancyGuard {
    // ============ IMMUTABLES ============

    address public immutable veloRouter;
    address public immutable poolFactory;
    address public immutable loanManager;

    // ============ STATE VARIABLES ============

    address[] private whitelistedTokens;
    mapping(address => address) public userWallet;
    address[] public wallets;

    // ============ EVENTS ============

    event WalletCreated(address indexed user, address indexed wallet);

    // ============ CONSTRUCTOR ============

    /**
     * @notice Initialize factory with Velodrome contracts
     * @param _veloRouter Velodrome Router address
     * @param _poolFactory Velodrome PoolFactory address
     * @param _loanManager LoanManager address
     * @param _whitelistedTokens Initial token whitelist
     */
    constructor(
        address _veloRouter,
        address _poolFactory,
        address _loanManager,
        address[] memory _whitelistedTokens
    ) {
        require(_veloRouter != address(0), "Invalid router");
        require(_poolFactory != address(0), "Invalid factory");
        require(_loanManager != address(0), "Invalid loan manager");

        veloRouter = _veloRouter;
        poolFactory = _poolFactory;
        loanManager = _loanManager;
        whitelistedTokens = _whitelistedTokens;
    }

    // ============ FACTORY FUNCTIONS ============

    /**
     * @notice Create wallet for borrower (only LoanManager)
     * @param borrower Borrower address
     * @return wallet Address of created wallet
     */
    function createWallet(
        address borrower
    ) external nonReentrant returns (address wallet) {
        require(msg.sender == loanManager, "Only loan manager");
        require(borrower != address(0), "Invalid borrower");
        require(userWallet[borrower] == address(0), "Wallet exists");

        // FIX: Pass whitelist to constructor
        RestrictedWallet newWallet = new RestrictedWallet(
            borrower,
            veloRouter,
            poolFactory,
            loanManager,
            whitelistedTokens
        );

        wallet = address(newWallet);
        userWallet[borrower] = wallet;
        wallets.push(wallet);

        emit WalletCreated(borrower, wallet);
    }

    /**
     * @notice Get existing wallet or create new one (only LoanManager)
     * @param borrower Borrower address
     * @return wallet Address of wallet
     */
    function getOrCreateWallet(
        address borrower
    ) external nonReentrant returns (address wallet) {
        require(msg.sender == loanManager, "Only loan manager");
        require(borrower != address(0), "Invalid borrower");

        if (userWallet[borrower] != address(0)) {
            return userWallet[borrower];
        }

        // FIX: Pass whitelist to constructor
        RestrictedWallet newWallet = new RestrictedWallet(
            borrower,
            veloRouter,
            poolFactory,
            loanManager,
            whitelistedTokens
        );

        wallet = address(newWallet);
        userWallet[borrower] = wallet;
        wallets.push(wallet);

        emit WalletCreated(borrower, wallet);
    }

    // ============ VIEW FUNCTIONS ============

    function getWallet(address borrower) external view returns (address) {
        return userWallet[borrower];
    }

    function hasWallet(address borrower) external view returns (bool) {
        return userWallet[borrower] != address(0);
    }

    function getAllWallets() external view returns (address[] memory) {
        return wallets;
    }

    function getWalletCount() external view returns (uint256) {
        return wallets.length;
    }

    function getWhitelistedTokens() external view returns (address[] memory) {
        return whitelistedTokens;
    }
}
