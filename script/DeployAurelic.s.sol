// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {MockETH} from "../src/MockETH.sol";
import {MockBTC} from "../src/MockBTC.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {CollateralManager} from "../src/CollateralManager.sol";
import {RestrictedWalletFactory} from "../src/RestrictedWalletFactory.sol";
import {LoanManager} from "../src/LoanManager.sol";

/**
 * @title DeployAurelic
 * @notice Deploy Aurelic protocol with fixed repay loan functionality
 * @dev This script deploys the corrected version with LoanManager authorization
 */
contract DeployAurelic is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Mock Tokens
        MockUSDC mockUSDC = new MockUSDC();
        MockETH mockETH = new MockETH();
        MockBTC mockBTC = new MockBTC();

        console.log("MockUSDC deployed at:", address(mockUSDC));
        console.log("MockETH deployed at:", address(mockETH));
        console.log("MockBTC deployed at:", address(mockBTC));

        // Deploy Core Contracts with placeholder addresses
        LendingPool lendingPool = new LendingPool(address(mockUSDC), address(0x1));
        console.log("LendingPool deployed at:", address(lendingPool));

        CollateralManager collateralManager = new CollateralManager(address(0x1));
        console.log("CollateralManager deployed at:", address(collateralManager));

        RestrictedWalletFactory walletFactory = new RestrictedWalletFactory(address(0x1));
        console.log("RestrictedWalletFactory deployed at:", address(walletFactory));

        LoanManager loanManager = new LoanManager(
            address(lendingPool), address(collateralManager), address(walletFactory), address(mockUSDC)
        );
        console.log("LoanManager deployed at:", address(loanManager));

        // Update contract references
        lendingPool.setLoanManager(address(loanManager));
        collateralManager.setLoanManager(address(loanManager));
        walletFactory.setLoanManager(address(loanManager));

        console.log("All contracts deployed and configured successfully!");

        vm.stopBroadcast();
    }
}
