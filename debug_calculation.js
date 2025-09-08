const { ethers } = require('ethers');

// Values from the debug call
const ethPriceUsd = '430756798400'; // 8 decimals from Chainlink
const currentRate = '100000'; // 6 decimals (0.10 USD)
const ethAmount = '1000000000000'; // wei (0.000001 ETH)

// Calculate USD amount: (ethAmount * ethPriceUsd) / (10^20)
const ethAmountBN = ethers.getBigInt(ethAmount);
const ethPriceUsdBN = ethers.getBigInt(ethPriceUsd);
const usdAmount = (ethAmountBN * ethPriceUsdBN) / ethers.getBigInt('100000000000000000000'); // 10^20

console.log('ETH amount (wei):', ethAmount);
console.log('ETH price (8 decimals):', ethPriceUsd);
console.log('USD amount (6 decimals):', usdAmount.toString());
console.log('USD amount in dollars:', Number(usdAmount) / 1000000);

// Calculate tokens: (usdAmount * 10^18) / currentRate
const currentRateBN = ethers.getBigInt(currentRate);
const tokensToAllocate = (usdAmount * ethers.getBigInt('1000000000000000000')) / currentRateBN;

console.log('Current rate (6 decimals):', currentRate);
console.log('Tokens to allocate:', tokensToAllocate.toString());
console.log('Tokens to allocate (formatted):', ethers.formatEther(tokensToAllocate));

// Check against presale cap
const presaleCap = ethers.getBigInt('20000000000000000000000000'); // 20M tokens
console.log('Presale cap:', presaleCap.toString());
console.log('Presale cap (formatted):', ethers.formatEther(presaleCap));
console.log('Will exceed cap?', tokensToAllocate > presaleCap);