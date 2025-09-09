# XTSY Token - Tokenomics Implementation

## Overview

The XTSY token automatically distributes the total supply of 500M tokens according to the implemented tokenomics during deployment.

## Token Distribution (500M Total Supply)

| Allocation      | Percentage | Amount (XTSY) | Description                              |
| --------------- | ---------- | ------------- | ---------------------------------------- |
| Presale         | 2%         | 10,000,000    | Distributed during presale phases        |
| Public Sale     | 6%         | 30,000,000    | Distributed during public sale phases    |
| Liquidity       | 7%         | 35,000,000    | Liquidity & market making allocation     |
| Team & Advisors | 15%        | 75,000,000    | Team allocation (should be vested)       |
| Ecosystem       | 20%        | 100,000,000   | Ecosystem growth and development         |
| Treasury        | 25%        | 125,000,000   | Protocol treasury for future development |
| Staking         | 15%        | 75,000,000    | Staking rewards and incentives           |
| Marketing       | 10%        | 50,000,000    | Marketing & partnerships allocation      |

## Implementation Details

### Constructor Parameters

The `ExtsyToken` constructor requires 9 addresses:

1. `initialOwner` - Contract owner (admin)
2. `_presaleAddress` - Receives 10M XTSY (2%) for presale
3. `_publicSaleAddress` - Receives 30M XTSY (6%) for public sale
4. `_liquidityAddress` - Receives 35M XTSY (7%) for liquidity
5. `_teamAdvisorsAddress` - Receives 75M XTSY (15%) for team (should implement vesting)
6. `_ecosystemAddress` - Receives 100M XTSY (20%) for ecosystem growth
7. `_treasuryAddress` - Receives 125M XTSY (25%) for treasury
8. `_stakingAddress` - Receives 75M XTSY (15%) for staking rewards
9. `_marketingAddress` - Receives 50M XTSY (10%) for marketing

### Key Features

1. **Automatic Distribution**: All 500M tokens are minted and distributed in the constructor
2. **Owner Minting**: Owner can mint additional tokens up to the maximum supply cap
3. **Burnable**: Users can burn their own tokens using OpenZeppelin's ERC20Burnable
4. **Immutable Addresses**: Allocation addresses are stored as immutable variables
5. **Supply Cap**: Maximum supply is hard-capped at 500M XTSY tokens

### Contract Constants

```solidity
uint256 public constant MAX_SUPPLY = 500_000_000 * 10**18;

uint256 public constant PRESALE_ALLOCATION = 200;           // 2%
uint256 public constant PUBLICSALE_ALLOCATION = 600;        // 6%
uint256 public constant LIQUIDITY_ALLOCATION = 700;         // 7%
uint256 public constant TEAM_ADVISORS_ALLOCATION = 1500;    // 15%
uint256 public constant ECOSYSTEM_ALLOCATION = 2000;        // 20%
uint256 public constant TREASURY_ALLOCATION = 2500;         // 25%
uint256 public constant STAKING_ALLOCATION = 1500;          // 15%
uint256 public constant MARKETING_ALLOCATION = 1000;        // 10%
```

### Deployment Example

```solidity
ExtsyToken token = new ExtsyToken(
    0x123..., // initialOwner
    0x456..., // presaleAddress (10M XTSY)
    0x789..., // publicSaleAddress (30M XTSY)
    0xABC..., // liquidityAddress (35M XTSY)
    0xDEF..., // teamAdvisorsAddress (75M XTSY)
    0x012..., // ecosystemAddress (100M XTSY)
    0x345..., // treasuryAddress (125M XTSY)
    0x678..., // stakingAddress (75M XTSY)
    0x901...  // marketingAddress (50M XTSY)
);
```

### Available Functions

#### Owner Functions

- `mint(address to, uint256 amount)` - Mint additional tokens (only owner)
- `transferOwnership(address newOwner)` - Transfer ownership
- `renounceOwnership()` - Renounce ownership

#### User Functions

- `burn(uint256 amount)` - Burn tokens from caller's balance
- `burnFrom(address account, uint256 amount)` - Burn tokens from account (requires allowance)

### Testing

Run the tokenomics distribution tests:

```bash
forge test --match-path test/TokenomicsDistribution.t.sol -vv
```

### Deployment Script

Use the deployment script with environment variables:

```bash
INITIAL_OWNER=0x... \
PRESALE_ADDRESS=0x... \
PUBLIC_SALE_ADDRESS=0x... \
LIQUIDITY_ADDRESS=0x... \
TEAM_ADVISORS_ADDRESS=0x... \
ECOSYSTEM_ADDRESS=0x... \
TREASURY_ADDRESS=0x... \
STAKING_ADDRESS=0x... \
MARKETING_ADDRESS=0x... \
forge script script/DeployExtsyToken.s.sol:DeployExtsyToken --rpc-url $RPC_URL --broadcast
```

## Important Notes

1. **Team Vesting**: The team allocation (75M XTSY) should ideally go to a vesting contract to implement proper vesting schedules.

2. **Liquidity Management**: The liquidity allocation (35M XTSY) should be managed for market making and liquidity provision.

3. **Staking Rewards**: The staking allocation (75M XTSY) should be distributed as rewards to stakers over time.

4. **Marketing Budget**: The marketing allocation (50M XTSY) should be used for partnerships and marketing campaigns.

5. **Supply Cap**: The total supply is capped at 500M XTSY. Additional minting is only possible up to this limit.

6. **Security**: All allocation addresses are validated to not be zero addresses during deployment.

## Verified Features

✅ Total supply correctly set to 500M XTSY
✅ Automatic distribution according to implemented percentages
✅ All allocation addresses stored as immutable
✅ Owner can mint additional tokens up to supply cap
✅ Burnable functionality using OpenZeppelin ERC20Burnable
✅ Zero address validation
✅ Supply cap enforcement
✅ All tests passing
