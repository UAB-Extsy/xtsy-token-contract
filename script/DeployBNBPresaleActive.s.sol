// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/xtsySaleBNB.sol";

contract DeployBNBPresaleActive is Script {
    xtsySaleBNB public presale;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=================================================");
        console.log("DEPLOYING XTSY BNB PRESALE ACTIVE CONTRACT");
        console.log("=================================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Block timestamp:", block.timestamp);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // =============================================================================
        // 1. GET TOKEN ADDRESSES FROM ENVIRONMENT
        // =============================================================================
        
        console.log("\n1. Getting Token Addresses...");
        
        // Using BNB Chain testnet token addresses
        address usdtTokenAddress = _getAddress("BSC_TESTNET_USDT_TOKEN_ADDRESS", 0x337610d27c682E347C9cD60BD4b3b107C9d34dDd); // BSC Testnet USDT
        address usdcTokenAddress = _getAddress("BSC_TESTNET_USDC_TOKEN_ADDRESS", 0x64544969ed7EBf5f083679233325356EbE738930); // BSC Testnet USDC
        console.log("   Using USDT token at:", usdtTokenAddress);
        console.log("   Using USDC token at:", usdcTokenAddress);
        
        // =============================================================================
        // 2. DEPLOY BNB PRESALE ACTIVE CONTRACT
        // =============================================================================
        
        console.log("\n2. Deploying BNB Presale Active Contract...");
        
        address backendSigner = _getAddress("BACKEND_SIGNER_ADDRESS", deployer);
        
        // BSC testnet BNB/USD price feed: 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
        address bnbUsdPriceFeed = _getAddress("BNB_USD_PRICE_FEED", 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526);
        
        presale = new xtsySaleBNB(
            usdtTokenAddress,
            usdcTokenAddress,
            bnbUsdPriceFeed,
            deployer,
            backendSigner
        );
        
        console.log("   BNB Presale Active deployed at:", address(presale));
        console.log("   Backend Signer:", backendSigner);
        console.log("   BNB/USD Price Feed:", bnbUsdPriceFeed);
        
        // =============================================================================
        // 3. CONFIGURE PRESALE TIMING (PRESALE ACTIVE FOR 2 DAYS)
        // =============================================================================
        
        console.log("\n3. Configuring Presale Timing...");
        
        uint256 currentTime = block.timestamp;
        uint256 presaleDuration = 2 days; // 2 days presale period
        uint256 publicSaleDuration = 30 days; // 30 days public sale period
        
        xtsySaleBNB.SaleConfig memory saleConfig = xtsySaleBNB.SaleConfig({
            presaleStartTime: currentTime, // Start presale immediately
            presaleEndTime: currentTime + presaleDuration, // End after 2 days
            publicSaleStartTime: currentTime + presaleDuration + 1 seconds, // Start 1 second after presale ends
            publicSaleEndTime: currentTime + presaleDuration + publicSaleDuration, // End after 30 days public sale
            presaleRate: 100000,         // $0.10 per token (100000 micro-USD)
            publicSaleStartRate: 350000, // $0.35 per token (350000 micro-USD)
            priceIncreaseInterval: 6 days, // Price increases every 6 days
            priceIncreaseAmount: 17500   // 5% increase (17500 micro-USD = $0.0175)
        });
        
        presale.configureSale(saleConfig);
        
        console.log("   Sale Timeline:");
        console.log("   - Presale Start: NOW (", _formatTime(saleConfig.presaleStartTime), ")");
        console.log("   - Presale End:", _formatTime(saleConfig.presaleEndTime));
        console.log("   - Public Sale Start:", _formatTime(saleConfig.publicSaleStartTime));
        console.log("   - Public Sale End:", _formatTime(saleConfig.publicSaleEndTime));
        console.log("   - Presale Price: $0.10 per XTSY");
        console.log("   - Public Sale Start Price: $0.35 per XTSY");
        console.log("   - Price increases 5% every 6 days");
        
        // =============================================================================
        // 4. CONFIGURE REFERRAL SYSTEM
        // =============================================================================
        
        console.log("\n4. Configuring Referral System...");
        
        presale.setReferralConfig(50, true); // 5% bonus, enabled
        console.log("   Referral bonus tracking: 5%");
        console.log("   Referral system: Enabled");
        
        vm.stopBroadcast();
        
        // =============================================================================
        // 5. DEPLOYMENT INFO SUMMARY
        // =============================================================================
        
        console.log("\n5. Deployment Information Summary...");
        console.log("   Chain ID:", block.chainid);
        console.log("   Network: BNB Chain Testnet");
        console.log("   Deployed at:", block.timestamp);
        console.log("   Deployer:", deployer);
        console.log("");
        console.log("   Contract Addresses:");
        console.log("   BNB_PRESALE_ACTIVE=", address(presale));
        console.log("   USDT_TOKEN=", usdtTokenAddress);
        console.log("   USDC_TOKEN=", usdcTokenAddress);
        console.log("   BNB_USD_FEED=", bnbUsdPriceFeed);
        console.log("");
        console.log("   Sale Timeline:");
        console.log("   Presale Start:", saleConfig.presaleStartTime);
        console.log("   Presale End:", saleConfig.presaleEndTime);
        console.log("   Public Sale Start:", saleConfig.publicSaleStartTime);
        console.log("   Public Sale End:", saleConfig.publicSaleEndTime);
        
        // =============================================================================
        // 6. DEPLOYMENT SUMMARY
        // =============================================================================
        
        console.log("\n=================================================");
        console.log("BNB PRESALE ACTIVE DEPLOYMENT COMPLETE!");
        console.log("=================================================");
        console.log("[OK] BNB Presale Active Contract:", address(presale));
        console.log("[OK] USDT Token:", usdtTokenAddress);
        console.log("[OK] USDC Token:", usdcTokenAddress);
        console.log("[OK] BNB/USD Feed:", bnbUsdPriceFeed);
        console.log("[OK] Backend Signer:", backendSigner);
        console.log("");
        console.log("CONTRACT FUNCTIONALITY:");
        console.log("- PRESALE IS CURRENTLY ACTIVE!");
        console.log("- Presale runs for 2 days from deployment");
        console.log("- Tracks purchase amounts only");
        console.log("- No token allocation or vesting");
        console.log("- Backend handles token distribution on Ethereum");
        console.log("");
        console.log("SUPPORTED PAYMENT METHODS:");
        console.log("- BNB (native token)");
        console.log("- USDT on BNB Chain");
        console.log("- USDC on BNB Chain");
        console.log("");
        console.log("CURRENT STATUS:");
        console.log("[ACTIVE] PRESALE IS ACTIVE - Users can purchase immediately!");
        console.log("Presale Duration: 2 days");
        console.log("Presale Price: $0.10 per XTSY");
        console.log("Public Sale Price: $0.35+ per XTSY");
        console.log("Price increases 5% every 6 days during public sale");
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Add addresses to whitelist using: addToWhitelist(address)");
        console.log("2. Users can purchase with BNB/USDT/USDC immediately!");
        console.log("3. Backend will handle token distribution based on purchase records");
        console.log("=================================================");
    }
    
    function _formatTime(uint256 timestamp) private pure returns (string memory) {
        return string.concat("t+", vm.toString(timestamp));
    }
    
    function _getAddress(string memory envVar, address defaultAddr) private view returns (address) {
        try vm.envAddress(envVar) returns (address addr) {
            return addr;
        } catch {
            return defaultAddr;
        }
    }
}