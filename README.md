# Aurelic Protocol - Smart Contracts

## Overview

Aurelic Protocol is a community-backed prefunding system that enables 5x leverage trading through a 20/80 prefunding model. This repository contains the complete smart contract implementation deployed on Lisk Sepolia testnet.

## Network Information

- **Network**: Lisk Sepolia
- **Chain ID**: 4202
- **RPC URL**: https://rpc.sepolia-api.lisk.com
- **Explorer**: https://sepolia-blockscout.lisk.com

## Deployed Contracts

### Core Protocol Contracts

| Contract                | Address                                    | Description                        |
| ----------------------- | ------------------------------------------ | ---------------------------------- |
| LendingPool             | 0xc0d14dE4514696544d5a415ED4aB72A3c60EFFf3 | ERC-4626 vault for LP deposits     |
| CollateralManager       | 0x6E37b89B5FA2d85A360B368c42f40AB6Aa7Eb884 | Borrower collateral handler        |
| LoanManager             | 0x4391da449AaFa306cDBb434B732F8ACC508D5b7E | Core orchestrator for 20/80 model  |
| RestrictedWalletFactory | 0xd340A31467a2a145cbFEf8008Ce5DA72Df684F84 | Deploys RestrictedWallet instances |

### Mock Tokens

| Contract | Address                                    | Description            |
| -------- | ------------------------------------------ | ---------------------- |
| MockUSDC | 0xc309D45d4119487b30205784efF9abACF20872c0 | Mock USDC (6 decimals) |
| MockETH  | 0x8379372caeE37abEdacA9925a3D4d5aad2975B35 | Mock ETH (18 decimals) |
| MockBTC  | 0xb56967f199FF15b098195C6Dcb8e7f3fC26B43D9 | Mock BTC (8 decimals)  |

### Uniswap V4 Contracts

| Contract         | Address                                    | Description                   |
| ---------------- | ------------------------------------------ | ----------------------------- |
| PoolManager      | 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408 | Uniswap V4 pool manager       |
| Universal Router | 0x492E6456D9528771018DeB9E87ef7750EF184104 | Trade execution router        |
| Position Manager | 0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80 | Liquidity position management |
| Permit2          | 0x000000000022D473030F116dDEE9F6B43aC78BA3 | Enhanced token approvals      |

## Protocol Architecture

### 20/80 Prefunding Model

- **Borrower Margin**: 20% (required collateral)
- **Pool Funding**: 80% (from LendingPool)
- **Total Trading Power**: 5x leverage
- **Interest Rate**: 8% APR for borrowers
- **LP Yield**: 6% APY for liquidity providers

### Core Features

- **ERC-4626 Vault**: Standardized vault interface for LP deposits
- **RestrictedWallet**: Smart wallet for controlled trading execution
- **Uniswap V4 Integration**: Direct access to V4 pools
- **Access Control**: LoanManager authorization for withdrawals
- **Reentrancy Protection**: All contracts protected against reentrancy attacks
- **SafeERC20**: Secure token operations throughout

## Contract Interactions

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│     LP     │───▶│ LendingPool  │───▶│ LoanManager │
└─────────────┘    └──────────────┘    └─────────────┘
                                              │
                                              ▼
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│  Borrower   │───▶│CollateralMgr │───▶│RestrictedWallet│
└─────────────┘    └──────────────┘    └─────────────┘
                                              │
                                              ▼
                                    ┌─────────────┐
                                    │ Uniswap V4  │
                                    │    Pools    │
                                    └─────────────┘
```

## V4 Pools Configuration

All pools configured with fee 3000 (0.3%), tick spacing 60, no hooks:

| Pair     | Pool ID                                                            | Status      |
| -------- | ------------------------------------------------------------------ | ----------- |
| USDC/ETH | 0xb8c8ee21dc067700a8aca05a5c89af1b498bc9c4239718899080dd105a5ada32 | Initialized |
| USDC/BTC | 0x8c8647fb06835a711967f9ce23c5ef0a37352e3f15a1546e50066bc4c1ade76f | Initialized |
| ETH/BTC  | 0x64549200c3b190c572ade0fbfed337afbe56fa344e9fe0a3d744a1eeecf31dc9 | Initialized |

## Development Setup

### Prerequisites

- Foundry (forge, cast, anvil)
- Node.js 18+
- Git

### Installation

```bash
# Clone repository
git clone <repository-url>
cd smart-contract

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test
```

### Deployment

```bash
# Deploy all contracts to Lisk Sepolia with verification
forge script script/DeployAurelic.s.sol:DeployAurelic --broadcast --rpc-url https://rpc.sepolia-api.lisk.com --verify --verifier blockscout --verifier-url https://sepolia-blockscout.lisk.com/api
```

## Key Functions

### LendingPool (ERC-4626)

```solidity
function deposit(uint256 assets, address receiver) external returns (uint256 shares)
function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets)
function getAvailableLiquidity() external view returns (uint256)
```

### LoanManager

```solidity
function createLoan(uint256 loanAmount) external returns (bool success)
function repayLoan() external returns (bool success)
function getRequiredMargin(uint256 loanAmount) external pure returns (uint256)
function getPoolFunding(uint256 loanAmount) external pure returns (uint256)
```

### RestrictedWallet

```solidity
function swapExactInputSingleV4(PoolKey calldata poolKey, uint256 amountIn, uint256 amountOutMinimum, uint256 deadline) external returns (uint256 amountOut)
function getBalance(address token) external view returns (uint256)
function getPoolKey(address token0, address token1) external pure returns (PoolKey memory)
```

## Security Features

### Access Control

- Owner-only functions for critical operations
- LoanManager authorization for emergency withdrawals
- Function-level permissions throughout

### Input Validation

- Zero address checks
- Amount validation
- Deadline verification
- Balance sufficiency checks

### Reentrancy Protection

- OpenZeppelin ReentrancyGuard on all state-changing functions
- Safe token transfers using SafeERC20
- State changes before external calls

### Restriction Enforcement

- Whitelist-based protocol access
- Function selector validation
- Token whitelist enforcement
- No external transfers allowed

## Testing

### Run All Tests

```bash
forge test -v
```

### Run Specific Test Suites

```bash
# Test LendingPool
forge test --match-contract LendingPoolTest -v

# Test LoanManager
forge test --match-contract LoanManagerTest -v

# Test RestrictedWallet
forge test --match-contract RestrictedWalletTest -v

# Integration tests
forge test --match-contract IntegrationTest -v
```

### Test Coverage

- **LendingPool**: 100% function coverage
- **LoanManager**: 100% function coverage
- **CollateralManager**: 100% function coverage
- **RestrictedWallet**: 100% function coverage

## Demo Scenarios

### Liquidity Provider Flow

1. LP deposits USDC to LendingPool
2. Receives LP shares representing vault ownership
3. Earns 6% APY on deposited amount
4. Can withdraw shares + accrued yield anytime

### Borrower Flow

1. Borrower deposits 20% margin (e.g., 1,000 USDC for 5,000 USDC loan)
2. LoanManager creates loan and allocates 80% from LendingPool
3. RestrictedWallet receives combined 5,000 USDC
4. Borrower executes trades via Uniswap V4
5. Repays loan + 8% APR interest
6. Keeps any trading profits

## Environment Variables

```bash
# Lisk Sepolia RPC
export LISK_SEPOLIA_RPC="https://rpc.sepolia-api.lisk.com"

# Mock Token Addresses
export MOCK_USDC_ADDRESS="0x06c70B293398B0b3CA4d1ff22C9FbAB4A71C0b43"
export MOCK_ETH_ADDRESS="0x8C0BC545Da30642c5C36CaeB3Bf0025141069178"
export MOCK_BTC_ADDRESS="0x6EEB61c808Ea8Ca3EceE81fE26D21A75CD050009"

# Core Aurelic Contracts
export LENDING_POOL_ADDRESS="0xc0d14dE4514696544d5a415ED4aB72A3c60EFFf3"
export COLLATERAL_MANAGER_ADDRESS="0x6E37b89B5FA2d85A360B368c42f40AB6Aa7Eb884"
export LOAN_MANAGER_ADDRESS="0x4391da449AaFa306cDBb434B732F8ACC508D5b7E"
export RESTRICTED_WALLET_FACTORY_ADDRESS="0xd340A31467a2a145cbFEf8008Ce5DA72Df684F84"
```

## Deployment Status

- All smart contracts deployed and verified on Lisk Sepolia
- Uniswap V4 pools initialized and ready for trading
- Frontend integration complete with all ABIs exported
- 20/80 prefunding model fully implemented and tested
- Ready for hackathon demonstration

## Support

For technical inquiries or issues, please create a GitHub issue in this repository.

---

**Deployment Date**: January 2026  
**Network**: Lisk Sepolia (4202)  
**Status**: Production Ready for Demo
