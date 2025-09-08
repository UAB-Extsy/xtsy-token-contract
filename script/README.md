# Deployment Scripts

This directory contains deployment scripts for the XTSY token presale ecosystem.

## Available Scripts

### 1. `DeployMockUSDC.s.sol`

Deploys the MockUSDC contract for testing purposes.

**Features:**

- 6 decimal precision (like real USDC)
- Mintable and burnable by owner
- Initial supply of 10M USDC

**Usage:**

```bash
# Deploy MockUSDC
forge script script/DeployMockUSDC.s.sol --rpc-url <RPC_URL> --broadcast

# Mint additional USDC
forge script script/DeployMockUSDC.s.sol --sig "mint(address,uint256)" --rpc-url <RPC_URL> --broadcast

# Burn USDC
forge script script/DeployMockUSDC.s.sol --sig "burn(address,uint256)" --rpc-url <RPC_URL> --broadcast
```

### 2. `DeployMockUSDT.s.sol`

Deploys the MockUSDT contract for testing purposes.

**Features:**

- 6 decimal precision (like real USDT)
- Blacklist functionality
- Pause/unpause functionality
- Mint functionality
- Initial supply of 1M USDT

**Usage:**

```bash
# Deploy MockUSDT
forge script script/DeployMockUSDT.s.sol --rpc-url <RPC_URL> --broadcast

# Mint additional USDT
forge script script/DeployMockUSDT.s.sol --sig "mint(address,uint256)" --rpc-url <RPC_URL> --broadcast

# Add address to blacklist
forge script script/DeployMockUSDT.s.sol --sig "addBlacklist(address)" --rpc-url <RPC_URL> --broadcast

# Remove address from blacklist
forge script script/DeployMockUSDT.s.sol --sig "removeBlacklist(address)" --rpc-url <RPC_URL> --broadcast

# Pause contract
forge script script/DeployMockUSDT.s.sol --sig "pause()" --rpc-url <RPC_URL> --broadcast

# Unpause contract
forge script script/DeployMockUSDT.s.sol --sig "unpause()" --rpc-url <RPC_URL> --broadcast
```

### 3. `DeployTwoPhasePresaleWithReferral.s.sol`

Deploys the TwoPhasePresaleWithReferral contract with referral system.

**Features:**

- Two-phase presale (whitelist + public)
- Referral system with 5% bonus
- Support for both USDT and USDC payments
- Dynamic pricing for public sale
- Whitepaper-compliant configuration

**Usage:**

```bash
# Deploy presale contract
forge script script/DeployTwoPhasePresaleWithReferral.s.sol --rpc-url <RPC_URL> --broadcast

# Add addresses to whitelist
forge script script/DeployTwoPhasePresaleWithReferral.s.sol --sig "addWhitelist(address,address[])" --rpc-url <RPC_URL> --broadcast

# Set TGE timestamp
forge script script/DeployTwoPhasePresaleWithReferral.s.sol --sig "setTGE(address,uint256)" --rpc-url <RPC_URL> --broadcast
```

### 4. `DeployAll.s.sol`

Deploys all contracts in the correct order for a complete setup.

**Features:**

- Deploys MockUSDC, MockUSDT, and TwoPhasePresaleWithReferral
- Optionally deploys XTSY token
- Configures all contracts automatically
- Saves deployment addresses to file

**Usage:**

```bash
# Deploy all contracts (including XTSY token)
DEPLOY_XTSY=true forge script script/DeployAll.s.sol --rpc-url <RPC_URL> --broadcast

# Deploy all contracts (using existing XTSY token)
forge script script/DeployAll.s.sol --rpc-url <RPC_URL> --broadcast
```

## Environment Variables

Create a `.env` file with the following variables:

```env
# Required for all scripts
PRIVATE_KEY=your_private_key_here

# Required for TwoPhasePresaleWithReferral and DeployAll
XTSY_TOKEN_ADDRESS=0x... # Only if not deploying XTSY token
USDT_TOKEN_ADDRESS=0x... # Only if using existing USDT
USDC_TOKEN_ADDRESS=0x... # Only if using existing USDC

# Optional for DeployAll
DEPLOY_XTSY=true # Set to true to deploy XTSY token
```

## Deployment Order

For a complete setup, deploy contracts in this order:

1. **MockUSDC** (if using mock)
2. **MockUSDT** (if using mock)
3. **XTSY Token** (if not already deployed)
4. **TwoPhasePresaleWithReferral**

Or use `DeployAll.s.sol` to deploy everything at once.

## Configuration Details

### Presale Configuration

- **Presale Period**: Sep 10-15, 2025
- **Presale Price**: $0.025 per token
- **Presale Cap**: 10M XTSY tokens
- **Whitelist Required**: Yes

### Public Sale Configuration

- **Public Sale Period**: Sep 15 - Oct 15, 2025
- **Initial Price**: $0.10 per token
- **Price Increase**: $0.01 every 3 days
- **Public Sale Cap**: 30M XTSY tokens
- **Whitelist Required**: No

### Referral System

- **Referrer Bonus**: 5% of purchase amount
- **Referral Enabled**: Yes
- **Payment Tokens**: USDT and USDC (6 decimals)

## Post-Deployment Steps

1. **Add whitelist addresses** (for presale phase)
2. **Set TGE timestamp** (when tokens become claimable)
3. **Test the contracts** with small amounts
4. **Monitor the sale** and adjust if needed

## Testing

After deployment, you can test the contracts using the provided test files in the `test/` directory.

## Security Notes

- Keep your private key secure
- Test on testnets before mainnet deployment
- Verify all contract addresses after deployment
- Monitor contract interactions during the sale
