// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/xtsySale.sol";
import "../src/ExtsyToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployxtsySale is Script {
    function run() external {
        // Load configuration from environment variables
        address xtsyTokenAddress = vm.envAddress("XTSY_TOKEN_ADDRESS");
        address usdtTokenAddress = vm.envAddress("USDT_TOKEN_ADDRESS");
        address usdcTokenAddress = vm.envAddress("USDC_TOKEN_ADDRESS");
        address backendSigner = vm.envAddress("BACKEND_SIGNER");
        address crossChainBackendSigner = vm.envAddress("CROSSCHAIN_BACKEND_SIGNER");
        
        // Start deployment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying xtsySale contract for XTSY token...");
        console.log("Deployer:", deployer);
        console.log("XTSY Token:", xtsyTokenAddress);
        console.log("USDT Token:", usdtTokenAddress);
        console.log("USDC Token:", usdcTokenAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy presale contract
        xtsySale presale = new xtsySale(
            xtsyTokenAddress,
            usdtTokenAddress,
            usdcTokenAddress,
            deployer,
            backendSigner,
            crossChainBackendSigner
        );
        
        console.log("xtsySale deployed at:", address(presale));
        
        // Configure sale timing
        uint256 currentTime = block.timestamp;
        xtsySale.SaleConfig memory config = xtsySale.SaleConfig({
            presaleStartTime: currentTime,
            presaleEndTime: currentTime + 7 days,
            publicSaleStartTime: currentTime + 7 days,
            publicSaleEndTime: currentTime + 14 days,
            presaleRate: 100000,           // $0.10 per token (in micro-USD)
            publicSaleStartRate: 350000,   // $0.35 per token (in micro-USD)  
            priceIncreaseInterval: 518400, // 6 days in seconds
            priceIncreaseAmount: 17500     // 5% increase ($0.0175 in micro-USD)
        });
        
        presale.configureSale(config);
        console.log("Sale configuration applied");
        
        vm.stopBroadcast();
        
        console.log("Deployment complete!");
        console.log("-----------------------------------");
        console.log("Presale: 7 days, $0.10/token");
        console.log("Public Sale: Starts after presale, $0.35+/token with 5% increases every 6 days");
    }
}