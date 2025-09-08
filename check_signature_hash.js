const { ethers } = require('ethers');

const signature = '0x858177de0fc3fc8287736e9603b37e36db108d54c7326b159f418f6a41cedeb821331ae75b5db1e5af950eeae1f1857bc4d81c0828e08448a9df421c6a2a64aa1b';

// Calculate signature hash (same as contract: keccak256(signature))
const signatureHash = ethers.keccak256(signature);

console.log('Signature:', signature);
console.log('Signature hash:', signatureHash);