// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/xtsySale.sol";
import "../src/ExtsyToken.sol";
import {MockUSDT} from "./mocks/MockUSDT.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

contract CleanPresaleTest is Test {
    xtsySale public presale;
    ExtsyToken public xtsyToken;
    MockUSDT public usdtToken;
    MockUSDC public usdcToken;
    
    // Private key for owner (used for signing)
    uint256 ownerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public owner = vm.addr(ownerPrivateKey);
    address public alice = address(2);
    address public bob = address(3);
    address public charlie = address(4);
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy tokens
        usdtToken = new MockUSDT();
        usdcToken = new MockUSDC();
        
        xtsyToken = new ExtsyToken(
            owner, owner, owner, owner, owner, owner, owner, owner, owner
        );
        
        // Deploy clean presale
        presale = new xtsySale(
            address(xtsyToken),
            address(usdtToken),
            address(usdcToken),
            owner,
            owner  // backend signer
        );
        
        // Configure sale with scaled times
        xtsySale.SaleConfig memory config = xtsySale.SaleConfig({
            presaleStartTime: block.timestamp + 25 seconds,  // 1 hour scaled
            presaleEndTime: block.timestamp + 50 minutes,    // 5 days scaled
            publicSaleStartTime: block.timestamp + 60 minutes, // 6 days scaled
            publicSaleEndTime: block.timestamp + 130 minutes,  // 13 days scaled
            presaleRate: 25000,        // $0.025 per token
            publicSaleStartRate: 100000, // $0.10 per token
            priceIncreaseInterval: 30 minutes, // 3 days scaled
            priceIncreaseAmount: 10000 // $0.01 increase
        });
        presale.configureSale(config);
        
        // Set TGE timestamp
        presale.setTGETimestamp(block.timestamp + 140 minutes); // 14 days scaled
        
        // Transfer tokens to presale (enough for presale + public + referrals)
        xtsyToken.transfer(address(presale), 50_000_000 * 10**18);
        
        // Backend signer setup is done in constructor
        
        // Fund users
        usdtToken.mint(alice, 10_000 * 10**6);
        usdtToken.mint(bob, 10_000 * 10**6);
        usdcToken.mint(alice, 10_000 * 10**6);
        usdcToken.mint(charlie, 10_000 * 10**6);
        
        vm.stopPrank();
        
        // Approve tokens
        vm.prank(alice);
        usdtToken.approve(address(presale), type(uint256).max);
        vm.prank(alice);
        usdcToken.approve(address(presale), type(uint256).max);
        
        vm.prank(bob);
        usdtToken.approve(address(presale), type(uint256).max);
        
        vm.prank(charlie);
        usdcToken.approve(address(presale), type(uint256).max);
    }
    
    // Helper function to generate signatures for testing
    function generateSignature(address user, uint256 amount, uint256 nonce) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encodePacked(user, amount, nonce, address(presale)));
        // Use the same format as the contract - this should match MessageHashUtils.toEthSignedMessageHash
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }
    
    function testBasicSetup() public {
        // Check category caps
        (uint256 cap, uint256 allocated,) = presale.getCategoryInfo(xtsySale.VestingCategory.Presale);
        assertEq(cap, 20_000_000 * 10**18);
        assertEq(allocated, 0);
        
        (cap, allocated,) = presale.getCategoryInfo(xtsySale.VestingCategory.TeamAdvisors);
        assertEq(cap, 75_000_000 * 10**18);
        assertEq(allocated, 0);
        
        // Check vesting configs
        (,, xtsySale.VestingConfig memory config) = presale.getCategoryInfo(xtsySale.VestingCategory.Presale);
        assertEq(config.tgePercent, 1000); // 100%
        assertEq(config.cliffMonths, 0);
        assertEq(config.vestingMonths, 0);
        
        (,, config) = presale.getCategoryInfo(xtsySale.VestingCategory.TeamAdvisors);
        assertEq(config.tgePercent, 0); // 0% at TGE
        assertEq(config.cliffMonths, 12); // 12 month cliff
        assertEq(config.vestingMonths, 24); // 24 month vesting
    }
    
    function testPresalePurchase() public {
        vm.warp(block.timestamp + 25 seconds); // Start presale
        
        uint256 purchaseAmount = 1000 * 10**6; // $1000
        uint256 expectedTokens = (purchaseAmount * 10**18) / 25000; // 40,000 XTSY
        uint256 nonce = 1;
        bytes memory signature = generateSignature(alice, purchaseAmount, nonce);
        
        vm.prank(alice);
        presale.buyTokensWithUSDT(purchaseAmount, nonce, signature);
        
        xtsySale.UserPurchase memory purchase = presale.getUserPurchaseInfo(alice);
        assertEq(purchase.presalePurchased, purchaseAmount);
        assertEq(purchase.tokensAllocated, expectedTokens);
        
        (uint256 totalPresale,,,,, xtsySale.SalePhase phase) = presale.getContractStats();
        assertEq(totalPresale, expectedTokens);
        assertEq(uint(phase), uint(xtsySale.SalePhase.PresaleWhitelist));
    }
    
    function testPublicSalePurchase() public {
        vm.warp(block.timestamp + 60 minutes); // Start public sale
        
        uint256 purchaseAmount = 1000 * 10**6; // $1000
        uint256 expectedTokens = (purchaseAmount * 10**18) / 100000; // 10,000 XTSY at $0.10
        uint256 nonce = 2;
        bytes memory signature = ""; // Empty signature for public sale
        
        vm.prank(charlie); // Can buy in public sale without signature verification
        presale.buyTokensWithUSDC(purchaseAmount, nonce, signature);
        
        xtsySale.UserPurchase memory purchase = presale.getUserPurchaseInfo(charlie);
        assertEq(purchase.publicSalePurchased, purchaseAmount);
        assertEq(purchase.tokensAllocated, expectedTokens);
    }
    
    function testReferralPurchase() public {
        vm.warp(block.timestamp + 25 seconds); // Start presale
        
        uint256 purchaseAmount = 2000 * 10**6; // $2000
        uint256 expectedTokens = (purchaseAmount * 10**18) / 25000; // 80,000 XTSY
        uint256 expectedBonus = (expectedTokens * 50) / 1000; // 5% = 4,000 XTSY
        uint256 nonce = 3;
        bytes memory signature = generateSignature(alice, purchaseAmount, nonce);
        
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(purchaseAmount, bob, nonce, signature);
        
        xtsySale.UserPurchase memory alicePurchase = presale.getUserPurchaseInfo(alice);
        assertEq(alicePurchase.referrer, bob);
        assertEq(alicePurchase.tokensAllocated, expectedTokens);
        
        xtsySale.ReferralInfo memory bobReferral = presale.getReferralInfo(bob);
        assertEq(bobReferral.totalReferred, 1);
        assertEq(bobReferral.totalReferralVolume, purchaseAmount);
        // Note: Referrer now gets payment tokens immediately, not XTSY tokens
    }
    
    function testTGEClaiming() public {
        // Purchase during presale
        vm.warp(block.timestamp + 25 seconds);
        uint256 purchaseAmount = 1000 * 10**6;
        uint256 nonce = 4;
        bytes memory signature = generateSignature(alice, purchaseAmount, nonce);
        vm.prank(alice);
        presale.buyTokensWithUSDT(purchaseAmount, nonce, signature);
        
        // Try to claim before TGE
        vm.expectRevert(xtsySale.TGENotSet.selector);
        vm.prank(alice);
        presale.claimTGETokens();
        
        // Warp to TGE
        vm.warp(block.timestamp + 140 minutes);
        
        uint256 aliceBalanceBefore = xtsyToken.balanceOf(alice);
        vm.prank(alice);
        presale.claimTGETokens();
        
        uint256 aliceBalanceAfter = xtsyToken.balanceOf(alice);
        uint256 expectedTokens = (purchaseAmount * 10**18) / 25000;
        
        assertEq(aliceBalanceAfter - aliceBalanceBefore, expectedTokens);
        
        // Check can't claim again
        vm.expectRevert(xtsySale.NoTokensToClaim.selector);
        vm.prank(alice);
        presale.claimTGETokens();
    }
    
    function testTeamAllocation() public {
        uint256 allocationAmount = 1_000_000 * 10**18; // 1M tokens
        
        vm.prank(owner);
        presale.allocateTokens(bob, xtsySale.VestingCategory.TeamAdvisors, allocationAmount);
        
        xtsySale.UserAllocation memory allocation = presale.getUserAllocation(bob, xtsySale.VestingCategory.TeamAdvisors);
        assertEq(allocation.totalAllocated, allocationAmount);
        assertEq(allocation.claimedAmount, 0);
        
        (uint256 cap, uint256 categoryAllocated,) = presale.getCategoryInfo(xtsySale.VestingCategory.TeamAdvisors);
        assertEq(categoryAllocated, allocationAmount);
    }
    
    function testTeamVesting() public {
        uint256 allocationAmount = 1_000_000 * 10**18;
        
        // Allocate team tokens
        vm.prank(owner);
        presale.allocateTokens(bob, xtsySale.VestingCategory.TeamAdvisors, allocationAmount);
        
        // Set TGE time
        vm.warp(block.timestamp + 140 minutes);
        
        // Try to claim immediately (should fail due to cliff)
        vm.expectRevert(xtsySale.NoTokensToClaim.selector);
        vm.prank(bob);
        presale.claimVestedTokens(xtsySale.VestingCategory.TeamAdvisors);
        
        // Warp past cliff (12 months scaled)
        vm.warp(block.timestamp + 12 * 30 * 10 minutes); // 12 months scaled
        
        uint256 claimableAmount = presale.getClaimableAmount(bob, xtsySale.VestingCategory.TeamAdvisors);
        assertTrue(claimableAmount > 0);
        
        uint256 bobBalanceBefore = xtsyToken.balanceOf(bob);
        vm.prank(bob);
        presale.claimVestedTokens(xtsySale.VestingCategory.TeamAdvisors);
        
        uint256 bobBalanceAfter = xtsyToken.balanceOf(bob);
        assertTrue(bobBalanceAfter > bobBalanceBefore);
    }
    
    function testMarketingVesting() public {
        uint256 allocationAmount = 1_000_000 * 10**18;
        
        // Allocate marketing tokens
        vm.prank(owner);
        presale.allocateTokens(charlie, xtsySale.VestingCategory.Marketing, allocationAmount);
        
        // Set TGE time
        vm.warp(block.timestamp + 140 minutes);
        
        // Should be able to claim 20% at TGE
        uint256 claimableAmount = presale.getClaimableAmount(charlie, xtsySale.VestingCategory.Marketing);
        uint256 expectedTGE = (allocationAmount * 200) / 1000; // 20%
        assertApproxEqRel(claimableAmount, expectedTGE, 0.01e18); // 1% tolerance
        
        vm.prank(charlie);
        presale.claimVestedTokens(xtsySale.VestingCategory.Marketing);
        
        // Wait 3 months and claim more
        vm.warp(block.timestamp + 3 * 30 * 10 minutes); // 3 months scaled
        
        uint256 claimableAfter = presale.getClaimableAmount(charlie, xtsySale.VestingCategory.Marketing);
        assertTrue(claimableAfter > 0);
    }
    
    function testDynamicPricing() public {
        vm.warp(block.timestamp + 60 minutes); // Start public sale
        
        uint256 initialRate = presale.getCurrentRate();
        assertEq(initialRate, 100000); // $0.10
        
        // Warp forward by one price increase interval
        vm.warp(block.timestamp + 30 minutes); // 3 days scaled
        
        uint256 newRate = presale.getCurrentRate();
        assertEq(newRate, 110000); // $0.11
    }
    
    function testCategoryCaps() public {
        vm.warp(block.timestamp + 25 seconds); // Start presale
        
        // Try to exceed presale cap
        uint256 hugePurchase = 50_000_000 * 10**6; // $50M (would get 2B tokens at $0.025)
        uint256 nonce = 5;
        bytes memory signature = generateSignature(alice, hugePurchase, nonce);
        
        vm.expectRevert(xtsySale.InsufficientTokensAvailable.selector);
        vm.prank(alice);
        presale.buyTokensWithUSDT(hugePurchase, nonce, signature);
    }
}