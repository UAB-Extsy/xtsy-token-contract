const { ethers } = require('ethers');

// Parameters
const userAddress = '0xD91D65Bb458cE10E83b740BBc9DF29839f56a8B1'; // Your address from seth estimate
const amount = '1000000000000'; // ETH amount in wei
const nonce = '1';
const contractAddress = '0xD4D47103df0f67BD23b7c4DeAfD552Ef1Ce80bda';
const backendSignerPrivateKey = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

async function createSignature() {
    // Create wallet from private key
    const wallet = new ethers.Wallet(backendSignerPrivateKey);
    console.log('Backend signer address:', wallet.address);
    
    // Create message hash (same as contract: keccak256(abi.encodePacked(user, amount, nonce, address(this))))
    const messageHash = ethers.solidityPackedKeccak256(
        ['address', 'uint256', 'uint256', 'address'],
        [userAddress, amount, nonce, contractAddress]
    );
    
    console.log('Message hash:', messageHash);
    
    // Sign the message hash (contract will convert to eth signed message hash)
    const signature = await wallet.signMessage(ethers.getBytes(messageHash));
    
    console.log('Signature:', signature);
    console.log('Signature (without 0x):', signature.slice(2));
    
    // Verify signature
    const recoveredAddress = ethers.verifyMessage(ethers.getBytes(messageHash), signature);
    console.log('Recovered address:', recoveredAddress);
    console.log('Signature valid:', recoveredAddress.toLowerCase() === wallet.address.toLowerCase());
}

createSignature().catch(console.error);