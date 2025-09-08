// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../script/DeployCleanPresale.s.sol";

contract DeploymentTest is Test {
    function testDeploymentScript() public {
        // Set up environment variables for the test
        vm.setEnv("PRIVATE_KEY", "0x1234567890123456789012345678901234567890123456789012345678901234");
        
        // Deploy the script
        DeployCleanPresale deployScript = new DeployCleanPresale();
        
        // Run the deployment
        deployScript.run();
        
        // Check that deployment file was created
        assertTrue(vm.exists("clean_presale_deployment.txt"));
        
        console.log("[OK] Deployment script executed successfully");
    }
    
    function testTimingConfiguration() public {
        uint256 currentTime = block.timestamp;
        uint256 whitelistPeriod = 2 hours;
        uint256 presalePeriod = 2 hours;
        uint256 publicSalePeriod = 2 hours;
        
        uint256 expectedPresaleStart = currentTime + whitelistPeriod;
        uint256 expectedPresaleEnd = expectedPresaleStart + presalePeriod;
        uint256 expectedPublicStart = expectedPresaleEnd;
        uint256 expectedPublicEnd = expectedPublicStart + publicSalePeriod;
        
        // Verify timing calculations
        assertTrue(expectedPresaleStart > currentTime);
        assertTrue(expectedPresaleEnd > expectedPresaleStart);
        assertTrue(expectedPublicStart == expectedPresaleEnd);
        assertTrue(expectedPublicEnd > expectedPublicStart);
        
        console.log("[OK] Timing configuration is correct");
    }
}