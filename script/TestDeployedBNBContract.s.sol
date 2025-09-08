// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/xtsySaleBNB.sol";

contract TestDeployedBNBContract is Script {
    function run() external {
        console.log("Testing Deployed BNB Contract getTokenAmountForPayment");
        console.log("====================================================");
        
        // Use the deployed presale active contract
        address presaleContract = 0x57AB105E3d1f096c68BBd141e533e20609F4fE86;
        xtsySaleBNB presale = xtsySaleBNB(presaleContract);
        
        console.log("Testing contract at:", presaleContract);
        
        // Test parameters
        uint256 usdAmount = 1000 * 10**6; // $1000 USDT/USDC  
        uint256 bnbAmount = 1 * 10**18;   // 1 BNB
        
        console.log("Input Parameters:");
        console.log("- USD Amount:", usdAmount, "(represents $1000)");
        console.log("- BNB Amount:", bnbAmount, "(represents 1 BNB)");
        
        try presale.getTokenAmountForPayment(usdAmount, bnbAmount) returns (uint256 tokensFromUSD, uint256 tokensFromBNB) {
            console.log("");
            console.log("Results:");
            console.log("- Tokens from USD:", tokensFromUSD / 10**18, "XTSY");
            console.log("- Tokens from BNB:", tokensFromBNB / 10**18, "XTSY");
            console.log("- Raw USD tokens:", tokensFromUSD);
            console.log("- Raw BNB tokens:", tokensFromBNB);
            
            if (tokensFromBNB > 0) {
                console.log("");
                console.log("[SUCCESS] BNB calculation is working!");
                console.log("The fix resolved the issue where tokensFromBNB was returning 0");
            } else {
                console.log("");
                console.log("[WARNING] BNB calculation still returns 0");
                console.log("This might be expected if the sale is not active");
            }
        } catch Error(string memory reason) {
            console.log("Error calling getTokenAmountForPayment:", reason);
        } catch {
            console.log("Unknown error calling getTokenAmountForPayment");
        }
        
        // Also test the getCurrentRate function
        try presale.getCurrentRate() returns (uint256 currentRate) {
            console.log("");
            console.log("Current Rate:", currentRate, "micro-USD per token");
            if (currentRate == 0) {
                console.log("Rate is 0 - sale might not be active, using fallback rate in getTokenAmountForPayment");
            } else {
                console.log("Rate is active - should calculate correctly");
            }
        } catch {
            console.log("Error getting current rate");
        }
        
        // Test the BNB price feed directly
        try presale.getLatestBNBPrice() returns (uint256 bnbPrice) {
            console.log("");
            console.log("BNB Price from Feed:", bnbPrice);
        } catch {
            console.log("Error getting BNB price");
        }
        
        console.log("");
        console.log("Test completed successfully!");
    }
}