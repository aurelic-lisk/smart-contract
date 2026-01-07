// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./RestrictedWallet.sol";

/**
 * @title RestrictedWalletFactory
 * @notice Factory for creating RestrictedWallets for Aurelic PoC
 * - Only one wallet per borrower, created by LoanManager
 * - getOrCreateWallet returns existing or creates new wallet
 */
contract RestrictedWalletFactory is ReentrancyGuard {
    mapping(address => address) public userWallet;
    address[] public wallets;
    address public loanManager;

    event WalletCreated(address indexed user, address indexed wallet);

    /**
     * @notice Constructor
     * @param _loanManager LoanManager address
     */
    constructor(address _loanManager) {
        loanManager = _loanManager;
    }

    /**
     * @notice Update the LoanManager address
     */
    function setLoanManager(address _loanManager) external {
        require(loanManager == address(0x1) || msg.sender == loanManager, "Not authorized");
        require(_loanManager != address(0), "Invalid loan manager address");
        loanManager = _loanManager;
    }

    /**
     * @notice Create a restricted wallet for a borrower (only LoanManager)
     * @param borrower Borrower address
     * @return wallet Address of the created wallet
     */
    function createWallet(address borrower) external nonReentrant returns (address wallet) {
        require(msg.sender == loanManager, "Only loan manager");
        require(borrower != address(0), "Invalid borrower address");
        require(userWallet[borrower] == address(0), "Wallet already exists");
        RestrictedWallet newWallet = new RestrictedWallet(
            borrower,
            0x492E6456D9528771018DeB9E87ef7750EF184104, // Universal Router
            0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408, // Pool Manager
            0x000000000022D473030F116dDEE9F6B43aC78BA3, // Permit2
            loanManager // Loan Manager
        );
        userWallet[borrower] = address(newWallet);
        wallets.push(address(newWallet));
        emit WalletCreated(borrower, address(newWallet));
        return address(newWallet);
    }

    /**
     * @notice Get existing wallet or create new one for borrower (only LoanManager)
     * @param borrower Borrower address
     * @return wallet Address of the wallet
     */
    function getOrCreateWallet(address borrower) external nonReentrant returns (address wallet) {
        require(msg.sender == loanManager, "Only loan manager");
        require(borrower != address(0), "Invalid borrower address");
        if (userWallet[borrower] != address(0)) {
            return userWallet[borrower];
        }
        RestrictedWallet newWallet = new RestrictedWallet(
            borrower,
            0x492E6456D9528771018DeB9E87ef7750EF184104, // Universal Router
            0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408, // Pool Manager
            0x000000000022D473030F116dDEE9F6B43aC78BA3, // Permit2
            loanManager // Loan Manager
        );
        userWallet[borrower] = address(newWallet);
        wallets.push(address(newWallet));
        emit WalletCreated(borrower, address(newWallet));
        return address(newWallet);
    }

    /**
     * @notice Get wallet address for a borrower
     * @param borrower Borrower address
     * @return wallet Wallet address (0x0 if no wallet exists)
     */
    function getWallet(address borrower) external view returns (address wallet) {
        return userWallet[borrower];
    }

    /**
     * @notice Check if borrower has a wallet
     * @param borrower Borrower address
     * @return exists True if wallet exists
     */
    function hasWallet(address borrower) external view returns (bool exists) {
        return userWallet[borrower] != address(0);
    }

    /**
     * @notice Get all created wallet addresses
     * @return allWallets Array of all wallet addresses
     */
    function getAllWallets() external view returns (address[] memory allWallets) {
        return wallets;
    }

    /**
     * @notice Get total number of wallets created
     * @return count Total wallet count
     */
    function getWalletCount() external view returns (uint256 count) {
        return wallets.length;
    }
}
