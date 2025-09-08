// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TwoPhasePresaleWithReferral.sol";
import "../src/ExtsyToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployTwoPhasePresaleWithReferral is Script {
    function run() external {
        // Load configuration from environment variables
        address xtsyTokenAddress = vm.envAddress("XTSY_TOKEN_ADDRESS");
        address usdtTokenAddress = vm.envAddress("USDT_TOKEN_ADDRESS");
        address usdcTokenAddress = vm.envAddress("USDC_TOKEN_ADDRESS");
        
        // Start deployment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying TwoPhasePresaleWithReferral contract for XTSY token...");
        console.log("Deployer:", deployer);
        console.log("XTSY Token:", xtsyTokenAddress);
        console.log("USDT Token:", usdtTokenAddress);
        console.log("USDC Token:", usdcTokenAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy presale contract with referral system
        TwoPhasePresaleWithReferral presale = new TwoPhasePresaleWithReferral(
            xtsyTokenAddress,
            usdtTokenAddress,
            usdcTokenAddress,
            deployer
        );
        
        console.log("TwoPhasePresaleWithReferral deployed at:", address(presale));
        
        // Configure sale to start immediately
        uint256 currentTime = block.timestamp;
        uint256 whitelistDuration = 2 hours;  // 2 hours whitelisting
        uint256 presaleDuration = 2 hours;    // 2 hours presale
        uint256 publicSaleDuration = 2 hours; // 2 hours public sale
        TwoPhasePresaleWithReferral.SaleConfig memory config = TwoPhasePresaleWithReferral.SaleConfig({
            presaleStartTime: currentTime,  // Start immediately
            presaleEndTime: currentTime + presaleDuration,
            publicSaleStartTime: currentTime + presaleDuration,
            publicSaleEndTime: currentTime + presaleDuration + publicSaleDuration,
            presaleRate: 40 * 10**6,           // 40 tokens per USD ($0.025/token)
            publicSaleStartRate: 10 * 10**6,   // 10 tokens per USD ($0.10/token)
            presaleCap: 10_000_000 * 10**18,   // 10M XTSY tokens
            publicSaleCap: 30_000_000 * 10**18, // 30M XTSY tokens
            whitelistDeadline: currentTime + whitelistDuration,  // Whitelist deadline in 50 minutes
            priceIncreaseInterval: 30 minutes,  // Price increases every 30 minutes (3 days scaled)
            priceIncreaseAmount: 10000          // $0.01 increase (in 6 decimal format)
        });
        
        presale.configureSale(config);
        console.log("Immediate sale configuration applied");
        
        // Configure referral system (5% bonus for referrer)
        TwoPhasePresaleWithReferral.ReferralConfig memory referralConfig = TwoPhasePresaleWithReferral.ReferralConfig({
            referrerBonusPercent: 50,  // 5% bonus
            referralEnabled: true
        });
        presale.configureReferral(referralConfig);
        console.log("Referral system configured");
        
        // // Transfer XTSY tokens to presale contract
        // uint256 totalTokensNeeded = 40_000_000 * 10**18; // 40M XTSY (10M presale + 30M public)
        // IERC20 xtsyToken = IERC20(xtsyTokenAddress);
        
        // console.log("Transferring", totalTokensNeeded / 10**18, "XTSY tokens to presale contract...");
        // xtsyToken.transfer(address(presale), totalTokensNeeded);
        
        console.log("Deployment complete!");
        console.log("-----------------------------------");
        console.log("Whitelisting: 50 minutes from now");
        console.log("Presale: Starts immediately, lasts 50 minutes, $0.025/token, 10M tokens");
        console.log("Public Sale: After 50 minutes, lasts 1 day, $0.10+/token, 30M tokens");
        console.log("Referral bonus: 5% for referrer");
        console.log("Payment tokens: USDT and USDC");
        console.log("Sale starts immediately!");
        console.log("-----------------------------------");
        
        vm.stopBroadcast();
    }
    
    function addWhitelist(address presaleAddress, address[] memory whitelist) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        TwoPhasePresaleWithReferral presale = TwoPhasePresaleWithReferral(presaleAddress);
        presale.addBatchToWhitelist(whitelist);
        
        console.log("Added", whitelist.length, "addresses to whitelist");
        
        vm.stopBroadcast();
    }
    
    function setTGE(address presaleAddress, uint256 tgeTimestamp) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        TwoPhasePresaleWithReferral presale = TwoPhasePresaleWithReferral(presaleAddress);
        presale.setTGETimestamp(tgeTimestamp);
        
        console.log("TGE timestamp set to:", tgeTimestamp);
        
        vm.stopBroadcast();
    }
}
