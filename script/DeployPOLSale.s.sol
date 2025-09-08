// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/xtsySalePOL.sol";

contract DeployPOLSale is Script {
    xtsySalePOL public presale;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=================================================");
        console.log("DEPLOYING XTSY POLYGON/POL SALE CONTRACT");
        console.log("=================================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Block timestamp:", block.timestamp);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // =============================================================================
        // 1. GET TOKEN ADDRESSES FROM ENVIRONMENT
        // =============================================================================
        
        console.log("\n1. Getting Token Addresses...");
        
        // Using existing USDT/USDC tokens from environment variables for Polygon
        address usdtTokenAddress = _getAddress("POLYGON_USDT_TOKEN_ADDRESS", 0x03ab458634910AaD20eF5f1C8ee96F1D6ac54919); // Polygon USDT
        address usdcTokenAddress = _getAddress("POLYGON_USDC_TOKEN_ADDRESS", 0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582); // Polygon USDC
        console.log("   Using USDT token at:", usdtTokenAddress);
        console.log("   Using USDC token at:", usdcTokenAddress);
        
        // =============================================================================
        // 2. DEPLOY POL SALE CONTRACT
        // =============================================================================
        
        console.log("\n2. Deploying POL Sale Contract...");
        
        address backendSigner = _getAddress("BACKEND_SIGNER_ADDRESS", deployer);
        
        // Polygon mainnet POL/USD price feed: 0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada
        // Polygon Mumbai testnet POL/USD: 0x001382149eBa3441043c1c66972b4772963f5D43
        address polUsdPriceFeed = _getAddress("POL_USD_PRICE_FEED", 0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada);
        
        presale = new xtsySalePOL(
            usdtTokenAddress,
            usdcTokenAddress,
            polUsdPriceFeed,
            deployer,
            backendSigner
        );
        
        console.log("   POL Sale deployed at:", address(presale));
        console.log("   Backend Signer:", backendSigner);
        console.log("   POL/USD Price Feed:", polUsdPriceFeed);
        
        // =============================================================================
        // 3. CONFIGURE SALE TIMING
        // =============================================================================
        
        console.log("\n3. Configuring Sale Timing...");
        
        uint256 currentTime = block.timestamp;
        uint256 whitelistPeriod = 10 minutes;
        uint256 presalePeriod = 2 hours;
        uint256 publicSalePeriod = 2 hours;
        
        xtsySalePOL.SaleConfig memory saleConfig = xtsySalePOL.SaleConfig({
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
        console.log("   Network: Polygon/POL");
        console.log("   Deployed at:", block.timestamp);
        console.log("   Deployer:", deployer);
        console.log("");
        console.log("   Contract Addresses:");
        console.log("   POL_SALE=", address(presale));
        console.log("   USDT_TOKEN=", usdtTokenAddress);
        console.log("   USDC_TOKEN=", usdcTokenAddress);
        console.log("   POL_USD_FEED=", polUsdPriceFeed);
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
        console.log("POL SALE DEPLOYMENT COMPLETE!");
        console.log("=================================================");
        console.log("[OK] POL Sale Contract:", address(presale));
        console.log("[OK] USDT Token:", usdtTokenAddress);
        console.log("[OK] USDC Token:", usdcTokenAddress);
        console.log("[OK] POL/USD Feed:", polUsdPriceFeed);
        console.log("[OK] Backend Signer:", backendSigner);
        console.log("");
        console.log("CONTRACT FUNCTIONALITY:");
        console.log("- Tracks purchase amounts only");
        console.log("- No token allocation or vesting");
        console.log("- Backend handles token distribution on Ethereum");
        console.log("");
        console.log("SUPPORTED PAYMENT METHODS:");
        console.log("- POL (native token)");
        console.log("- USDT on Polygon");
        console.log("- USDC on Polygon");
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Add addresses to whitelist using: addToWhitelist(address)");
        console.log("2. Wait for presale to start in 10 minutes");
        console.log("3. Users can purchase with POL/USDT/USDC (purchases recorded only)");
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