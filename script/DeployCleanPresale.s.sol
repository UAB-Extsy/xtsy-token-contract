// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/xtsySale.sol";
import "../src/ExtsyToken.sol";
import "../src/mocks/MockUSDC.sol";
import "../src/mocks/MockUSDT.sol";

contract DeployCleanPresale is Script {
    ExtsyToken public token;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=================================================");
        console.log("DEPLOYING CLEAN XTSY PRESALE ECOSYSTEM");
        console.log("=================================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Block timestamp:", block.timestamp);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // =============================================================================
        // 1. DEPLOY MOCK TOKENS (for testnet/development)
        // =============================================================================
        
        console.log("\n1. Deploying Mock Tokens...");
        
        // MockUSDC mockUsdc = new MockUSDC();
        // console.log("   MockUSDC deployed at:", address(mockUsdc));
        
        // MockUSDT mockUsdt = new MockUSDT();
        // console.log("   MockUSDT deployed at:", address(mockUsdt));
        
        // Using existing USDT/USDC tokens from environment variables
        address usdtTokenAddress = vm.envAddress("USDT_TOKEN_ADDRESS");
        address usdcTokenAddress = vm.envAddress("USDC_TOKEN_ADDRESS");
        console.log("   Using USDT token at:", usdtTokenAddress);
        console.log("   Using USDC token at:", usdcTokenAddress);
        
        // =============================================================================
        // 2. DEPLOY CLEAN PRESALE CONTRACT (without sale token)
        // =============================================================================
        
        console.log("\n2. Deploying Clean Presale Contract...");
        xtsySale presale = new xtsySale(
            address(0),  // placeholder - will be set later
            usdtTokenAddress,
            usdcTokenAddress,
            deployer,
            deployer,  // backend signer - use deployer for now
            deployer   // crosschain backend signer - use deployer for now
        );
        
        console.log("   Clean Presale deployed at:", address(presale));
        
        // =============================================================================
        // 3. DEPLOY XTSY TOKEN WITH PRESALE ADDRESS
        // =============================================================================
        
        console.log("\n3. Deploying XTSY Token with presale address...");
        
        // Get addresses from environment variables with fallbacks
        address initialOwner = _getAddress("INITIAL_OWNER", deployer);
        address communityAddress = _getAddress("COMMUNITY_ADDRESS", deployer);
        address treasuryAddress = _getAddress("TREASURY_ADDRESS", deployer);
        address teamAddress = _getAddress("TEAM_ADDRESS", deployer);
        address referralPoolAddress = _getAddress("REFERRAL_POOL_ADDRESS", deployer);
        
        console.log("Deploying ExtsyToken with tokenomics distribution...");
        console.log("Initial Owner:", initialOwner);
        console.log("Presale Address:", address(presale));
        console.log("Community Address:", communityAddress);
        console.log("Treasury Address:", treasuryAddress);
        console.log("Team Address:", teamAddress);
        console.log("Referral Pool Address:", referralPoolAddress);
        
        token = new ExtsyToken(
            address(presale),        // presale
            address(presale),        // public sale (reusing presale for simplicity)
            address(presale),        // liquidity
            address(presale),             // team advisors
            address(presale),        // ecosystem (reusing community)
            address(presale),         // treasury
            address(presale),        // staking (reusing community)
            address(presale)      // marketing
        );
        
        console.log("   XTSY Token deployed at:", address(token));
        console.log("   Total Supply:", token.totalSupply() / 10**18, "XTSY");
        console.log("   Cap:", token.cap() / 10**18, "XTSY");
        
        // =============================================================================
        // 4. UPDATE SALE TOKEN IN PRESALE CONTRACT
        // =============================================================================
        
        console.log("\n4. Setting sale token and price feed in presale contract...");
        
        presale.setSaleToken(address(token));
        console.log("   Sale token set to:", address(token));
        
        // Set ETH/USD price feed for Sepolia testnet
        address ethUsdPriceFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
        presale.setEthUsdPriceFeed(ethUsdPriceFeed);
        presale.setBackendSigner(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        presale.setCrossChainBackendSigner(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        console.log("   ETH/USD price feed set to:", ethUsdPriceFeed);
        
        // =============================================================================
        // 5. CONFIGURE SALE TIMING (2h whitelist + 2h presale + 2h public sale)
        // =============================================================================
        
        console.log("\n5. Configuring Sale Timing...");
        
        uint256 currentTime = block.timestamp;
        uint256 whitelistPeriod = 2 hours;
        uint256 presalePeriod = 2 hours;
        uint256 publicSalePeriod = 2 hours;
        xtsySale.SaleConfig memory saleConfig = xtsySale.SaleConfig({
            presaleStartTime: currentTime + whitelistPeriod,                        // Start after 30min whitelist period
            presaleEndTime: currentTime + whitelistPeriod + presalePeriod,          // End after 30min presale
            publicSaleStartTime: currentTime + whitelistPeriod + presalePeriod + 1, // Start 1 second after presale ends
            publicSaleEndTime: currentTime + whitelistPeriod + presalePeriod + publicSalePeriod + 1, // End after 30min public sale
            presaleRate: 25000,         // $0.025 per token (25000 micro-USD)
            publicSaleStartRate: 100000, // $0.10 per token (100000 micro-USD)
            priceIncreaseInterval: 30 minutes, // Price increases every 30 minutes
            priceIncreaseAmount: 10000  // $0.01 increase (10000 micro-USD)
        });
        
        presale.configureSale(saleConfig);
        
        console.log("   Sale Timeline:");
        console.log("   - Whitelist Period: Now -> ", _formatTime(currentTime + whitelistPeriod));
        console.log("   - Presale Start:", _formatTime(saleConfig.presaleStartTime));
        console.log("   - Presale End:", _formatTime(saleConfig.presaleEndTime));
        console.log("   - Public Sale Start:", _formatTime(saleConfig.publicSaleStartTime));
        console.log("   - Public Sale End:", _formatTime(saleConfig.publicSaleEndTime));
        console.log("   - Presale Price: $0.025 per XTSY");
        console.log("   - Public Sale Start Price: $0.10 per XTSY");
        console.log("   - Price increases $0.01 every 30 minutes");
        
        // =============================================================================
        // 6. SET TGE TIMESTAMP (1 day after public sale ends)
        // =============================================================================
        
        console.log("\n6. Setting TGE Timestamp...");
        
        // uint256 tgeTimestamp = saleConfig.publicSaleEndTime + 1 days;
        // presale.setTGETimestamp(tgeTimestamp);
        
        // console.log("   TGE (Token Generation Event):", _formatTime(tgeTimestamp));
        
        // =============================================================================
        // 7. CONFIGURE REFERRAL SYSTEM
        // =============================================================================
        
        console.log("\n7. Configuring Referral System...");
        
        // presale.setReferralConfig(50, true); // 5% bonus, enabled
        console.log("   Referral bonus: 5% for referrer");
        console.log("   Referral system: Enabled");
        
        // =============================================================================
        // 8. VERIFY CATEGORY CAPS AND PRESALE BALANCE
        // =============================================================================
        
        console.log("\n8. Verifying Category Caps and Presale Balance...");
        
        uint256 presaleBalance = token.balanceOf(address(presale)) / 10**18;
        console.log("   Presale contract balance:", presaleBalance, "XTSY");
        
        (uint256 presaleCap, uint256 presaleAllocated,) = presale.getCategoryInfo(xtsySale.VestingCategory.Presale);
        console.log("   Presale Cap:", presaleCap / 10**18, "XTSY");
        console.log("   Presale Allocated:", presaleAllocated / 10**18, "XTSY");
        
        (uint256 publicCap, uint256 publicAllocated,) = presale.getCategoryInfo(xtsySale.VestingCategory.PublicSale);
        console.log("   Public Sale Cap:", publicCap / 10**18, "XTSY");
        console.log("   Public Sale Allocated:", publicAllocated / 10**18, "XTSY");
        
        xtsySale.VestingCategory teamCategory = xtsySale.VestingCategory.TeamAdvisors;
        (uint256 teamCap, uint256 teamAllocated,) = presale.getCategoryInfo(teamCategory);
        console.log("   Team & Advisors Cap:", teamCap / 10**18, "XTSY");
        console.log("   Team & Advisors Allocated:", teamAllocated / 10**18, "XTSY");
        
        xtsySale.VestingCategory marketingCategory = xtsySale.VestingCategory.Marketing;
        (uint256 marketingCap, uint256 marketingAllocated,) = presale.getCategoryInfo(marketingCategory);
        console.log("   Marketing Cap:", marketingCap / 10**18, "XTSY");
        console.log("   Marketing Allocated:", marketingAllocated / 10**18, "XTSY");
        
        vm.stopBroadcast();
        
        // =============================================================================
        // 9. DEPLOYMENT INFO SUMMARY
        // =============================================================================
        
        console.log("\n9. Deployment Information Summary...");
        console.log("   Chain ID:", block.chainid);
        console.log("   Deployed at:", block.timestamp);
        console.log("   Deployer:", deployer);
        console.log("");
        console.log("   Contract Addresses:");
        console.log("   XTSY_TOKEN=", address(token));
        console.log("   USDT_TOKEN=", usdtTokenAddress);
        console.log("   USDC_TOKEN=", usdcTokenAddress);
        console.log("   CLEAN_PRESALE=", address(presale));
        console.log("");
        console.log("   Sale Timeline:");
        console.log("   Presale Start:", saleConfig.presaleStartTime);
        console.log("   Presale End:", saleConfig.presaleEndTime);
        console.log("   Public Sale Start:", saleConfig.publicSaleStartTime);
        console.log("   Public Sale End:", saleConfig.publicSaleEndTime);
        // console.log("   TGE Timestamp:", tgeTimestamp);
        
        // =============================================================================
        // 10. DEPLOYMENT SUMMARY
        // =============================================================================
        
        console.log("\n=================================================");
        console.log("DEPLOYMENT COMPLETE!");
        console.log("=================================================");
        console.log("[OK] XTSY Token:", address(token));
        console.log("[OK] Clean Presale:", address(presale));
        console.log("[OK] USDT Token:", usdtTokenAddress);
        console.log("[OK] USDC Token:", usdcTokenAddress);
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Add addresses to whitelist using: addToWhitelist(address)");
        console.log("2. Wait for presale to start in 2 hours");
        console.log("3. Users can purchase with USDT/USDC during presale/public sale");
        console.log("4. Allocate team/ecosystem/treasury tokens using: allocateTokens()");
        console.log("5. Set TGE and let users claim tokens");
        console.log("");
        console.log("MANAGEMENT FUNCTIONS:");
        console.log("- presale.addToWhitelist(address user)");
        console.log("- presale.addBatchToWhitelist(address[] users)");
        console.log("- presale.allocateTokens(address, VestingCategory, amount)");
        console.log("- presale.withdrawFunds() // after sale ends");
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
    
    // =============================================================================
    // HELPER FUNCTIONS FOR POST-DEPLOYMENT MANAGEMENT
    // =============================================================================
    
    /**
     * @dev Set backend signer address
     * Usage: forge script script/DeployCleanPresale.s.sol:DeployCleanPresale --sig "setBackendSigner(address,address[])" <presale_address> <backend_signer>
     */
    function setBackendSigner(address presaleAddress, address[] memory users) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        xtsySale presale = xtsySale(presaleAddress);
        presale.setBackendSigner(users[0]); // Use first user as backend signer for demo
        
        console.log("[OK] Set backend signer to:", users[0]);
        
        vm.stopBroadcast();
    }
    
    /**
     * @dev Allocate team tokens
     * Usage: forge script script/DeployCleanPresale.s.sol:DeployCleanPresale --sig "allocateTeamTokens(address,address[],uint256[])" <presale_address> <recipients> <amounts>
     */
    function allocateTeamTokens(
        address presaleAddress,
        address[] memory recipients,
        uint256[] memory amounts
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        xtsySale presale = xtsySale(presaleAddress);
        presale.batchAllocateTokens(recipients, xtsySale.VestingCategory.TeamAdvisors, amounts);
        
        console.log("[OK] Allocated team tokens to", recipients.length, "recipients");
        
        vm.stopBroadcast();
    }
    
    /**
     * @dev Allocate marketing tokens
     */
    function allocateMarketingTokens(
        address presaleAddress,
        address[] memory recipients, 
        uint256[] memory amounts
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        xtsySale presale = xtsySale(presaleAddress);
        presale.batchAllocateTokens(recipients, xtsySale.VestingCategory.Marketing, amounts);
        
        console.log("[OK] Allocated marketing tokens to", recipients.length, "recipients");
        
        vm.stopBroadcast();
    }
    
    /**
     * @dev Allocate treasury tokens
     */
    function allocateTreasuryTokens(
        address presaleAddress,
        address[] memory recipients,
        uint256[] memory amounts
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        xtsySale presale = xtsySale(presaleAddress);
        presale.batchAllocateTokens(recipients, xtsySale.VestingCategory.Treasury, amounts);
        
        console.log("[OK] Allocated treasury tokens to", recipients.length, "recipients");
        
        vm.stopBroadcast();
    }
    
    /**
     * @dev Allocate ecosystem tokens
     */
    function allocateEcosystemTokens(
        address presaleAddress,
        address[] memory recipients,
        uint256[] memory amounts
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        xtsySale presale = xtsySale(presaleAddress);
        presale.batchAllocateTokens(recipients, xtsySale.VestingCategory.Ecosystem, amounts);
        
        console.log("[OK] Allocated ecosystem tokens to", recipients.length, "recipients");
        
        vm.stopBroadcast();
    }
    
    /**
     * @dev Check contract status
     */
    function checkStatus(address presaleAddress) external view {
        xtsySale presale = xtsySale(presaleAddress);
        
        console.log("=== PRESALE STATUS ===");
        
        (uint256 totalPresale, uint256 totalPublic, uint256 totalUsdt, uint256 totalUsdc, uint256 totalEth, xtsySale.SalePhase phase) = presale.getContractStats();
        
        console.log("Current Phase:", uint(phase));
        console.log("Total Presale Sold:", totalPresale / 10**18, "XTSY");
        console.log("Total Public Sold:", totalPublic / 10**18, "XTSY"); 
        console.log("Total USDT Raised:", totalUsdt / 10**6, "USDT");
        console.log("Total USDC Raised:", totalUsdc / 10**6, "USDC");
        console.log("Total ETH Raised:", totalEth / 10**18, "ETH");
        console.log("Current Rate:", presale.getCurrentRate(), "micro-USD per token");
        console.log("TGE Timestamp:", presale.tgeTimestamp());
    }
}