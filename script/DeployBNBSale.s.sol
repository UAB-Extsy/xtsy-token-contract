// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/xtsySaleBNB.sol";

contract DeployBNBSale is Script {
    xtsySaleBNB public presale;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=================================================");
        console.log("DEPLOYING XTSY BNB CHAIN SALE CONTRACT");
        console.log("=================================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Block timestamp:", block.timestamp);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // =============================================================================
        // 1. GET TOKEN ADDRESSES FROM ENVIRONMENT
        // =============================================================================
        
        console.log("\n1. Getting Token Addresses...");
        
        // Using existing USDT/USDC tokens from environment variables for BNB Chain
        address usdtTokenAddress = _getAddress("BSC_USDT_TOKEN_ADDRESS", 0x55d398326f99059fF775485246999027B3197955); // BSC USDT
        address usdcTokenAddress = _getAddress("BSC_USDC_TOKEN_ADDRESS", 0x8965349fb649A33a30cbFDa057D8eC2C48AbE2A2); // BSC USDC
        console.log("   Using USDT token at:", usdtTokenAddress);
        console.log("   Using USDC token at:", usdcTokenAddress);
        
        // =============================================================================
        // 2. DEPLOY BNB SALE CONTRACT
        // =============================================================================
        
        console.log("\n2. Deploying BNB Sale Contract...");
        
        address backendSigner = _getAddress("BACKEND_SIGNER_ADDRESS", deployer);
        
        // BSC mainnet BNB/USD price feed: 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE
        // BSC testnet BNB/USD: 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
        address bnbUsdPriceFeed = _getAddress("BNB_USD_PRICE_FEED", 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE);
        
        presale = new xtsySaleBNB(
            usdtTokenAddress,
            usdcTokenAddress,
            bnbUsdPriceFeed,
            deployer,
            backendSigner
        );
        
        console.log("   BNB Sale deployed at:", address(presale));
        console.log("   Backend Signer:", backendSigner);
        console.log("   BNB/USD Price Feed:", bnbUsdPriceFeed);
        
        // =============================================================================
        // 3. CONFIGURE SALE TIMING
        // =============================================================================
        
        console.log("\n3. Configuring Sale Timing...");
        
        uint256 currentTime = block.timestamp;
        uint256 whitelistPeriod = 10 minutes;
        uint256 presalePeriod = 2 hours;
        uint256 publicSalePeriod = 2 hours;
        
        xtsySaleBNB.SaleConfig memory saleConfig = xtsySaleBNB.SaleConfig({
            presaleStartTime: currentTime + whitelistPeriod,
            presaleEndTime: currentTime + whitelistPeriod + presalePeriod,
            publicSaleStartTime: currentTime + whitelistPeriod + presalePeriod + 1 seconds,
            publicSaleEndTime: currentTime + whitelistPeriod + presalePeriod + publicSalePeriod,
            presaleRate: 100000,         // $0.10 per token (100000 micro-USD)
            publicSaleStartRate: 350000, // $0.35 per token (350000 micro-USD)
            priceIncreaseInterval: 6 days,
            priceIncreaseAmount: 17500   // 5% increase (17500 micro-USD = $0.0175)
        });
        
        presale.configureSale(saleConfig);
        
        console.log("   Sale Timeline:");
        console.log("   - Whitelist Period: Now -> ", _formatTime(currentTime + whitelistPeriod));
        console.log("   - Presale Start:", _formatTime(saleConfig.presaleStartTime));
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
        console.log("   Network: BNB Chain");
        console.log("   Deployed at:", block.timestamp);
        console.log("   Deployer:", deployer);
        console.log("");
        console.log("   Contract Addresses:");
        console.log("   BNB_SALE=", address(presale));
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
        console.log("BNB SALE DEPLOYMENT COMPLETE!");
        console.log("=================================================");
        console.log("[OK] BNB Sale Contract:", address(presale));
        console.log("[OK] USDT Token:", usdtTokenAddress);
        console.log("[OK] USDC Token:", usdcTokenAddress);
        console.log("[OK] BNB/USD Feed:", bnbUsdPriceFeed);
        console.log("[OK] Backend Signer:", backendSigner);
        console.log("");
        console.log("CONTRACT FUNCTIONALITY:");
        console.log("- Tracks purchase amounts only");
        console.log("- No token allocation or vesting");
        console.log("- Backend handles token distribution on Ethereum");
        console.log("");
        console.log("SUPPORTED PAYMENT METHODS:");
        console.log("- BNB (native token)");
        console.log("- USDT on BNB Chain");
        console.log("- USDC on BNB Chain");
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Add addresses to whitelist using: addToWhitelist(address)");
        console.log("2. Wait for presale to start in 10 minutes");
        console.log("3. Users can purchase with BNB/USDT/USDC (purchases recorded only)");
        console.log("4. Backend will handle token distribution based on purchase records");
        console.log("");
        console.log("Available contract functions:");
        console.log("- Direct contract interaction required for management");
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