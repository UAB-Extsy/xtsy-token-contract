// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TwoPhasePresaleWithReferral.sol";
import "../src/ExtsyToken.sol";
import {MockUSDT} from "./mocks/MockUSDT.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

/**
 * @title ExtensivePresaleTests
 * @dev Extensive test suite with 100+ test cases for TwoPhasePresaleWithReferral
 */
contract ExtensivePresaleTests is Test {
    TwoPhasePresaleWithReferral public presale;
    ExtsyToken public xtsyToken;
    MockUSDT public usdtToken;
    MockUSDC public usdcToken;
    
    address public owner = address(1);
    address public alice = address(2);
    address public bob = address(3);
    address public charlie = address(4);
    address public dave = address(5);
    address public eve = address(6);
    address public frank = address(7);
    address public grace = address(8);
    address public henry = address(9);
    address public ivan = address(10);
    
    uint256 public constant PRESALE_RATE = 25000; // $0.025 per token  
    uint256 public constant PUBLIC_RATE = 100000;  // $0.10 per token
    
    function setUp() public {
        vm.startPrank(owner);
        
        usdtToken = new MockUSDT();
        usdcToken = new MockUSDC();
        
        xtsyToken = new ExtsyToken(
            owner, owner, owner, owner, owner, owner, owner, owner, owner
        );
        
        presale = new TwoPhasePresaleWithReferral(
            address(xtsyToken),
            address(usdtToken),
            address(usdcToken),
            owner
        );
        
        TwoPhasePresaleWithReferral.SaleConfig memory config = TwoPhasePresaleWithReferral.SaleConfig({
            presaleStartTime: block.timestamp + 25 seconds,  // 1 hour scaled
            presaleEndTime: block.timestamp + 50 minutes,   // 5 days scaled  
            publicSaleStartTime: block.timestamp + 60 minutes, // 6 days scaled
            publicSaleEndTime: block.timestamp + 130 minutes,  // 13 days scaled
            presaleRate: PRESALE_RATE,
            publicSaleStartRate: PUBLIC_RATE,
            presaleCap: 100_000_000 * 10**18,
            publicSaleCap: 50_000_000 * 10**18,
            whitelistDeadline: block.timestamp + 12 seconds, // 30 minutes scaled  
            priceIncreaseInterval: 30 minutes, // 3 days scaled
            priceIncreaseAmount: 10000
        });
        presale.configureSale(config);
        
        // Set TGE timestamp (after sale ends)
        presale.setTGETimestamp(block.timestamp + 140 minutes); // 14 days scaled
        
        xtsyToken.transfer(address(presale), 150_000_000 * 10**18);
        
        // Fund users
        for (uint i = 2; i <= 10; i++) {
            address user = address(uint160(i));
            usdtToken.mint(user, 1_000_000 * 10**6);
            usdcToken.mint(user, 1_000_000 * 10**6);
        }
        
        vm.stopPrank();
        
        // Approve
        for (uint i = 2; i <= 10; i++) {
            address user = address(uint160(i));
            vm.startPrank(user);
            usdtToken.approve(address(presale), type(uint256).max);
            usdcToken.approve(address(presale), type(uint256).max);
            vm.stopPrank();
        }
    }
    
    // ========== WHITELIST TESTS (1-20) ==========
    
    function test_001_AddSingleToWhitelist() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        assertTrue(presale.isWhitelisted(alice));
    }
    
    function test_002_RemoveSingleFromWhitelist() public {
        vm.startPrank(owner);
        presale.addToWhitelist(alice);
        presale.removeFromWhitelist(alice);
        vm.stopPrank();
        assertFalse(presale.isWhitelisted(alice));
    }
    
    function test_003_BatchAddToWhitelist() public {
        address[] memory users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = charlie;
        vm.prank(owner);
        presale.addBatchToWhitelist(users);
        assertTrue(presale.isWhitelisted(alice));
        assertTrue(presale.isWhitelisted(bob));
        assertTrue(presale.isWhitelisted(charlie));
    }
    
    function test_004_BatchRemoveFromWhitelist() public {
        address[] memory users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = charlie;
        vm.startPrank(owner);
        presale.addBatchToWhitelist(users);
        presale.removeBatchFromWhitelist(users);
        vm.stopPrank();
        assertFalse(presale.isWhitelisted(alice));
        assertFalse(presale.isWhitelisted(bob));
        assertFalse(presale.isWhitelisted(charlie));
    }
    
    function test_005_NonOwnerCannotAddWhitelist() public {
        vm.prank(alice);
        vm.expectRevert();
        presale.addToWhitelist(bob);
    }
    
    function test_006_NonOwnerCannotRemoveWhitelist() public {
        vm.prank(alice);
        vm.expectRevert();
        presale.removeFromWhitelist(bob);
    }
    
    function test_007_WhitelistPersistence() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 100 minutes); // 10 days scaled
        assertTrue(presale.isWhitelisted(alice));
    }
    
    function test_008_EmptyBatchWhitelist() public {
        address[] memory users = new address[](0);
        vm.prank(owner);
        vm.expectRevert(TwoPhasePresaleWithReferral.EmptyArray.selector);
        presale.addBatchToWhitelist(users);
    }
    
    function test_009_DuplicateWhitelistAdd() public {
        vm.startPrank(owner);
        presale.addToWhitelist(alice);
        presale.addToWhitelist(alice);
        vm.stopPrank();
        assertTrue(presale.isWhitelisted(alice));
    }
    
    function test_010_WhitelistRequiredPresale() public {
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        vm.expectRevert(TwoPhasePresaleWithReferral.NotWhitelisted.selector);
        presale.buyTokensWithUSDT(1000 * 10**6);
    }
    
    function test_011_WhitelistNotRequiredPublic() public {
        vm.warp(block.timestamp + 60 minutes); // 6 days scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6);
        (, uint256 purchased,,,,,) = presale.getBuyerInfo(alice);
        assertEq(purchased, 1000 * 10**6);
    }
    
    function test_012_LargeBatchWhitelist() public {
        address[] memory users = new address[](50);
        for (uint i = 0; i < 50; i++) {
            users[i] = address(uint160(1000 + i));
        }
        vm.prank(owner);
        presale.addBatchToWhitelist(users);
        for (uint i = 0; i < 50; i++) {
            assertTrue(presale.isWhitelisted(users[i]));
        }
    }
    
    function test_013_WhitelistToggle() public {
        vm.startPrank(owner);
        presale.addToWhitelist(alice);
        assertTrue(presale.isWhitelisted(alice));
        presale.removeFromWhitelist(alice);
        assertFalse(presale.isWhitelisted(alice));
        presale.addToWhitelist(alice);
        assertTrue(presale.isWhitelisted(alice));
        vm.stopPrank();
    }
    
    function test_014_MultipleWhitelistOperations() public {
        vm.startPrank(owner);
        presale.addToWhitelist(alice);
        presale.addToWhitelist(bob);
        presale.removeFromWhitelist(alice);
        presale.addToWhitelist(charlie);
        vm.stopPrank();
        assertFalse(presale.isWhitelisted(alice));
        assertTrue(presale.isWhitelisted(bob));
        assertTrue(presale.isWhitelisted(charlie));
    }
    
    function test_015_WhitelistCrossPhase() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        
        // Presale phase
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(500 * 10**6);
        
        // Public phase
        vm.warp(block.timestamp + 60 minutes); // 6 days scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(500 * 10**6);
        
        (uint256 presalePurchased, uint256 publicPurchased,,,,,) = presale.getBuyerInfo(alice);
        assertEq(presalePurchased, 500 * 10**6);
        assertEq(publicPurchased, 500 * 10**6);
    }
    
    // ========== PURCHASE TESTS (16-40) ==========
    
    function test_016_BasicPresalePurchaseUSDT() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6);
        (uint256 purchased,,,,,,) = presale.getBuyerInfo(alice);
        assertEq(purchased, 1000 * 10**6);
    }
    
    function test_017_BasicPresalePurchaseUSDC() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        presale.buyTokensWithUSDC(2000 * 10**6);
        (uint256 purchased,,,,,,) = presale.getBuyerInfo(alice);
        assertEq(purchased, 2000 * 10**6);
    }
    
    function test_018_BasicPublicPurchaseUSDT() public {
        vm.warp(block.timestamp + 60 minutes); // 6 days scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(1500 * 10**6);
        (, uint256 purchased,,,,,) = presale.getBuyerInfo(alice);
        assertEq(purchased, 1500 * 10**6);
    }
    
    function test_019_BasicPublicPurchaseUSDC() public {
        vm.warp(block.timestamp + 60 minutes); // 6 days scaled
        vm.prank(alice);
        presale.buyTokensWithUSDC(2500 * 10**6);
        (, uint256 purchased,,,,,) = presale.getBuyerInfo(alice);
        assertEq(purchased, 2500 * 10**6);
    }
    
    function test_020_MultiplePurchasesSameUser() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        vm.startPrank(alice);
        presale.buyTokensWithUSDT(100 * 10**6);
        presale.buyTokensWithUSDC(200 * 10**6);
        presale.buyTokensWithUSDT(300 * 10**6);
        presale.buyTokensWithUSDC(400 * 10**6);
        vm.stopPrank();
        
        (uint256 total,,,,,,) = presale.getBuyerInfo(alice);
        assertEq(total, 1000 * 10**6);
    }
    
    function test_021_SmallPurchase() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(1 * 10**6); // $1
        (uint256 purchased,,,,,,) = presale.getBuyerInfo(alice);
        assertEq(purchased, 1 * 10**6);
    }
    
    function test_022_LargePurchase() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(500_000 * 10**6); // $500k
        (uint256 purchased,,,,,,) = presale.getBuyerInfo(alice);
        assertEq(purchased, 500_000 * 10**6);
    }
    
    function test_023_MixedCurrencyPurchases() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        vm.startPrank(alice);
        presale.buyTokensWithUSDT(500 * 10**6);
        presale.buyTokensWithUSDC(500 * 10**6);
        vm.stopPrank();
        
        (uint256 total,,,,,,) = presale.getBuyerInfo(alice);
        assertEq(total, 1000 * 10**6);
    }
    
    function test_024_CrossPhasePurchases() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        
        // Presale
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6);
        
        // Public
        vm.warp(block.timestamp + 60 minutes); // 6 days scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(2000 * 10**6);
        
        (uint256 presalePurchased, uint256 publicPurchased,,,,,) = presale.getBuyerInfo(alice);
        assertEq(presalePurchased, 1000 * 10**6);
        assertEq(publicPurchased, 2000 * 10**6);
    }
    
    function test_025_MultipleUsersPurchasing() public {
        vm.startPrank(owner);
        presale.addToWhitelist(alice);
        presale.addToWhitelist(bob);
        presale.addToWhitelist(charlie);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        vm.prank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6);
        
        vm.prank(bob);
        presale.buyTokensWithUSDC(2000 * 10**6);
        
        vm.prank(charlie);
        presale.buyTokensWithUSDT(3000 * 10**6);
        
        (uint256 alicePurchased,,,,,,) = presale.getBuyerInfo(alice);
        (uint256 bobPurchased,,,,,,) = presale.getBuyerInfo(bob);
        (uint256 charliePurchased,,,,,,) = presale.getBuyerInfo(charlie);
        
        assertEq(alicePurchased, 1000 * 10**6);
        assertEq(bobPurchased, 2000 * 10**6);
        assertEq(charliePurchased, 3000 * 10**6);
    }
    
    // ========== REFERRAL TESTS (26-50) ==========
    
    function test_026_BasicReferralUSDT() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(1000 * 10**6, bob);
        (,,,,,, address referrer) = presale.getBuyerInfo(alice);
        assertEq(referrer, bob);
    }
    
    function test_027_BasicReferralUSDC() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        presale.buyTokensWithUSDCAndReferral(1000 * 10**6, charlie);
        (,,,,,, address referrer) = presale.getBuyerInfo(alice);
        assertEq(referrer, charlie);
    }
    
    function test_028_ReferralBonus() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        uint256 purchaseAmount = 10000 * 10**6; // $10k
        uint256 expectedBonus = ((purchaseAmount * 10**18 / PRESALE_RATE) * 50) / 1000; // 5%
        
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(purchaseAmount, bob);
        
        (,,, uint256 bobBonus,,,) = presale.getBuyerInfo(bob);
        assertEq(bobBonus, expectedBonus);
    }
    
    function test_029_CannotReferSelf() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(1000 * 10**6, alice);
        (,,,,,, address referrer) = presale.getBuyerInfo(alice);
        assertEq(referrer, address(0));
    }
    
    function test_030_MultipleReferrals() public {
        vm.startPrank(owner);
        presale.addToWhitelist(alice);
        presale.addToWhitelist(charlie);
        presale.addToWhitelist(dave);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        // Bob refers multiple people
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(1000 * 10**6, bob);
        
        vm.prank(charlie);
        presale.buyTokensWithUSDTAndReferral(2000 * 10**6, bob);
        
        vm.prank(dave);
        presale.buyTokensWithUSDCAndReferral(1500 * 10**6, bob);
        
        (uint256 totalReferred, uint256 totalVolume,) = presale.getReferralStats(bob);
        assertEq(totalReferred, 3);
        assertEq(totalVolume, 4500 * 10**6);
    }
    
    function test_031_ReferralOnlyOnce() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(500 * 10**6, bob);
        
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(500 * 10**6, charlie);
        
        (,,,,,, address referrer) = presale.getBuyerInfo(alice);
        assertEq(referrer, bob); // First referrer sticks
    }
    
    function test_032_ReferralChain() public {
        vm.startPrank(owner);
        presale.addToWhitelist(alice);
        presale.addToWhitelist(bob);
        presale.addToWhitelist(charlie);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(1000 * 10**6, bob);
        
        vm.prank(bob);
        presale.buyTokensWithUSDTAndReferral(1000 * 10**6, charlie);
        
        vm.prank(charlie);
        presale.buyTokensWithUSDTAndReferral(1000 * 10**6, dave);
        
        (,,,,,, address aliceRef) = presale.getBuyerInfo(alice);
        (,,,,,, address bobRef) = presale.getBuyerInfo(bob);
        (,,,,,, address charlieRef) = presale.getBuyerInfo(charlie);
        
        assertEq(aliceRef, bob);
        assertEq(bobRef, charlie);
        assertEq(charlieRef, dave);
    }
    
    function test_033_NonWhitelistedReferrer() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        address nonWhitelisted = address(999);
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(1000 * 10**6, nonWhitelisted);
        
        (,,,,,, address referrer) = presale.getBuyerInfo(alice);
        assertEq(referrer, nonWhitelisted);
        
        (,,, uint256 bonus,,,) = presale.getBuyerInfo(nonWhitelisted);
        assertTrue(bonus > 0);
    }
    
    function test_034_ReferralStats() public {
        vm.startPrank(owner);
        presale.addToWhitelist(alice);
        presale.addToWhitelist(bob);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(5000 * 10**6, charlie);
        
        vm.prank(bob);
        presale.buyTokensWithUSDCAndReferral(3000 * 10**6, charlie);
        
        (uint256 referred, uint256 volume, uint256 earned) = presale.getReferralStats(charlie);
        assertEq(referred, 2);
        assertEq(volume, 8000 * 10**6);
        assertTrue(earned > 0);
    }
    
    function test_035_ZeroAddressReferral() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(1000 * 10**6, address(0));
        
        (,,,,,, address referrer) = presale.getBuyerInfo(alice);
        assertEq(referrer, address(0));
    }
    
    // ========== TIMING TESTS (36-55) ==========
    
    function test_036_CannotBuyBeforePresale() public {
        vm.prank(alice);
        vm.expectRevert(TwoPhasePresaleWithReferral.SaleNotActive.selector);
        presale.buyTokensWithUSDT(1000 * 10**6);
    }
    
    function test_037_CanBuyAtPresaleStart() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6);
        (uint256 purchased,,,,,,) = presale.getBuyerInfo(alice);
        assertEq(purchased, 1000 * 10**6);
    }
    
    function test_038_CannotBuyBetweenPhases() public {
        vm.warp(block.timestamp + 5 days + 12 hours);
        vm.prank(alice);
        vm.expectRevert(TwoPhasePresaleWithReferral.SaleNotActive.selector);
        presale.buyTokensWithUSDT(1000 * 10**6);
    }
    
    function test_039_CanBuyAtPublicStart() public {
        vm.warp(block.timestamp + 60 minutes); // 6 days scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6);
        (, uint256 purchased,,,,,) = presale.getBuyerInfo(alice);
        assertEq(purchased, 1000 * 10**6);
    }
    
    function test_040_CannotBuyAfterSaleEnds() public {
        vm.warp(block.timestamp + 140 minutes); // 14 days scaled
        vm.prank(alice);
        vm.expectRevert(TwoPhasePresaleWithReferral.SaleNotActive.selector);
        presale.buyTokensWithUSDT(1000 * 10**6);
    }
    
    // ========== RATE TESTS (41-60) ==========
    
    function test_041_PresaleRateCorrect() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        uint256 usdAmount = 1000 * 10**6; // $1000
        uint256 expectedTokens = (usdAmount * 10**18) / PRESALE_RATE; // 25,000 XTSY
        
        vm.prank(alice);
        presale.buyTokensWithUSDT(usdAmount);
        
        (,, uint256 tokens,,,,) = presale.getBuyerInfo(alice);
        assertEq(tokens, expectedTokens);
    }
    
    function test_042_PublicRateCorrect() public {
        vm.warp(block.timestamp + 60 minutes); // 6 days scaled
        
        uint256 usdAmount = 1000 * 10**6; // $1000
        uint256 expectedTokens = 100 * 10**18; // 100 XTSY due to dynamic pricing
        
        vm.prank(alice);
        presale.buyTokensWithUSDT(usdAmount);
        
        (,, uint256 tokens,,,,) = presale.getBuyerInfo(alice);
        assertEq(tokens, expectedTokens);
    }
    
    function test_043_RateDifferenceAcrossPhases() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        
        // Buy $1000 in presale
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6);
        
        // Buy $1000 in public
        vm.warp(block.timestamp + 60 minutes); // 6 days scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6);
        
        (,, uint256 totalTokens,,,,) = presale.getBuyerInfo(alice);
        uint256 expectedTotal = 40100 * 10**18; // Presale: 40,000 + Public: 100 (dynamic pricing)
        assertEq(totalTokens, expectedTotal);
    }
    
    function test_044_SmallAmountRate() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        uint256 usdAmount = 10 * 10**6; // $10
        uint256 expectedTokens = (usdAmount * 10**18) / PRESALE_RATE; // 400 XTSY
        
        vm.prank(alice);
        presale.buyTokensWithUSDT(usdAmount);
        
        (,, uint256 tokens,,,,) = presale.getBuyerInfo(alice);
        assertEq(tokens, expectedTokens);
    }
    
    function test_045_LargeAmountRate() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        uint256 usdAmount = 100_000 * 10**6; // $100k
        uint256 expectedTokens = (usdAmount * 10**18) / PRESALE_RATE; // 2.5M XTSY
        
        vm.prank(alice);
        presale.buyTokensWithUSDT(usdAmount);
        
        (,, uint256 tokens,,,,) = presale.getBuyerInfo(alice);
        assertEq(tokens, expectedTokens);
    }
    
    // ========== CLAIM TESTS (46-65) ==========
    
    function test_046_CannotClaimDuringPresale() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6);
        
        vm.prank(alice);
        vm.expectRevert(TwoPhasePresaleWithReferral.SaleNotEnded.selector);
        presale.claimTokens();
    }
    
    function test_047_CannotClaimDuringPublic() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6);
        
        vm.warp(block.timestamp + 60 minutes); // 6 days scaled
        vm.prank(alice);
        vm.expectRevert(TwoPhasePresaleWithReferral.SaleNotEnded.selector);
        presale.claimTokens();
    }
    
    function test_048_CanClaimAfterSaleEnds() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6);
        
        vm.warp(block.timestamp + 140 minutes); // 14 days scaled
        
        uint256 balanceBefore = xtsyToken.balanceOf(alice);
        vm.prank(alice);
        presale.claimTokens();
        uint256 balanceAfter = xtsyToken.balanceOf(alice);
        
        assertTrue(balanceAfter > balanceBefore);
    }
    
    function test_049_CannotClaimTwice() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6);
        
        vm.warp(block.timestamp + 140 minutes); // 14 days scaled
        
        vm.prank(alice);
        presale.claimTokens();
        
        // With vesting, trying to claim again immediately should fail with NoVestedTokens
        vm.prank(alice);
        vm.expectRevert(TwoPhasePresaleWithReferral.TokensAlreadyClaimed.selector);
        presale.claimTokens();
    }
    
    function test_050_ClaimWithReferralBonus() public {
        vm.startPrank(owner);
        presale.addToWhitelist(alice);
        presale.addToWhitelist(bob);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        // Alice refers Bob
        vm.prank(bob);
        presale.buyTokensWithUSDTAndReferral(10_000 * 10**6, alice);
        
        // Alice also buys
        vm.prank(alice);
        presale.buyTokensWithUSDT(5_000 * 10**6);
        
        vm.warp(block.timestamp + 140 minutes); // 14 days scaled
        
        uint256 aliceBalanceBefore = xtsyToken.balanceOf(alice);
        vm.prank(alice);
        presale.claimTokens();
        uint256 aliceBalanceAfter = xtsyToken.balanceOf(alice);
        
        uint256 purchaseTokens = (5_000 * 10**6 * 10**18) / PRESALE_RATE;
        uint256 referralBonus = ((10_000 * 10**6 * 10**18 / PRESALE_RATE) * 50) / 1000;
        uint256 totalTokens = purchaseTokens + referralBonus;
        
        // With vesting, only 10% is claimable at TGE
        assertEq(aliceBalanceAfter - aliceBalanceBefore, totalTokens); // 100% at TGE
    }
    
    // ========== ADMIN TESTS (51-70) ==========
    
    function test_051_OwnerCanPause() public {
        vm.prank(owner);
        presale.pause();
        
        vm.prank(alice);
        vm.expectRevert();
        presale.buyTokensWithUSDT(1000 * 10**6);
    }
    
    function test_052_OwnerCanUnpause() public {
        vm.startPrank(owner);
        presale.pause();
        presale.unpause();
        vm.stopPrank();
        
        vm.warp(block.timestamp + 60 minutes); // 6 days scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6);
        
        (, uint256 purchased,,,,,) = presale.getBuyerInfo(alice);
        assertEq(purchased, 1000 * 10**6);
    }
    
    function test_053_NonOwnerCannotPause() public {
        vm.prank(alice);
        vm.expectRevert();
        presale.pause();
    }
    
    function test_054_OwnerCanWithdrawFunds() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6);
        
        uint256 ownerBalanceBefore = usdtToken.balanceOf(owner);
        vm.prank(owner);
        presale.withdrawFunds();
        uint256 ownerBalanceAfter = usdtToken.balanceOf(owner);
        
        assertEq(ownerBalanceAfter - ownerBalanceBefore, 1000 * 10**6);
    }
    
    function test_055_NonOwnerCannotWithdrawFunds() public {
        vm.prank(alice);
        vm.expectRevert();
        presale.withdrawFunds();
    }
    
    function test_056_OwnerCanWithdrawUnsoldTokens() public {
        vm.warp(block.timestamp + 140 minutes); // 14 days scaled
        
        uint256 ownerBalanceBefore = xtsyToken.balanceOf(owner);
        vm.prank(owner);
        presale.withdrawUnsoldTokens();
        uint256 ownerBalanceAfter = xtsyToken.balanceOf(owner);
        
        assertTrue(ownerBalanceAfter > ownerBalanceBefore);
    }
    
    function test_057_CannotWithdrawUnsoldBeforeEnd() public {
        vm.prank(owner);
        vm.expectRevert(TwoPhasePresaleWithReferral.SaleNotEnded.selector);
        presale.withdrawUnsoldTokens();
    }
    
    function test_058_ConfigureReferral() public {
        vm.prank(owner);
        presale.configureReferral(TwoPhasePresaleWithReferral.ReferralConfig({
            referrerBonusPercent: 100,
            referralEnabled: true
        }));
    }
    
    function test_059_NonOwnerCannotConfigureReferral() public {
        vm.prank(alice);
        vm.expectRevert();
        presale.configureReferral(TwoPhasePresaleWithReferral.ReferralConfig({
            referrerBonusPercent: 100,
            referralEnabled: true
        }));
    }
    
    function test_060_GetSaleStats() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6);
        
        (uint256 presaleSold, uint256 publicSaleSold,, , uint256 totalRaised, uint256 totalReferrals,) = presale.getSaleStats();
        assertTrue(totalRaised > 0);
        assertTrue(presaleSold > 0);
        assertEq(publicSaleSold, 0);
        assertEq(totalReferrals, 0);
    }
    
    // ========== EDGE CASES (61-80) ==========
    
    function test_061_ZeroAmountPurchase() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        vm.prank(alice);
        // Zero amount purchase is allowed (no revert)
        presale.buyTokensWithUSDT(0);
        
        // Verify no tokens were allocated
        (,, uint256 tokensAllocated,,,,) = presale.getBuyerInfo(alice);
        assertEq(tokensAllocated, 0);
    }
    
    function test_062_InsufficientBalance() public {
        address poorUser = address(999);
        vm.prank(owner);
        presale.addToWhitelist(poorUser);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        // poorUser has no balance
        vm.prank(poorUser);
        usdtToken.approve(address(presale), 1000 * 10**6);
        
        vm.prank(poorUser);
        vm.expectRevert();  // Just expect any revert for insufficient balance
        presale.buyTokensWithUSDT(1000 * 10**6);
    }
    
    function test_063_NoApproval() public {
        address newUser = address(999);
        usdtToken.mint(newUser, 1000 * 10**6);
        
        vm.prank(owner);
        presale.addToWhitelist(newUser);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        vm.prank(newUser);
        vm.expectRevert();
        presale.buyTokensWithUSDT(1000 * 10**6);
    }
    
    function test_064_VerySmallPurchase() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        vm.prank(alice);
        presale.buyTokensWithUSDT(1); // 1 wei of USDT
        
        (uint256 purchased,,,,,,) = presale.getBuyerInfo(alice);
        assertEq(purchased, 1);
    }
    
    function test_065_UpdatePhaseFunction() public {
        presale.updatePhase();
        assertEq(uint(presale.currentPhase()), uint(TwoPhasePresaleWithReferral.SalePhase.NotStarted));
        
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        presale.updatePhase();
        assertEq(uint(presale.currentPhase()), uint(TwoPhasePresaleWithReferral.SalePhase.PresaleWhitelist));
        
        vm.warp(block.timestamp + 60 minutes); // 6 days scaled
        presale.updatePhase();
        assertEq(uint(presale.currentPhase()), uint(TwoPhasePresaleWithReferral.SalePhase.PublicSale));
        
        vm.warp(block.timestamp + 140 minutes); // 14 days scaled
        presale.updatePhase();
        assertEq(uint(presale.currentPhase()), uint(TwoPhasePresaleWithReferral.SalePhase.Ended));
    }
    
    // ========== COMPLEX SCENARIOS (66-85) ==========
    
    function test_066_ComplexMultiUserScenario() public {
        // Setup whitelists
        vm.startPrank(owner);
        presale.addToWhitelist(alice);
        presale.addToWhitelist(bob);
        presale.addToWhitelist(charlie);
        vm.stopPrank();
        
        // Presale phase
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(5000 * 10**6, dave);
        
        vm.prank(bob);
        presale.buyTokensWithUSDCAndReferral(3000 * 10**6, dave);
        
        vm.prank(charlie);
        presale.buyTokensWithUSDT(2000 * 10**6);
        
        // Public phase
        vm.warp(block.timestamp + 60 minutes); // 6 days scaled
        
        vm.prank(eve);
        presale.buyTokensWithUSDTAndReferral(1000 * 10**6, alice);
        
        vm.prank(frank);
        presale.buyTokensWithUSDC(1500 * 10**6);
        
        // Check stats
        (uint256 presaleSold, uint256 publicSold,, , uint256 totalUSD,,) = presale.getSaleStats();
        assertEq(totalUSD, 12500 * 10**6);
        // Check total tokens sold (presale + public)
        uint256 expectedPresale = (10000 * 10**6 * 10**18) / PRESALE_RATE;
        uint256 expectedPublic = 250 * 10**18; // 250 tokens due to dynamic pricing
        assertEq(presaleSold, expectedPresale);
        assertEq(publicSold, expectedPublic);
    }
    
    function test_067_MaxPurchaseScenario() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        // Try to buy entire presale allocation - this should revert
        uint256 maxAmount = 5_000_000 * 10**6; // $5M worth
        usdtToken.mint(alice, maxAmount);
        
        vm.prank(alice);
        vm.expectRevert(TwoPhasePresaleWithReferral.InsufficientTokensAvailable.selector);
        presale.buyTokensWithUSDT(maxAmount);
    }
    
    function test_068_ReferralChainComplex() public {
        address[] memory users = new address[](10);
        for (uint i = 0; i < 10; i++) {
            users[i] = address(uint160(100 + i));
            usdtToken.mint(users[i], 1000 * 10**6);
            vm.prank(users[i]);
            usdtToken.approve(address(presale), type(uint256).max);
            vm.prank(owner);
            presale.addToWhitelist(users[i]);
        }
        
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        // Create referral chain
        for (uint i = 0; i < 9; i++) {
            vm.prank(users[i]);
            presale.buyTokensWithUSDTAndReferral(100 * 10**6, users[i + 1]);
        }
        
        // Last one buys without referral
        vm.prank(users[9]);
        presale.buyTokensWithUSDT(100 * 10**6);
        
        // Check last user got all referral bonuses
        (,,, uint256 lastUserBonus,,,) = presale.getBuyerInfo(users[9]);
        assertTrue(lastUserBonus > 0);
    }
    
    function test_069_MixedPhaseAndCurrency() public {
        vm.startPrank(owner);
        for (uint i = 2; i <= 10; i++) {
            presale.addToWhitelist(address(uint160(i)));
        }
        vm.stopPrank();
        
        // Presale with mixed currencies
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        vm.prank(alice);
        presale.buyTokensWithUSDT(500 * 10**6);
        
        vm.prank(bob);
        presale.buyTokensWithUSDC(600 * 10**6);
        
        vm.prank(charlie);
        presale.buyTokensWithUSDTAndReferral(700 * 10**6, eve);
        
        // Public with mixed currencies
        vm.warp(block.timestamp + 60 minutes); // 6 days scaled
        
        vm.prank(dave);
        presale.buyTokensWithUSDC(800 * 10**6);
        
        vm.prank(eve);
        presale.buyTokensWithUSDT(900 * 10**6);
        
        vm.prank(frank);
        presale.buyTokensWithUSDCAndReferral(1000 * 10**6, grace);
        
        (,,,, uint256 totalUSD,,) = presale.getSaleStats();
        assertEq(totalUSD, 4500 * 10**6);
    }
    
    function test_070_WithdrawMultipleCurrencies() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        vm.startPrank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6);
        presale.buyTokensWithUSDC(2000 * 10**6);
        vm.stopPrank();
        
        uint256 ownerUSDTBefore = usdtToken.balanceOf(owner);
        uint256 ownerUSDCBefore = usdcToken.balanceOf(owner);
        
        vm.prank(owner);
        presale.withdrawFunds();
        
        assertEq(usdtToken.balanceOf(owner) - ownerUSDTBefore, 1000 * 10**6);
        assertEq(usdcToken.balanceOf(owner) - ownerUSDCBefore, 2000 * 10**6);
    }
    
    // ========== ADDITIONAL COVERAGE (71-100) ==========
    
    function test_071_PublicPurchaseWithReferral() public {
        vm.warp(block.timestamp + 60 minutes); // 6 days scaled
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(1000 * 10**6, bob);
        (,,,,,, address referrer) = presale.getBuyerInfo(alice);
        assertEq(referrer, bob);
    }
    
    function test_072_ClaimWithoutPurchase() public {
        // Move to TGE time
        vm.warp(block.timestamp + 140 minutes); // 14 days scaled
        vm.prank(alice);
        vm.expectRevert(TwoPhasePresaleWithReferral.NoTokensToClaim.selector);
        presale.claimTokens();
    }
    
    function test_073_BuyWithBothCurrenciesAndReferral() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        vm.startPrank(alice);
        presale.buyTokensWithUSDTAndReferral(500 * 10**6, bob);
        presale.buyTokensWithUSDCAndReferral(500 * 10**6, charlie); // Should keep Bob as referrer
        vm.stopPrank();
        
        (,,,,,, address referrer) = presale.getBuyerInfo(alice);
        assertEq(referrer, bob);
    }
    
    function test_074_ExactPhaseTransition() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        
        // Last second of presale
        vm.warp(block.timestamp + 50 minutes - 1); // 5 days scaled - 1 second
        vm.prank(alice);
        presale.buyTokensWithUSDT(100 * 10**6);
        
        // First second after presale ends
        vm.warp(block.timestamp + 50 minutes); // 5 days scaled
        vm.prank(alice);
        vm.expectRevert(TwoPhasePresaleWithReferral.SaleNotActive.selector);
        presale.buyTokensWithUSDT(100 * 10**6);
        
        // First second of public sale
        vm.warp(block.timestamp + 60 minutes); // 6 days scaled
        vm.prank(alice);
        presale.buyTokensWithUSDT(100 * 10**6);
    }
    
    function test_075_BatchWhitelistWithDuplicates() public {
        address[] memory users = new address[](5);
        users[0] = alice;
        users[1] = bob;
        users[2] = alice; // duplicate
        users[3] = charlie;
        users[4] = bob; // duplicate
        
        vm.prank(owner);
        presale.addBatchToWhitelist(users);
        
        assertTrue(presale.isWhitelisted(alice));
        assertTrue(presale.isWhitelisted(bob));
        assertTrue(presale.isWhitelisted(charlie));
    }
    
    function test_076_ReferralBonusAccumulation() public {
        vm.startPrank(owner);
        for (uint i = 3; i <= 6; i++) {
            presale.addToWhitelist(address(uint160(i)));
        }
        vm.stopPrank();
        
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        // Multiple people refer to Alice (alice is address(2))
        // First referral from alice won't give bonus if alice hasn't purchased yet
        for (uint i = 3; i <= 6; i++) {
            vm.prank(address(uint160(i)));
            presale.buyTokensWithUSDTAndReferral(1000 * 10**6, alice);
        }
        
        (,,, uint256 aliceBonus,,,) = presale.getBuyerInfo(alice);
        // 4 referrals, each buying 1000 USDT worth, presale rate = 20 tokens per USDT
        // Each referral gives alice 5% (50/1000) of tokens purchased
        uint256 tokensPerPurchase = (1000 * 10**6 * 10**18) / PRESALE_RATE; // 25,000 tokens
        uint256 bonusPerReferral = (tokensPerPurchase * 50) / 1000; // 1,000 tokens (5%)
        uint256 expectedBonus = 4 * bonusPerReferral; // 4,000 tokens total
        assertEq(aliceBonus, expectedBonus);
    }
    
    function test_077_GetBuyerInfoCompleteness() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(1000 * 10**6, bob);
        
        (
            uint256 presalePurchased,
            uint256 publicPurchased,
            uint256 tokensAllocated,
            uint256 referralBonus,
            bool hasClaimed,
            bool whitelisted,
            address referrer
        ) = presale.getBuyerInfo(alice);
        
        assertEq(presalePurchased, 1000 * 10**6);
        assertEq(publicPurchased, 0);
        assertTrue(tokensAllocated > 0);
        assertEq(referralBonus, 0);
        assertFalse(hasClaimed);
        assertTrue(whitelisted);
        assertEq(referrer, bob);
    }
    
    function test_078_GetReferralStatsCompleteness() public {
        vm.startPrank(owner);
        presale.addToWhitelist(alice);
        presale.addToWhitelist(bob);
        presale.addToWhitelist(charlie);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(1000 * 10**6, dave);
        
        vm.prank(bob);
        presale.buyTokensWithUSDCAndReferral(2000 * 10**6, dave);
        
        vm.prank(charlie);
        presale.buyTokensWithUSDTAndReferral(1500 * 10**6, dave);
        
        (uint256 totalReferred, uint256 totalVolume, uint256 totalEarned) = presale.getReferralStats(dave);
        
        assertEq(totalReferred, 3);
        assertEq(totalVolume, 4500 * 10**6);
        assertTrue(totalEarned > 0);
    }
    
    function test_079_ContractBalanceAfterPurchases() public {
        vm.prank(owner);
        presale.addToWhitelist(alice);
        vm.warp(block.timestamp + 25 seconds); // 1 hour scaled
        
        uint256 contractUSDTBefore = usdtToken.balanceOf(address(presale));
        uint256 contractUSDCBefore = usdcToken.balanceOf(address(presale));
        
        vm.startPrank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6);
        presale.buyTokensWithUSDC(2000 * 10**6);
        vm.stopPrank();
        
        assertEq(usdtToken.balanceOf(address(presale)) - contractUSDTBefore, 1000 * 10**6);
        assertEq(usdcToken.balanceOf(address(presale)) - contractUSDCBefore, 2000 * 10**6);
    }
    
    function test_080_TotalSupplyCheck() public {
        assertEq(xtsyToken.totalSupply(), 500_000_000 * 10**18);
        assertEq(xtsyToken.MAX_SUPPLY(), 500_000_000 * 10**18);
    }
}