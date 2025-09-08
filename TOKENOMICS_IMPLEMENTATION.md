# XTSY Token - Tokenomics Implementation

## Overview
The XTSY token has been updated to automatically distribute the total supply of 500M tokens according to the whitepaper v0.2 tokenomics during deployment.

## Token Distribution (500M Total Supply)

| Allocation | Percentage | Amount (XTSY) | Description |
|------------|------------|---------------|-------------|
| Presale | 20% | 100,000,000 | Distributed during presale phases |
| Community & Ecosystem | 40% | 200,000,000 | Community incentives and ecosystem growth |
| Treasury Reserve | 20% | 100,000,000 | Protocol treasury for future development |
| Team & Advisors | 15% | 75,000,000 | Team allocation (should be vested) |
| Referral Bonus Pool | 5% | 25,000,000 | Rewards for referral program |

## Implementation Details

### Constructor Changes
The `ExtsyToken` constructor now requires 6 addresses:
1. `initialOwner` - Contract owner (admin)
2. `presaleAddress` - Receives 100M XTSY for presale
3. `communityAddress` - Receives 200M XTSY for community/ecosystem
4. `treasuryAddress` - Receives 100M XTSY for treasury
5. `teamAddress` - Receives 75M XTSY for team (should implement vesting)
6. `referralPoolAddress` - Receives 25M XTSY for referral bonuses

### Key Changes Made

1. **Automatic Distribution**: All 500M tokens are minted and distributed in the constructor
2. **Removed Mint Function**: No additional tokens can be minted after deployment
3. **Immutable Addresses**: Allocation addresses are stored as immutable variables
4. **Helper Functions**: Added `getPresaleAllocation()` and `getReferralAllocation()` for easy reference

### Deployment Example

```solidity
ExtsyToken token = new ExtsyToken(
    0x123..., // owner
    0x456..., // presale contract
    0x789..., // community wallet
    0xABC..., // treasury wallet
    0xDEF..., // team wallet (should be vesting contract)
    0x012...  // referral pool (managed by presale contract)
);
```

### Testing
Run the tokenomics distribution tests:
```bash
forge test --match-path test/TokenomicsDistribution.t.sol -vv
```

### Deployment Script
Use the updated deployment script with environment variables:
```bash
INITIAL_OWNER=0x... \
PRESALE_ADDRESS=0x... \
COMMUNITY_ADDRESS=0x... \
TREASURY_ADDRESS=0x... \
TEAM_ADDRESS=0x... \
REFERRAL_POOL_ADDRESS=0x... \
forge script script/DeployExtsyToken.s.sol:DeployExtsyToken --rpc-url $RPC_URL --broadcast
```

## Important Notes

1. **Team Vesting**: The team allocation (75M XTSY) should ideally go to a vesting contract to implement the 2-year vesting schedule with 6-month cliff as mentioned in the whitepaper.

2. **Referral Pool Management**: The referral pool (25M XTSY) should be managed by the presale contract or a separate referral manager contract to distribute rewards.

3. **No Additional Minting**: Once deployed, no additional tokens can be created. The total supply is fixed at 500M XTSY.

4. **Security**: All allocation addresses are validated to not be zero addresses during deployment.

## Verified Features

✅ Total supply correctly set to 500M XTSY
✅ Automatic distribution according to whitepaper percentages
✅ All allocation addresses stored as immutable
✅ No mint function - supply is fixed
✅ Zero address validation
✅ All tests passing