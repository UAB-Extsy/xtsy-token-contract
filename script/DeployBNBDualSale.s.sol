// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/xtsySaleBNB.sol";

contract DeployBNBDualSale is Script {
    xtsySaleBNB public presaleContract;
    xtsySaleBNB public publicSaleContract;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=================================================");
        console.log("DEPLOYING DUAL XTSY BNB SALE CONTRACTS");
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
        
        address backendSigner = _getAddress("BACKEND_SIGNER_ADDRESS", deployer);
        // BSC testnet BNB/USD price feed: 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
        address bnbUsdPriceFeed = _getAddress("BNB_USD_PRICE_FEED", 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526);
        
        // =============================================================================
        // 2. DEPLOY PRESALE ACTIVE CONTRACT (2 DAYS)
        // =============================================================================
        
        console.log("\n2. Deploying BNB Presale Active Contract...");
        
        presaleContract = new xtsySaleBNB(
            usdtTokenAddress,
            usdcTokenAddress,
            bnbUsdPriceFeed,
            deployer,
            backendSigner
        );
        
        console.log("   BNB Presale Contract deployed at:", address(presaleContract));
        
        // Configure presale timing (presale active for 2 days)
        uint256 currentTime = block.timestamp;
        uint256 presaleDuration = 2 days; // 2 days presale period
        uint256 publicSaleDuration = 30 days; // 30 days public sale period
        
        xtsySaleBNB.SaleConfig memory presaleConfig = xtsySaleBNB.SaleConfig({
            presaleStartTime: currentTime, // Start presale immediately
            presaleEndTime: currentTime + presaleDuration, // End after 2 days
            publicSaleStartTime: currentTime + presaleDuration + 1 seconds, // Start 1 second after presale ends
            publicSaleEndTime: currentTime + presaleDuration + publicSaleDuration, // End after 30 days public sale
            presaleRate: 100000,         // $0.10 per token (100000 micro-USD)
            publicSaleStartRate: 350000, // $0.35 per token (350000 micro-USD)
            priceIncreaseInterval: 6 days, // Price increases every 6 days
            priceIncreaseAmount: 17500   // 5% increase (17500 micro-USD = $0.0175)
        });
        
        presaleContract.configureSale(presaleConfig);
        presaleContract.setReferralConfig(50, true); // 5% bonus, enabled
        
        console.log("   [OK] PRESALE IS ACTIVE NOW - Runs for 2 days");
        console.log("   Presale Price: $0.10 per XTSY");
        
        // =============================================================================
        // 3. DEPLOY PUBLIC SALE ACTIVE CONTRACT (30 DAYS)
        // =============================================================================
        
        console.log("\n3. Deploying BNB Public Sale Active Contract...");
        
        publicSaleContract = new xtsySaleBNB(
            usdtTokenAddress,
            usdcTokenAddress,
            bnbUsdPriceFeed,
            deployer,
            backendSigner
        );
        
        console.log("   BNB Public Sale Contract deployed at:", address(publicSaleContract));
        
        // Configure public sale timing (public sale active for 30 days with price changes)
        uint256 publicSaleDuration30Days = 30 days; // 30 days public sale period
        
        xtsySaleBNB.SaleConfig memory publicSaleConfig = xtsySaleBNB.SaleConfig({
            presaleStartTime: currentTime - 1 days, // Presale already ended (set to past)
            presaleEndTime: currentTime - 1 seconds, // Presale already ended
            publicSaleStartTime: currentTime, // Start public sale immediately
            publicSaleEndTime: currentTime + publicSaleDuration30Days, // End after 30 days
            presaleRate: 100000,         // $0.10 per token (not used since presale ended)
            publicSaleStartRate: 350000, // $0.35 per token (350000 micro-USD)
            priceIncreaseInterval: 6 days, // Price increases every 6 days (5 price increases in 30 days)
            priceIncreaseAmount: 17500   // 5% increase (17500 micro-USD = $0.0175)
        });
        
        publicSaleContract.configureSale(publicSaleConfig);
        publicSaleContract.setReferralConfig(50, true); // 5% bonus, enabled
        
        console.log("   [OK] PUBLIC SALE IS ACTIVE NOW - Runs for 30 days");
        console.log("   Starting Price: $0.35 per XTSY");
        console.log("   Price increases 5% every 6 days");
        
        vm.stopBroadcast();
        
        // =============================================================================
        // 4. DEPLOYMENT SUMMARY
        // =============================================================================
        
        console.log("\n=================================================");
        console.log("DUAL BNB SALE DEPLOYMENT COMPLETE!");
        console.log("=================================================");
        console.log("");
        console.log("CONTRACT 1: PRESALE ACTIVE");
        console.log("  Address:", address(presaleContract));
        console.log("  Status: [OK] PRESALE ACTIVE (2 days)");
        console.log("  Price: $0.10 per XTSY");
        console.log("  Duration: 2 days from now");
        console.log("");
        console.log("CONTRACT 2: PUBLIC SALE ACTIVE");
        console.log("  Address:", address(publicSaleContract));
        console.log("  Status: [OK] PUBLIC SALE ACTIVE (30 days)");
        console.log("  Starting Price: $0.35 per XTSY");
        console.log("  Price Increases: 5% every 6 days");
        console.log("  Duration: 30 days from now");
        console.log("");
        console.log("SHARED CONFIGURATION:");
        console.log("  USDT Token:", usdtTokenAddress);
        console.log("  USDC Token:", usdcTokenAddress);
        console.log("  BNB/USD Feed:", bnbUsdPriceFeed);
        console.log("  Backend Signer:", backendSigner);
        console.log("  Chain ID:", block.chainid);
        console.log("  Network: BNB Chain Testnet");
        console.log("");
        console.log("SUPPORTED PAYMENT METHODS:");
        console.log("- BNB (native token)");
        console.log("- USDT on BNB Chain");
        console.log("- USDC on BNB Chain");
        console.log("");
        console.log("PRICE PROGRESSION (Public Sale Contract):");
        console.log("Day 0-6:   $0.35 per XTSY");
        console.log("Day 6-12:  $0.3675 per XTSY (+5%)");
        console.log("Day 12-18: $0.3859 per XTSY (+5%)");
        console.log("Day 18-24: $0.4052 per XTSY (+5%)");
        console.log("Day 24-30: $0.4255 per XTSY (+5%)");
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Add addresses to whitelist on both contracts");
        console.log("2. Users can purchase immediately on both contracts");
        console.log("3. Backend will handle token distribution based on purchase records");
        console.log("=================================================");
        
        // Output environment variables for easy copy-paste
        console.log("\nENVIRONMENT VARIABLES:");
        console.log("export BNB_PRESALE_CONTRACT=", address(presaleContract));
        console.log("export BNB_PUBLIC_SALE_CONTRACT=", address(publicSaleContract));
        console.log("export BSC_TESTNET_USDT=", usdtTokenAddress);
        console.log("export BSC_TESTNET_USDC=", usdcTokenAddress);
        console.log("export BNB_USD_PRICEFEED=", bnbUsdPriceFeed);
        
        console.log("\nTO VERIFY CONTRACTS:");
        console.log("forge verify-contract --chain-id", block.chainid, "\\");
        console.log("  ", address(presaleContract), "\\");
        console.log("  src/xtsySaleBNB.sol:xtsySaleBNB \\");
        console.log("  --constructor-args $(cast abi-encode \"constructor(address,address,address,address,address)\" \\");
        console.log("    ", usdtTokenAddress, "\\");
        console.log("    ", usdcTokenAddress, "\\"); 
        console.log("    ", bnbUsdPriceFeed, "\\");
        console.log("    ", deployer, "\\");
        console.log("    ", backendSigner, ")");
        console.log("");
        console.log("forge verify-contract --chain-id", block.chainid, "\\");
        console.log("  ", address(publicSaleContract), "\\");
        console.log("  src/xtsySaleBNB.sol:xtsySaleBNB \\");
        console.log("  --constructor-args $(cast abi-encode \"constructor(address,address,address,address,address)\" \\");
        console.log("    ", usdtTokenAddress, "\\");
        console.log("    ", usdcTokenAddress, "\\");
        console.log("    ", bnbUsdPriceFeed, "\\");
        console.log("    ", deployer, "\\");
        console.log("    ", backendSigner, ")");
    }
    
    /**
     * @dev Verify both deployed contracts
     * Usage: forge script script/DeployBNBDualSale.s.sol:DeployBNBDualSale --sig "verifyContracts(address,address)" <presale_contract> <public_sale_contract>
     */
    function verifyContracts(address presaleContractAddr, address publicSaleContractAddr) external {
        // Get the same addresses used during deployment
        address usdtTokenAddress = _getAddress("BSC_TESTNET_USDT_TOKEN_ADDRESS", 0x337610d27c682E347C9cD60BD4b3b107C9d34dDd);
        address usdcTokenAddress = _getAddress("BSC_TESTNET_USDC_TOKEN_ADDRESS", 0x64544969ed7EBf5f083679233325356EbE738930);
        address bnbUsdPriceFeed = _getAddress("BNB_USD_PRICE_FEED", 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526);
        address deployer = msg.sender; // or get from env
        address backendSigner = _getAddress("BACKEND_SIGNER_ADDRESS", deployer);
        
        console.log("=== VERIFYING CONTRACTS ===");
        console.log("Chain ID:", block.chainid);
        console.log("Presale Contract:", presaleContractAddr);
        console.log("Public Sale Contract:", publicSaleContractAddr);
        
        // Verify presale contract
        string[] memory presaleCmd = new string[](9);
        presaleCmd[0] = "forge";
        presaleCmd[1] = "verify-contract";
        presaleCmd[2] = "--chain-id";
        presaleCmd[3] = vm.toString(block.chainid);
        presaleCmd[4] = vm.toString(presaleContractAddr);
        presaleCmd[5] = "src/xtsySaleBNB.sol:xtsySaleBNB";
        presaleCmd[6] = "--constructor-args";
        presaleCmd[7] = vm.toString(
            abi.encode(usdtTokenAddress, usdcTokenAddress, bnbUsdPriceFeed, deployer, backendSigner)
        );
        presaleCmd[8] = "--watch";
        
        console.log("Verifying Presale Contract...");
        vm.ffi(presaleCmd);
        console.log("[OK] Presale Contract Verified");
        
        // Verify public sale contract  
        string[] memory publicCmd = new string[](9);
        publicCmd[0] = "forge";
        publicCmd[1] = "verify-contract";
        publicCmd[2] = "--chain-id";
        publicCmd[3] = vm.toString(block.chainid);
        publicCmd[4] = vm.toString(publicSaleContractAddr);
        publicCmd[5] = "src/xtsySaleBNB.sol:xtsySaleBNB";
        publicCmd[6] = "--constructor-args";
        publicCmd[7] = vm.toString(
            abi.encode(usdtTokenAddress, usdcTokenAddress, bnbUsdPriceFeed, deployer, backendSigner)
        );
        publicCmd[8] = "--watch";
        
        console.log("Verifying Public Sale Contract...");
        vm.ffi(publicCmd);
        console.log("[OK] Public Sale Contract Verified");
        
        console.log("=== VERIFICATION COMPLETE ===");
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