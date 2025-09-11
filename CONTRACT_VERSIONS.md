# XTSY Sale Contract Versions

## Overview

There are three main versions of the XTSY sale contract, each tailored for a specific blockchain network:

1. **xtsySale.sol** – Ethereum mainnet (original)
2. **xtsySaleBNB.sol** – Binance Smart Chain (BNB Chain)
3. **xtsySalePOL.sol** – Polygon

---

## Key Differences

### Ethereum Contract (`xtsySale.sol`)

- **Token Transfer:** ✅ Tokens are transferred to buyers immediately upon purchase.
- **Native Currency:** ETH (uses Chainlink ETH/USD price feed).
- **Stablecoins Supported:** USDT, USDC.
- **Claiming:** Users receive tokens instantly; vesting and TGE claim features are fully implemented for other categories.
- **Vesting:** Full vesting and TGE claim support.

### BNB Contract (`xtsySaleBNB.sol`)

- **Token Transfer:** ❌ No direct token transfer; only allocation is tracked on BNB Chain.
- **Native Currency:** BNB (uses Chainlink BNB/USD price feed).
- **Stablecoins Supported:** USDT, USDC.
- **Backend Integration:** Purchases are tracked on BNB Chain; actual XTSY tokens are distributed on Ethereum by the backend.
- **Events:** Emits `PurchaseRecorded` and `ReferralRecorded` for backend monitoring.

### Polygon Contract (`xtsySalePOL.sol`)

- **Token Transfer:** ❌ No direct token transfer; only allocation is tracked on Polygon.
- **Native Currency:** MATIC (uses Chainlink MATIC/USD price feed).
- **Stablecoins Supported:** USDT, USDC.
- **Backend Integration:** Purchases are tracked on Polygon; actual XTSY tokens are distributed on Ethereum by the backend.
- **Events:** Emits `PurchaseRecorded` and `ReferralRecorded` for backend monitoring.

---

## Contract Functions

### Common Functions (All Contracts)
