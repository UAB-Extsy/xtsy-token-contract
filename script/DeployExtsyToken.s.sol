// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ExtsyToken} from "../src/ExtsyToken.sol";

contract DeployExtsyToken is Script {
    ExtsyToken public token;
    
    function setUp() public {}

    function run() public returns (ExtsyToken) {
        // Get deployer address
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        
        // Get addresses from environment variables with fallbacks
        address initialOwner = _getAddress("INITIAL_OWNER", deployer);
        address presaleAddress = _getAddress("PRESALE_ADDRESS", deployer);
        address communityAddress = _getAddress("COMMUNITY_ADDRESS", deployer);
        address treasuryAddress = _getAddress("TREASURY_ADDRESS", deployer);
        address teamAddress = _getAddress("TEAM_ADDRESS", deployer);
        address referralPoolAddress = _getAddress("REFERRAL_POOL_ADDRESS", deployer);
        
        console2.log("Deploying ExtsyToken with tokenomics distribution...");
        console2.log("Deployer:", deployer);
        console2.log("Initial Owner:", initialOwner);
        console2.log("Presale Address:", presaleAddress);
        console2.log("Community Address:", communityAddress);
        console2.log("Treasury Address:", treasuryAddress);
        console2.log("Team Address:", teamAddress);
        console2.log("Referral Pool Address:", referralPoolAddress);
        
        vm.startBroadcast();
        
        token = new ExtsyToken(
            presaleAddress,       // presale
            presaleAddress,       // public sale (reusing presale for simplicity)
            communityAddress,     // liquidity
            teamAddress,          // team advisors
            communityAddress,     // ecosystem (reusing community)
            treasuryAddress,      // treasury
            communityAddress,     // staking (reusing community)
            referralPoolAddress   // marketing
        );
        
        vm.stopBroadcast();
        
        console2.log("\n=== ExtsyToken Deployed Successfully ===");
        console2.log("Token Address:", address(token));
        console2.log("Token name:", token.name());
        console2.log("Token symbol:", token.symbol());
        console2.log("Token decimals:", token.decimals());
        console2.log("Total Supply:", token.totalSupply() / 10**18, "XTSY");
        console2.log("Token deployed by:", deployer);
        
        console2.log("\n=== Token Distribution ===");
        console2.log("Presale (20%):", token.balanceOf(presaleAddress) / 10**18, "XTSY");
        console2.log("Community (40%):", token.balanceOf(communityAddress) / 10**18, "XTSY");
        console2.log("Treasury (20%):", token.balanceOf(treasuryAddress) / 10**18, "XTSY");
        console2.log("Team (15%):", token.balanceOf(teamAddress) / 10**18, "XTSY");
        console2.log("Referral Pool (5%):", token.balanceOf(referralPoolAddress) / 10**18, "XTSY");
        
        return token;
    }
    
    // Helper function for testing deployment locally with test addresses
    function runLocal() public returns (ExtsyToken) {
        address deployer = msg.sender;
        
        // Use different addresses for testing
        address presaleAddress = address(0x1000);
        address communityAddress = address(0x2000);
        address treasuryAddress = address(0x3000);
        address teamAddress = address(0x4000);
        address referralPoolAddress = address(0x5000);
        
        console2.log("Deploying ExtsyToken locally for testing...");
        
        vm.startBroadcast();
        
        token = new ExtsyToken(
            presaleAddress,       // presale
            presaleAddress,       // public sale (reusing presale for simplicity)
            communityAddress,     // liquidity
            teamAddress,          // team advisors
            communityAddress,     // ecosystem (reusing community)
            treasuryAddress,      // treasury
            communityAddress,     // staking (reusing community)
            referralPoolAddress   // marketing
        );
        
        vm.stopBroadcast();
        
        console2.log("ExtsyToken deployed locally at:", address(token));
        console2.log("Presale allocation:", token.balanceOf(presaleAddress) / 10**18, "XTSY");
        console2.log("Community allocation:", token.balanceOf(communityAddress) / 10**18, "XTSY");
        console2.log("Treasury allocation:", token.balanceOf(treasuryAddress) / 10**18, "XTSY");
        console2.log("Team allocation:", token.balanceOf(teamAddress) / 10**18, "XTSY");
        console2.log("Referral pool allocation:", token.balanceOf(referralPoolAddress) / 10**18, "XTSY");
        
        return token;
    }
    
    // Helper function to get address from environment with fallback
    function _getAddress(string memory envKey, address fallbackAddress) private view returns (address) {
        try vm.envAddress(envKey) returns (address addr) {
            return addr;
        } catch {
            console2.log(string.concat(envKey, " not set, using fallback"));
            return fallbackAddress;
        }
    }
}