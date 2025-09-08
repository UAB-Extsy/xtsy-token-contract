// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ExtsyToken.sol";

/**
 * @title TokenomicsDistributionTest
 * @dev Test suite to verify proper token distribution according to whitepaper v0.2
 */
contract TokenomicsDistributionTest is Test {
    ExtsyToken public xtsyToken;
    
    address public owner = address(1);
    address public presaleContract = address(2);
    address public communityWallet = address(3);
    address public treasuryWallet = address(4);
    address public teamWallet = address(5);
    address public referralPool = address(6);
    
    uint256 public constant TOTAL_SUPPLY = 500_000_000 * 10**18;
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy token with proper allocations
        xtsyToken = new ExtsyToken(
            owner,
            presaleContract,     // presale
            presaleContract,     // public sale (reusing presale)
            communityWallet,     // liquidity
            teamWallet,          // team advisors
            communityWallet,     // ecosystem (reusing community)
            treasuryWallet,      // treasury
            communityWallet,     // staking (reusing community)
            referralPool         // marketing
        );
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test that total supply is correctly minted
     */
    function testTotalSupplyMinted() public {
        assertEq(xtsyToken.totalSupply(), TOTAL_SUPPLY, "Total supply should be 500M XTSY");
        assertEq(xtsyToken.MAX_SUPPLY(), TOTAL_SUPPLY, "Max supply should be 500M XTSY");
    }
    
    /**
     * @dev Test presale allocation (20% = 100M XTSY)
     */
    function testPresaleAllocation() public {
        // Presale contract gets presale(2%) + publicSale(6%) = 8% total
        uint256 expectedPresale = (TOTAL_SUPPLY * 8) / 100; // 40M XTSY (2% presale + 6% public)
        assertEq(xtsyToken.balanceOf(presaleContract), expectedPresale);
        
        // Verify percentage
        uint256 percentage = (xtsyToken.balanceOf(presaleContract) * 100) / TOTAL_SUPPLY;
        assertEq(percentage, 8, "Presale contract should have 8% of total supply");
    }
    
    /**
     * @dev Test community allocation (40% = 200M XTSY)
     */
    function testCommunityAllocation() public {
        // Community wallet gets liquidity(7%) + ecosystem(20%) + staking(15%) = 42%
        uint256 expectedCommunity = (TOTAL_SUPPLY * 42) / 100; // 210M XTSY
        assertEq(xtsyToken.balanceOf(communityWallet), expectedCommunity);
        
        // Verify percentage
        uint256 percentage = (xtsyToken.balanceOf(communityWallet) * 100) / TOTAL_SUPPLY;
        assertEq(percentage, 42, "Community should have 42% of total supply");
    }
    
    /**
     * @dev Test treasury allocation (20% = 100M XTSY)
     */
    function testTreasuryAllocation() public {
        uint256 expectedTreasury = (TOTAL_SUPPLY * 25) / 100; // 125M XTSY
        assertEq(xtsyToken.balanceOf(treasuryWallet), expectedTreasury);
        
        // Verify percentage
        uint256 percentage = (xtsyToken.balanceOf(treasuryWallet) * 100) / TOTAL_SUPPLY;
        assertEq(percentage, 25, "Treasury should have 25% of total supply");
    }
    
    /**
     * @dev Test team allocation (15% = 75M XTSY)
     */
    function testTeamAllocation() public {
        uint256 expectedTeam = (TOTAL_SUPPLY * 15) / 100; // 75M XTSY
        assertEq(xtsyToken.balanceOf(teamWallet), expectedTeam);
        
        // Verify percentage
        uint256 percentage = (xtsyToken.balanceOf(teamWallet) * 100) / TOTAL_SUPPLY;
        assertEq(percentage, 15, "Team should have 15% of total supply");
    }
    
    /**
     * @dev Test referral pool allocation (5% = 25M XTSY)
     */
    function testReferralPoolAllocation() public {
        uint256 expectedReferral = (TOTAL_SUPPLY * 10) / 100; // 50M XTSY (10% marketing allocation)
        assertEq(xtsyToken.balanceOf(referralPool), expectedReferral);
        
        // Verify percentage
        uint256 percentage = (xtsyToken.balanceOf(referralPool) * 100) / TOTAL_SUPPLY;
        assertEq(percentage, 10, "Referral pool should have 10% of total supply");
    }
    
    /**
     * @dev Test that all allocations sum to total supply
     */
    function testAllAllocationsSumToTotalSupply() public {
        uint256 totalAllocated = xtsyToken.balanceOf(presaleContract) +
                                xtsyToken.balanceOf(communityWallet) +
                                xtsyToken.balanceOf(treasuryWallet) +
                                xtsyToken.balanceOf(teamWallet) +
                                xtsyToken.balanceOf(referralPool);
        
        assertEq(totalAllocated, TOTAL_SUPPLY, "All allocations should sum to total supply");
    }
    
    /**
     * @dev Test that owner has no tokens
     */
    function testOwnerHasNoTokens() public {
        assertEq(xtsyToken.balanceOf(owner), 0, "Owner should not have any tokens");
    }
    
    /**
     * @dev Test allocation addresses are set correctly
     */
    function testAllocationAddressesSet() public {
        assertEq(xtsyToken.presaleAddress(), presaleContract);
        assertEq(xtsyToken.liquidityAddress(), communityWallet);
        assertEq(xtsyToken.treasuryAddress(), treasuryWallet);
        assertEq(xtsyToken.teamAdvisorsAddress(), teamWallet);
        assertEq(xtsyToken.marketingAddress(), referralPool);
    }
    
    /**
     * @dev Test that constructor reverts with zero addresses
     */
    function testConstructorRevertsWithZeroAddresses() public {
        // Test zero presale address
        vm.expectRevert("Invalid presale address");
        new ExtsyToken(owner, address(0), communityWallet, communityWallet, teamWallet, communityWallet, treasuryWallet, communityWallet, referralPool);
        
        // Test zero community address
        vm.expectRevert("Invalid liquidity address");
        new ExtsyToken(owner, presaleContract, presaleContract, address(0), teamWallet, communityWallet, treasuryWallet, communityWallet, referralPool);
        
        // Test zero treasury address
        vm.expectRevert("Invalid treasury address");
        new ExtsyToken(owner, presaleContract, presaleContract, communityWallet, teamWallet, communityWallet, address(0), communityWallet, referralPool);
        
        // Test zero team address
        vm.expectRevert("Invalid team/advisors address");
        new ExtsyToken(owner, presaleContract, presaleContract, communityWallet, address(0), communityWallet, treasuryWallet, communityWallet, referralPool);
        
        // Test zero referral pool address
        vm.expectRevert("Invalid marketing address");
        new ExtsyToken(owner, presaleContract, presaleContract, communityWallet, teamWallet, communityWallet, treasuryWallet, communityWallet, address(0));
    }
}