# Clean XTSY Presale Deployment Guide

## Overview

The `xtsySale.sol` is a **57% smaller, cleaner version** of the original TwoPhasePresaleWithReferral contract. It maintains all functionality while being much more maintainable and easier to configure.

## Key Features

- **Clean Architecture**: 576 lines vs 1343 lines (57% reduction)
- **Dynamic Vesting Categories**: 7 categories with configurable caps and schedules
- **Time Scaling**: Built-in 144x time compression for testing (1 day = 10 minutes)
- **Multi-Currency Support**: USDT and USDC payments
- **Referral System**: 5% bonus for referrers
- **Dynamic Pricing**: Price increases every interval during public sale

## Vesting Categories

| Category | % | Tokens | Vesting Schedule |
|----------|---|---------|------------------|
| **Presale** | 2% | 10M | 100% TGE |
| **Public Sale** | 6% | 30M | 100% TGE |
| **Liquidity & Market Making** | 7% | 35M | 100% TGE |
| **Team & Advisors** | 15% | 75M | 12m cliff, 24m vest |
| **Ecosystem Growth** | 20% | 100M | 36m vest |
| **Treasury** | 25% | 125M | 6m lock, 36m vest |
| **Marketing & Partnerships** | 10% | 50M | 20% TGE, 6m vest |

## Deployment

### 1. Deploy Contracts

```bash
# Set your private key
export PRIVATE_KEY="your_private_key_here"

# Deploy all contracts
forge script script/DeployCleanPresale.s.sol:DeployCleanPresale --broadcast --rpc-url $RPC_URL
```

### 2. Timeline Configuration

The deployment script automatically configures:
- **2 hours**: Whitelist period (users can register)
- **2 hours**: Presale phase (whitelisted users only)
- **2 hours**: Public sale phase (anyone can buy)
- **+1 day**: TGE (Token Generation Event)

### 3. Pricing Structure

- **Presale Price**: $0.025 per XTSY
- **Public Sale Start**: $0.10 per XTSY
- **Price Increases**: $0.01 every 30 minutes during public sale

## Post-Deployment Management

### Add Users to Whitelist

```bash
# Add single user
forge script script/DeployCleanPresale.s.sol:DeployCleanPresale --sig "addWhitelist(address,address[])" <PRESALE_ADDRESS> "[0x...]"

# Add multiple users
forge script script/DeployCleanPresale.s.sol:DeployCleanPresale --sig "addWhitelist(address,address[])" <PRESALE_ADDRESS> "[0x..., 0x..., 0x...]"
```

### Allocate Team Tokens

```bash
# Allocate team tokens
forge script script/DeployCleanPresale.s.sol:DeployCleanPresale --sig "allocateTeamTokens(address,address[],uint256[])" <PRESALE_ADDRESS> "[0x...]" "[1000000000000000000000000]"
```

### Allocate Other Categories

```bash
# Marketing tokens
forge script script/DeployCleanPresale.s.sol:DeployCleanPresale --sig "allocateMarketingTokens(address,address[],uint256[])" <PRESALE_ADDRESS> "[0x...]" "[500000000000000000000000]"

# Treasury tokens  
forge script script/DeployCleanPresale.s.sol:DeployCleanPresale --sig "allocateTreasuryTokens(address,address[],uint256[])" <PRESALE_ADDRESS> "[0x...]" "[5000000000000000000000000]"

# Ecosystem tokens
forge script script/DeployCleanPresale.s.sol:DeployCleanPresale --sig "allocateEcosystemTokens(address,address[],uint256[])" <PRESALE_ADDRESS> "[0x...]" "[10000000000000000000000000]"
```

### Check Contract Status

```bash
forge script script/DeployCleanPresale.s.sol:DeployCleanPresale --sig "checkStatus(address)" <PRESALE_ADDRESS>
```

## Contract Functions

### For Users

```solidity
// Purchase tokens during presale (whitelisted users only)
buyTokensWithUSDT(uint256 usdtAmount)
buyTokensWithUSDC(uint256 usdcAmount)

// Purchase with referral bonus
buyTokensWithUSDTAndReferral(uint256 usdtAmount, address referrer)
buyTokensWithUSDCAndReferral(uint256 usdcAmount, address referrer)

// Claim tokens at TGE (presale/public buyers)
claimTGETokens()

// Claim vested tokens (team/advisors/etc)
claimVestedTokens(VestingCategory category)
```

### For Owner

```solidity
// Whitelist management
addToWhitelist(address user)
addBatchToWhitelist(address[] users)
removeFromWhitelist(address user)

// Token allocation
allocateTokens(address recipient, VestingCategory category, uint256 amount)
batchAllocateTokens(address[] recipients, VestingCategory category, uint256[] amounts)

// Configuration
configureSale(SaleConfig memory config)
updateVestingConfig(VestingCategory category, VestingConfig memory config)
setTGETimestamp(uint256 timestamp)
setReferralConfig(uint256 bonusPercent, bool enabled)

// Management
withdrawFunds()
emergencyTokenWithdraw()
pause() / unpause()
```

## View Functions

```solidity
// Get user information
getUserPurchaseInfo(address user) returns (UserPurchase)
getUserAllocation(address user, VestingCategory category) returns (UserAllocation)
getReferralInfo(address user) returns (ReferralInfo)

// Get category information
getCategoryInfo(VestingCategory category) returns (uint256 cap, uint256 allocated, VestingConfig config)

// Get contract stats
getContractStats() returns (uint256 presaleSold, uint256 publicSold, uint256 usdtRaised, uint256 usdcRaised, SalePhase phase)

// Get pricing
getCurrentRate() returns (uint256)
getCurrentPhase() returns (SalePhase)

// Get claimable amounts
getClaimableAmount(address user, VestingCategory category) returns (uint256)
```

## Testing

```bash
# Run clean presale tests
forge test --match-contract "CleanPresaleTest"

# Run specific test
forge test --match-test "testPresalePurchase"

# Run with verbosity
forge test --match-contract "CleanPresaleTest" -vv
```

## Vesting Categories Enum

```solidity
enum VestingCategory {
    Presale,        // 0
    PublicSale,     // 1  
    Liquidity,      // 2
    TeamAdvisors,   // 3
    Ecosystem,      // 4
    Treasury,       // 5
    Marketing       // 6
}
```

## Example Usage

```solidity
// Check presale cap
(uint256 cap, uint256 allocated, VestingConfig memory config) = presale.getCategoryInfo(VestingCategory.Presale);

// Allocate 1M tokens to team member
presale.allocateTokens(teamMember, VestingCategory.TeamAdvisors, 1_000_000 * 10**18);

// Check claimable amount
uint256 claimable = presale.getClaimableAmount(teamMember, VestingCategory.TeamAdvisors);

// Claim vested tokens
presale.claimVestedTokens(VestingCategory.TeamAdvisors);
```

## Time Scaling (For Testing)

The contract uses 144x time compression:
- 1 day → 10 minutes
- 1 hour → 25 seconds  
- 30 days → 5 hours
- 1 year → 2.5 days

This allows for rapid testing of long-term vesting schedules.

## Security Features

- **ReentrancyGuard**: Prevents reentrancy attacks
- **Pausable**: Emergency pause functionality
- **Ownable**: Access control for admin functions
- **Category Caps**: Automatic enforcement of allocation limits
- **Vesting Validation**: Cliff and vesting period validation

## Contract Addresses

After deployment, contract addresses will be saved to `clean_presale_deployment.txt`:

```
XTSY_TOKEN=0x...
MOCK_USDT=0x...
MOCK_USDC=0x...
CLEAN_PRESALE=0x...
```

## Support

For questions or issues, refer to the contract source code or create an issue in the repository.