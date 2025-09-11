# Clean XTSY Presale Deployment Guide

> **Note:** This guide is styled for clarity and quick onboarding. For a visually appealing experience, consider viewing this document in a Markdown viewer with Bootstrap styling.

---

## Overview

The `xtsySale.sol` contract is a **streamlined, modern presale contract** while retaining all major features and improving maintainability and configuration.

---

## 🚀 Key Features

- **Clean Architecture:** 576 lines
- **Dynamic Vesting:** 7 categories, each with configurable caps and schedules
- **Time Scaling:** 144x time compression for rapid testing (1 day = 10 minutes)
- **Multi-Currency:** Accepts USDT and USDC
- **Referral System:** 5% bonus for referrers
- **Dynamic Pricing:** Price increases at set intervals during public sale

---

## 📊 Vesting Categories

| Category                      | %   | Tokens | Vesting Schedule    |
| ----------------------------- | --- | ------ | ------------------- |
| **Presale**                   | 2%  | 10M    | 100% TGE            |
| **Public Sale**               | 6%  | 30M    | 100% TGE            |
| **Liquidity & Market Making** | 7%  | 35M    | 100% TGE            |
| **Team & Advisors**           | 15% | 75M    | 12m cliff, 24m vest |
| **Ecosystem Growth**          | 20% | 100M   | 36m vest            |
| **Treasury**                  | 25% | 125M   | 6m lock, 36m vest   |
| **Marketing & Partnerships**  | 10% | 50M    | 20% TGE, 6m vest    |
