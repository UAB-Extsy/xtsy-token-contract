# XTSY Sale Contract Versions

## Overview
Three versions of the XTSY sale contract have been created for different blockchain networks:

1. **xtsySale.sol** - Ethereum mainnet (original)
2. **xtsySaleBNB.sol** - Binance Smart Chain
3. **xtsySalePOL.sol** - Polygon

## Key Differences

### Ethereum Contract (xtsySale.sol)
- **Token Transfer**: ✅ Transfers tokens immediately to buyers
- **Native Currency**: ETH (via Chainlink ETH/USD price feed)
- **Stablecoins**: USDT, USDC
- **Claiming**: Users receive tokens immediately on purchase
- **Vesting**: Full functionality with TGE claiming for other categories

### BNB Contract (xtsySaleBNB.sol)
- **Token Transfer**: ❌ Only allocates tokens (no transfers)
- **Native Currency**: BNB (via Chainlink BNB/USD price feed)
- **Stablecoins**: USDT, USDC
- **Backend Integration**: Tokens transferred on Ethereum by backend
- **Events**: `TokensAllocated` and `TokensAllocatedWithReferral`

### POL Contract (xtsySalePOL.sol)
- **Token Transfer**: ❌ Only allocates tokens (no transfers)
- **Native Currency**: POL (via Chainlink POL/USD price feed)
- **Stablecoins**: USDT, USDC
- **Backend Integration**: Tokens transferred on Ethereum by backend
- **Events**: `TokensAllocated` and `TokensAllocatedWithReferral`

## Contract Functions

### Common Functions (All Contracts)
```solidity
// USDT/USDC purchases
buyTokensWithUSDT(uint256 amount, uint256 nonce, bytes signature)
buyTokensWithUSDC(uint256 amount, uint256 nonce, bytes signature)
buyTokensWithUSDTAndReferral(uint256 amount, address referrer, uint256 nonce, bytes signature)
buyTokensWithUSDCAndReferral(uint256 amount, address referrer, uint256 nonce, bytes signature)

// Native currency purchases
// Ethereum: buyTokensWithETH()
// BNB: buyTokensWithBNB()
// POL: buyTokensWithPOL()
```

### Unique to Each Network
- **Ethereum**: `buyTokensWithETH()`, `claimTGETokens()`, `claimVestedTokens()`
- **BNB**: `buyTokensWithBNB()`, `getLatestBNBPrice()`
- **POL**: `buyTokensWithPOL()`, `getLatestPOLPrice()`

## Token Allocation Caps (All Networks)
- **Presale**: 20M tokens (4%)
- **Public Sale**: 20M tokens (4%)
- **Liquidity**: 35M tokens (7%)
- **Team & Advisors**: 75M tokens (15%)
- **Ecosystem**: 100M tokens (20%)
- **Treasury**: 125M tokens (25%)
- **Marketing**: 50M tokens (10%)

## Chainlink Price Feeds Required

### BSC (BNB Chain)
- **BNB/USD**: Configure via `setBnbUsdPriceFeed(address)`

### Polygon
- **POL/USD**: Configure via `setMaticUsdPriceFeed(address)`

### Ethereum
- **ETH/USD**: Configure via `setEthUsdPriceFeed(address)`

## Backend Integration Notes

For BNB and POL contracts:
1. Contracts only track token allocations
2. Backend monitors purchase events
3. Backend triggers token transfers on Ethereum mainnet
4. Events to monitor: `TokensAllocated`, `TokensAllocatedWithReferral`

## Deployment Parameters

### All Contracts
```solidity
constructor(
    address _usdtToken,      // USDT token address
    address _usdcToken,      // USDC token address  
    address _owner,          // Contract owner
    address _backendSigner,  // Backend signature verification
    address _priceFeed       // Chainlink price feed
)
```

### Additional for Ethereum
```solidity
constructor(
    address _saleToken,      // XTSY token address (can be set later)
    // ... other parameters
)
```

## Testing
- **BNBSaleTest.t.sol**: Tests BNB contract functionality
- **POLSaleTest.t.sol**: Tests POL contract functionality
- **CleanPresaleTest.t.sol**: Tests Ethereum contract functionality