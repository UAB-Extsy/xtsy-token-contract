// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/xtsySaleBNB.sol";

contract TestBNBCalculation is Script {
    function run() external {
        // Use the deployed contract address or deploy a new one for testing
        console.log("Testing BNB Token Amount Calculation");
        console.log("=====================================");
        
        // Test parameters
        uint256 usdAmount = 1000 * 10**6; // $1000 USDT/USDC
        uint256 bnbAmount = 1 * 10**18;   // 1 BNB
        
        console.log("Input Parameters:");
        console.log("USD Amount:", usdAmount, "(represents $1000)");
        console.log("BNB Amount:", bnbAmount, "(represents 1 BNB)");
        
        // If you have a deployed contract address, you can test it directly
        // address contractAddress = 0x...; // Replace with actual address
        // xtsySaleBNB presale = xtsySaleBNB(contractAddress);
        
        // For demonstration, let's show the expected calculation logic
        console.log("");
        console.log("Expected Behavior:");
        console.log("- If sale is active: use getCurrentRate()");
        console.log("- If sale is inactive: use presaleRate as fallback");
        console.log("- Presale rate: 100000 micro-USD ($0.10 per token)");
        console.log("- With 1 BNB at ~$600, should get ~6000 XTSY tokens");
        
        // Calculate expected tokens for $1000 at $0.10 per token
        uint256 expectedTokensFromUSD = (usdAmount * 10**18) / 100000; // 10,000 tokens
        console.log("Expected tokens from $1000 USD:", expectedTokensFromUSD / 10**18, "XTSY");
        
        // If BNB price is ~$600 and token price is $0.10, 1 BNB should get 6000 tokens
        console.log("Expected tokens from 1 BNB (~$600):", "~6000 XTSY");
        
        console.log("");
        console.log("Test completed. Use this script with a deployed contract to verify actual results.");
    }
}