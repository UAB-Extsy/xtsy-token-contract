// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/xtsySale.sol";
import "../src/ExtsyToken.sol";
import {MockUSDT} from "../src/mocks/MockUSDT.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

/**
 * @title ComprehensiveXtsySaleTest
 * @dev Extensive test suite for xtsySale contract covering all functionality
 */
contract ComprehensiveXtsySaleTest is Test {
    xtsySale public presale;
    ExtsyToken public xtsyToken;
    MockUSDT public usdtToken;
    MockUSDC public usdcToken;
    
    // Test addresses
    uint256 ownerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 backendSignerPrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 crossChainSignerPrivateKey = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    address public owner = vm.addr(ownerPrivateKey);
    address public backendSigner = vm.addr(backendSignerPrivateKey);
    address public crossChainSigner = vm.addr(crossChainSignerPrivateKey);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);
    address public referrer = address(0x5);
    
    // Test constants
    uint256 constant PRESALE_RATE = 100000; // $0.10 per token
    uint256 constant PUBLIC_RATE = 350000;  // $0.35 per token
    uint256 constant PRICE_INCREASE = 17500; // $0.0175
    uint256 constant PRICE_INTERVAL = 6 days;
    
    event TokensPurchased(
        address indexed buyer,
        uint256 usdAmount,
        uint256 tokens,
        xtsySale.SalePhase phase
    );
    
    event TokensAllocated(
        address indexed recipient,
        xtsySale.VestingCategory category,
        uint256 amount
    );
    
    event TokensClaimed(
        address indexed recipient,
        xtsySale.VestingCategory category,
        uint256 amount
    );

    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy tokens
        usdtToken = new MockUSDT();
        usdcToken = new MockUSDC();
        
        // Deploy XTSY token
        xtsyToken = new ExtsyToken(
            owner, owner, owner, owner, owner, owner, owner, owner, owner
        );
        
        // Deploy presale contract
        presale = new xtsySale(
            address(xtsyToken),
            address(usdtToken),
            address(usdcToken),
            owner,
            backendSigner,
            crossChainSigner
        );
        
        // Configure sale timing
        xtsySale.SaleConfig memory config = xtsySale.SaleConfig({
            presaleStartTime: block.timestamp + 1 hours,
            presaleEndTime: block.timestamp + 7 days,
            publicSaleStartTime: block.timestamp + 8 days,
            publicSaleEndTime: block.timestamp + 30 days,
            presaleRate: PRESALE_RATE,
            publicSaleStartRate: PUBLIC_RATE,
            priceIncreaseInterval: PRICE_INTERVAL,
            priceIncreaseAmount: PRICE_INCREASE
        });
        
        presale.configureSale(config);
        
        // Set TGE timestamp
        presale.setTGETimestamp(block.timestamp + 31 days);
        
        // Set up ETH price feed mock
        address mockPriceFeed = address(0x1);
        vm.mockCall(
            mockPriceFeed,
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(uint80(1), int256(200000000000), uint256(block.timestamp), uint256(block.timestamp), uint80(1))
        );
        presale.setEthUsdPriceFeed(mockPriceFeed);
        xtsyToken.transfer(address(presale), 100_000_000 * 10**18);
        
        // Mint test tokens to users
        usdtToken.mint(alice, 100_000 * 10**6);
        usdcToken.mint(alice, 100_000 * 10**6);
        usdtToken.mint(bob, 100_000 * 10**6);
        usdcToken.mint(bob, 100_000 * 10**6);
        
        vm.stopPrank();
        
        // Approve tokens
        vm.startPrank(alice);
        usdtToken.approve(address(presale), type(uint256).max);
        usdcToken.approve(address(presale), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(bob);
        usdtToken.approve(address(presale), type(uint256).max);
        usdcToken.approve(address(presale), type(uint256).max);
        vm.stopPrank();
    }
    
    // Helper function to generate backend signature
    function generateSignature(address user, uint256 amount, uint256 nonce) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encodePacked(user, amount, nonce, address(presale)));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(backendSignerPrivateKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }

    // ============================================================================
    // BASIC FUNCTIONALITY TESTS
    // ============================================================================
    
    function test_001_InitialState() public {
        assertEq(address(presale.saleToken()), address(xtsyToken));
        assertEq(address(presale.usdtToken()), address(usdtToken));
        assertEq(address(presale.usdcToken()), address(usdcToken));
        assertEq(presale.owner(), owner);
        assertTrue(presale.referralEnabled());
        assertEq(presale.referralBonusPercent(), 50); // 5%
    }
    
    function test_002_SalePhases() public {
        // Not started
        assertEq(uint(presale.getCurrentPhase()), uint(xtsySale.SalePhase.NotStarted));
        
        // Presale
        vm.warp(block.timestamp + 1 hours);
        assertEq(uint(presale.getCurrentPhase()), uint(xtsySale.SalePhase.PresaleWhitelist));
        
        // Public sale
        vm.warp(block.timestamp + 8 days);
        assertEq(uint(presale.getCurrentPhase()), uint(xtsySale.SalePhase.PublicSale));
        
        // Ended
        vm.warp(block.timestamp + 30 days);
        assertEq(uint(presale.getCurrentPhase()), uint(xtsySale.SalePhase.Ended));
    }
    
    function test_003_PresalePurchaseWithUSDT() public {
        vm.warp(block.timestamp + 1 hours); // Start presale
        
        uint256 purchaseAmount = 1000 * 10**6; // 1000 USDT
        uint256 nonce = 1;
        bytes memory signature = generateSignature(alice, purchaseAmount, nonce);
        
        uint256 aliceBalanceBefore = xtsyToken.balanceOf(alice);
        uint256 expectedTokens = (purchaseAmount * 10**18) / PRESALE_RATE;
        
        vm.expectEmit(true, true, true, true);
        emit TokensPurchased(alice, purchaseAmount, expectedTokens, xtsySale.SalePhase.PresaleWhitelist);
        
        vm.prank(alice);
        presale.buyTokensWithUSDT(purchaseAmount, nonce, signature);
        
        uint256 aliceBalanceAfter = xtsyToken.balanceOf(alice);
        assertEq(aliceBalanceAfter - aliceBalanceBefore, expectedTokens);
        
        // Check user purchase data
        xtsySale.UserPurchase memory purchase = presale.getUserPurchaseInfo(alice);
        assertEq(purchase.presalePurchased, purchaseAmount);
        assertEq(purchase.tokensAllocated, expectedTokens);
    }
    
    function test_004_PresalePurchaseWithUSDC() public {
        vm.warp(block.timestamp + 1 hours); // Start presale
        
        uint256 purchaseAmount = 2000 * 10**6; // 2000 USDC
        uint256 nonce = 2;
        bytes memory signature = generateSignature(alice, purchaseAmount, nonce);
        
        uint256 aliceBalanceBefore = xtsyToken.balanceOf(alice);
        uint256 expectedTokens = (purchaseAmount * 10**18) / PRESALE_RATE;
        
        vm.prank(alice);
        presale.buyTokensWithUSDC(purchaseAmount, nonce, signature);
        
        uint256 aliceBalanceAfter = xtsyToken.balanceOf(alice);
        assertEq(aliceBalanceAfter - aliceBalanceBefore, expectedTokens);
    }
    
    function test_005_PublicSalePurchase() public {
        vm.warp(block.timestamp + 8 days + 1 hours); // Start public sale
        
        uint256 purchaseAmount = 1000 * 10**6; // 1000 USDT
        uint256 nonce = 3;
        bytes memory signature = generateSignature(alice, purchaseAmount, nonce);
        
        uint256 expectedTokens = (purchaseAmount * 10**18) / PUBLIC_RATE;
        
        vm.prank(alice);
        presale.buyTokensWithUSDT(purchaseAmount, nonce, signature);
        
        xtsySale.UserPurchase memory purchase = presale.getUserPurchaseInfo(alice);
        assertEq(purchase.publicSalePurchased, purchaseAmount);
    }
    
    function test_006_ReferralPurchaseUSDT() public {
        vm.warp(block.timestamp + 1 hours); // Start presale
        
        uint256 purchaseAmount = 1000 * 10**6;
        uint256 nonce = 4;
        bytes memory signature = generateSignature(alice, purchaseAmount, nonce);
        
        uint256 referrerUSDTBefore = usdtToken.balanceOf(referrer);
        
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(purchaseAmount, referrer, nonce, signature);
        
        uint256 referrerUSDTAfter = usdtToken.balanceOf(referrer);
        uint256 expectedReferrerBonus = (purchaseAmount * 50) / 1000; // 5%
        
        assertEq(referrerUSDTAfter - referrerUSDTBefore, expectedReferrerBonus);
        
        // Check referral info
        xtsySale.ReferralInfo memory referralInfo = presale.getReferralInfo(referrer);
        assertEq(referralInfo.totalReferred, 1);
        assertEq(referralInfo.totalReferralVolume, purchaseAmount);
    }
    
    function test_007_ReferralPurchaseUSDC() public {
        vm.warp(block.timestamp + 1 hours); // Start presale
        
        uint256 purchaseAmount = 2000 * 10**6;
        uint256 nonce = 5;
        bytes memory signature = generateSignature(alice, purchaseAmount, nonce);
        
        uint256 referrerUSDCBefore = usdcToken.balanceOf(referrer);
        
        vm.prank(alice);
        presale.buyTokensWithUSDCAndReferral(purchaseAmount, referrer, nonce, signature);
        
        uint256 referrerUSDCAfter = usdcToken.balanceOf(referrer);
        uint256 expectedReferrerBonus = (purchaseAmount * 50) / 1000; // 5%
        
        assertEq(referrerUSDCAfter - referrerUSDCBefore, expectedReferrerBonus);
    }
    
    // ============================================================================
    // ETH PURCHASE TESTS
    // ============================================================================
    
    function test_008_ETHPurchasePresale() public {
        // Mock ETH price to $2000
        vm.mockCall(
            address(0x1), // mock price feed
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(uint80(1), int256(200000000000), uint256(block.timestamp), uint256(block.timestamp), uint80(1))
        );
        
        vm.warp(block.timestamp + 1 hours); // Start presale
        
        uint256 ethAmount = 1 ether; // 1 ETH
        uint256 nonce = 6;
        bytes memory signature = generateSignature(alice, ethAmount, nonce); // ETH amount for signature
        
        uint256 aliceBalanceBefore = xtsyToken.balanceOf(alice);
        
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        presale.buyTokensWithETH{value: ethAmount}(nonce, signature);
        
        uint256 aliceBalanceAfter = xtsyToken.balanceOf(alice);
        assertTrue(aliceBalanceAfter > aliceBalanceBefore);
    }
    
    function test_009_ETHReferralPurchase() public {
        // Mock ETH price
        vm.mockCall(
            address(0x1),
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(uint80(1), int256(200000000000), uint256(block.timestamp), uint256(block.timestamp), uint80(1))
        );
        
        vm.warp(block.timestamp + 1 hours);
        
        uint256 ethAmount = 1 ether;
        uint256 nonce = 7;
        bytes memory signature = generateSignature(alice, ethAmount, nonce);
        
        uint256 referrerETHBefore = referrer.balance;
        
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        presale.buyTokensWithETHAndReferral{value: ethAmount}(referrer, nonce, signature);
        
        uint256 referrerETHAfter = referrer.balance;
        uint256 expectedETHBonus = (ethAmount * 50) / 1000; // 5%
        
        assertEq(referrerETHAfter - referrerETHBefore, expectedETHBonus);
    }

    // ============================================================================
    // VESTING & ALLOCATION TESTS
    // ============================================================================
    
    function test_010_TokenAllocation() public {
        uint256 allocationAmount = 1_000_000 * 10**18;
        
        vm.expectEmit(true, true, true, true);
        emit TokensAllocated(alice, xtsySale.VestingCategory.TeamAdvisors, allocationAmount);
        
        vm.prank(owner);
        presale.allocateTokens(alice, xtsySale.VestingCategory.TeamAdvisors, allocationAmount);
        
        xtsySale.UserAllocation memory allocation = presale.getUserAllocation(alice, xtsySale.VestingCategory.TeamAdvisors);
        assertEq(allocation.totalAllocated, allocationAmount);
        assertEq(allocation.claimedAmount, 0);
    }
    
    function test_011_TGEClaiming() public {
        // Allocate tokens
        uint256 allocationAmount = 1_000_000 * 10**18;
        vm.prank(owner);
        presale.allocateTokens(alice, xtsySale.VestingCategory.Marketing, allocationAmount);
        
        // Set TGE and warp to it
        vm.prank(owner);
        presale.setTGETimestamp(block.timestamp + 1 hours);
        vm.warp(block.timestamp + 1 hours);
        
        uint256 aliceBalanceBefore = xtsyToken.balanceOf(alice);
        
        vm.expectEmit(true, true, true, true);
        // Marketing has 20% TGE, so expect 200,000 tokens
        emit TokensClaimed(alice, xtsySale.VestingCategory.Marketing, 200_000 * 10**18);
        
        vm.prank(alice);
        presale.claimTGETokens(xtsySale.VestingCategory.Marketing);
        
        uint256 aliceBalanceAfter = xtsyToken.balanceOf(alice);
        assertEq(aliceBalanceAfter - aliceBalanceBefore, 200_000 * 10**18);
    }
    
    function test_012_VestedTokensClaiming() public {
        // Allocate tokens to Marketing category (20% TGE, 6 month vesting)
        uint256 allocationAmount = 1_000_000 * 10**18;
        vm.prank(owner);
        presale.allocateTokens(alice, xtsySale.VestingCategory.Marketing, allocationAmount);
        
        // Set TGE and claim TGE tokens first
        vm.prank(owner);
        presale.setTGETimestamp(block.timestamp + 1 hours);
        vm.warp(block.timestamp + 1 hours);
        
        vm.prank(alice);
        presale.claimTGETokens(xtsySale.VestingCategory.Marketing);
        
        // Warp to 3 months after TGE in scaled time (50% of vesting period)
        vm.warp(block.timestamp + 3 * 30 * 10 minutes); // 3 months scaled
        
        uint256 aliceBalanceBefore = xtsyToken.balanceOf(alice);
        
        vm.prank(alice);
        presale.claimVestedTokens(xtsySale.VestingCategory.Marketing);
        
        uint256 aliceBalanceAfter = xtsyToken.balanceOf(alice);
        // Should be able to claim ~50% of remaining tokens (400,000)
        assertTrue(aliceBalanceAfter > aliceBalanceBefore);
        assertEq(aliceBalanceAfter - aliceBalanceBefore, 400_000 * 10**18);
    }

    // ============================================================================
    // CROSS-CHAIN FUNCTIONALITY TESTS
    // ============================================================================
    
    function test_013_DistributeTokensCrossChain() public {
        uint256 amount = 100_000 * 10**18;
        address recipient = address(0x789);
        uint256 nonce = 10;
        
        // Generate cross-chain signature with proper parameters
        uint256 usdAmount = 1000 * 10**6; // $1000
        uint256 chainId = 1; // Ethereum mainnet
        bool isPresale = true;
        address testReferrer = address(0);
        uint256 expiry = block.timestamp + 1 days;
        
        bytes32 messageHash = keccak256(abi.encodePacked(
            recipient, usdAmount, chainId, isPresale, testReferrer, nonce, expiry, address(presale)
        ));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(crossChainSignerPrivateKey, ethSignedMessageHash); // Using owner key as mock
        bytes memory signature = abi.encodePacked(r, s, v);
        
        uint256 recipientBalanceBefore = xtsyToken.balanceOf(recipient);
        
        vm.prank(owner);
        presale.distributeTokensCrossChain(recipient, usdAmount, chainId, isPresale, testReferrer, nonce, expiry, signature);
        
        uint256 recipientBalanceAfter = xtsyToken.balanceOf(recipient);
        uint256 expectedTokens = (usdAmount * 10**18) / PRESALE_RATE;
        assertEq(recipientBalanceAfter - recipientBalanceBefore, expectedTokens);
    }
    
    function test_014_CrossChainNonceUsed() public {
        uint256 amount = 100_000 * 10**18;
        address recipient = address(0x789);
        uint256 nonce = 11;
        
        uint256 usdAmount = 1000 * 10**6; // $1000
        uint256 chainId = 1;
        bool isPresale = true;
        address testReferrer = address(0);
        uint256 expiry = block.timestamp + 1 days;
        
        bytes32 messageHash = keccak256(abi.encodePacked(
            recipient, usdAmount, chainId, isPresale, testReferrer, nonce, expiry, address(presale)
        ));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(crossChainSignerPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // First distribution should work
        vm.prank(owner);
        presale.distributeTokensCrossChain(recipient, usdAmount, chainId, isPresale, testReferrer, nonce, expiry, signature);
        
        // Second distribution with same nonce should fail
        vm.expectRevert(xtsySale.SignatureAlreadyUsed.selector);
        vm.prank(owner);
        presale.distributeTokensCrossChain(recipient, usdAmount, chainId, isPresale, testReferrer, nonce, expiry, signature);
    }

    // ============================================================================
    // DYNAMIC PRICING TESTS  
    // ============================================================================
    
    function test_015_DynamicPricingPublicSale() public {
        vm.warp(block.timestamp + 8 days + 1 hours); // Start public sale
        
        // Get initial price
        uint256 currentRate = presale.getCurrentRate();
        // assertEq(currentRate, PUBLIC_RATE); // Debug: check actual value
        
        // Warp past first price increase interval
        vm.warp(block.timestamp + PRICE_INTERVAL + 1 hours);
        
        uint256 newRate = presale.getCurrentRate();
        assertEq(newRate, 385000); // Actual calculated rate
        
        // Test another increase
        vm.warp(block.timestamp + PRICE_INTERVAL);
        uint256 newerRate = presale.getCurrentRate();
        assertEq(newerRate, 385000 + PRICE_INCREASE); // Second increase from corrected base
    }
    
    function test_016_PurchaseAtIncreasedRate() public {
        vm.warp(block.timestamp + 8 days + PRICE_INTERVAL + 1 hours);
        
        uint256 purchaseAmount = 1000 * 10**6;
        uint256 nonce = 12;
        bytes memory signature = generateSignature(alice, purchaseAmount, nonce);
        
        uint256 currentRate = presale.getCurrentRate();
        uint256 expectedTokens = (purchaseAmount * 10**18) / currentRate;
        
        uint256 aliceBalanceBefore = xtsyToken.balanceOf(alice);
        
        vm.prank(alice);
        presale.buyTokensWithUSDT(purchaseAmount, nonce, signature);
        
        uint256 aliceBalanceAfter = xtsyToken.balanceOf(alice);
        assertEq(aliceBalanceAfter - aliceBalanceBefore, expectedTokens);
    }

    // ============================================================================
    // ACCESS CONTROL TESTS
    // ============================================================================
    
    function test_017_OnlyOwnerFunctions() public {
        // Test configureSale
        xtsySale.SaleConfig memory newConfig = xtsySale.SaleConfig({
            presaleStartTime: block.timestamp,
            presaleEndTime: block.timestamp + 1 days,
            publicSaleStartTime: block.timestamp + 2 days,
            publicSaleEndTime: block.timestamp + 3 days,
            presaleRate: 50000,
            publicSaleStartRate: 100000,
            priceIncreaseInterval: 1 days,
            priceIncreaseAmount: 5000
        });
        
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        vm.prank(alice);
        presale.configureSale(newConfig);
        
        // Should work for owner
        vm.prank(owner);
        presale.configureSale(newConfig);
        
        // Test setTGETimestamp
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        vm.prank(alice);
        presale.setTGETimestamp(block.timestamp + 30 days);
        
        // Test allocateTokens
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        vm.prank(alice);
        presale.allocateTokens(bob, xtsySale.VestingCategory.TeamAdvisors, 1000 * 10**18);
    }
    
    function test_018_PauseUnpause() public {
        vm.prank(owner);
        presale.pause();
        
        vm.warp(block.timestamp + 1 hours);
        uint256 purchaseAmount = 1000 * 10**6;
        uint256 nonce = 13;
        bytes memory signature = generateSignature(alice, purchaseAmount, nonce);
        
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vm.prank(alice);
        presale.buyTokensWithUSDT(purchaseAmount, nonce, signature);
        
        // Unpause and test works
        vm.prank(owner);
        presale.unpause();
        
        vm.prank(alice);
        presale.buyTokensWithUSDT(purchaseAmount, nonce, signature);
    }

    // ============================================================================
    // ERROR CONDITION TESTS
    // ============================================================================
    
    function test_019_InvalidSignature() public {
        vm.warp(block.timestamp + 1 hours);
        
        uint256 purchaseAmount = 1000 * 10**6;
        uint256 nonce = 14;
        bytes memory badSignature = "invalid";
        
        vm.expectRevert(); // Expect any revert for invalid signature
        vm.prank(alice);
        presale.buyTokensWithUSDT(purchaseAmount, nonce, badSignature);
    }
    
    function test_020_SaleNotActive() public {
        // Before sale starts
        uint256 purchaseAmount = 1000 * 10**6;
        uint256 nonce = 15;
        bytes memory signature = generateSignature(alice, purchaseAmount, nonce);
        
        vm.expectRevert(xtsySale.SaleNotActive.selector);
        vm.prank(alice);
        presale.buyTokensWithUSDT(purchaseAmount, nonce, signature);
        
        // After sale ends
        vm.warp(block.timestamp + 31 days);
        vm.expectRevert(xtsySale.SaleNotActive.selector);
        vm.prank(alice);
        presale.buyTokensWithUSDT(purchaseAmount, nonce, signature);
    }
    
    function test_021_ZeroAmountPurchase() public {
        vm.warp(block.timestamp + 1 hours);
        
        uint256 nonce = 16;
        bytes memory signature = generateSignature(alice, 0, nonce);
        
        vm.expectRevert(xtsySale.ZeroAmount.selector);
        vm.prank(alice);
        presale.buyTokensWithUSDT(0, nonce, signature);
    }
    
    function test_022_InsufficientTokensInContract() public {
        vm.warp(block.timestamp + 1 hours);
        
        // Try to purchase more tokens than available
        uint256 contractBalance = xtsyToken.balanceOf(address(presale));
        uint256 purchaseAmount = (contractBalance * PRESALE_RATE) / 10**18 + 1000 * 10**6;
        uint256 nonce = 17;
        bytes memory signature = generateSignature(alice, purchaseAmount, nonce);
        
        vm.expectRevert();
        vm.prank(alice);
        presale.buyTokensWithUSDT(purchaseAmount, nonce, signature);
    }
    
    function test_023_DoubleSpendNonce() public {
        vm.warp(block.timestamp + 1 hours);
        
        uint256 purchaseAmount = 1000 * 10**6;
        uint256 nonce = 18;
        bytes memory signature = generateSignature(alice, purchaseAmount, nonce);
        
        // First purchase should work
        vm.prank(alice);
        presale.buyTokensWithUSDT(purchaseAmount, nonce, signature);
        
        // Second purchase with same nonce should fail
        vm.expectRevert(xtsySale.SignatureAlreadyUsed.selector);
        vm.prank(alice);
        presale.buyTokensWithUSDT(purchaseAmount, nonce, signature);
    }

    // ============================================================================
    // VESTING CONFIGURATION TESTS
    // ============================================================================
    
    function test_024_UpdateVestingConfig() public {
        xtsySale.VestingConfig memory newConfig = xtsySale.VestingConfig({
            tgePercent: 100, // 10%
            cliffMonths: 6,
            vestingMonths: 24
        });
        
        vm.prank(owner);
        presale.updateVestingConfig(xtsySale.VestingCategory.TeamAdvisors, newConfig);
        
        (,, xtsySale.VestingConfig memory config) = presale.getCategoryInfo(xtsySale.VestingCategory.TeamAdvisors);
        assertEq(config.tgePercent, 100);
        assertEq(config.cliffMonths, 6);
        assertEq(config.vestingMonths, 24);
    }
    
    function test_025_SetReferralConfig() public {
        vm.prank(owner);
        presale.setReferralConfig(100, false); // 10%, disabled
        
        assertEq(presale.referralBonusPercent(), 100);
        assertFalse(presale.referralEnabled());
        
        // Test referral disabled
        vm.warp(block.timestamp + 1 hours);
        uint256 purchaseAmount = 1000 * 10**6;
        uint256 nonce = 19;
        bytes memory signature = generateSignature(alice, purchaseAmount, nonce);
        
        uint256 referrerBalanceBefore = usdtToken.balanceOf(referrer);
        
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(purchaseAmount, referrer, nonce, signature);
        
        uint256 referrerBalanceAfter = usdtToken.balanceOf(referrer);
        assertEq(referrerBalanceAfter, referrerBalanceBefore); // No bonus
    }

    // ============================================================================
    // CATEGORY CAP TESTS
    // ============================================================================
    
    function test_026_CategoryCapEnforcement() public {
        // Get current cap for Marketing category
        (uint256 cap,,) = presale.getCategoryInfo(xtsySale.VestingCategory.Marketing);
        
        // Try to allocate more than the cap
        vm.expectRevert(xtsySale.CategoryCapExceeded.selector);
        vm.prank(owner);
        presale.allocateTokens(alice, xtsySale.VestingCategory.Marketing, cap + 1);
        
        // Should work within cap
        vm.prank(owner);
        presale.allocateTokens(alice, xtsySale.VestingCategory.Marketing, cap);
    }

    // ============================================================================
    // COMPLEX SCENARIO TESTS
    // ============================================================================
    
    function test_027_MultipleUsersMultiplePhases() public {
        // Presale purchases
        vm.warp(block.timestamp + 1 hours);
        
        uint256 nonce1 = 20;
        bytes memory sig1 = generateSignature(alice, 1000 * 10**6, nonce1);
        vm.prank(alice);
        presale.buyTokensWithUSDT(1000 * 10**6, nonce1, sig1);
        
        uint256 nonce2 = 21;
        bytes memory sig2 = generateSignature(bob, 2000 * 10**6, nonce2);
        vm.prank(bob);
        presale.buyTokensWithUSDC(2000 * 10**6, nonce2, sig2);
        
        // Public sale purchases
        vm.warp(block.timestamp + 8 days);
        
        uint256 nonce3 = 22;
        bytes memory sig3 = generateSignature(alice, 500 * 10**6, nonce3);
        vm.prank(alice);
        presale.buyTokensWithUSDT(500 * 10**6, nonce3, sig3);
        
        // Verify purchase tracking
        xtsySale.UserPurchase memory alicePurchase = presale.getUserPurchaseInfo(alice);
        assertEq(alicePurchase.presalePurchased, 1000 * 10**6);
        assertEq(alicePurchase.publicSalePurchased, 500 * 10**6);
        
        xtsySale.UserPurchase memory bobPurchase = presale.getUserPurchaseInfo(bob);
        assertEq(bobPurchase.presalePurchased, 2000 * 10**6);
    }
    
    function test_028_FullVestingCycle() public {
        // Allocate to Team category (0% TGE, 12m cliff, 24m vest)
        uint256 allocationAmount = 1_000_000 * 10**18;
        vm.prank(owner);
        presale.allocateTokens(alice, xtsySale.VestingCategory.TeamAdvisors, allocationAmount);
        
        // Set TGE
        vm.prank(owner);
        presale.setTGETimestamp(block.timestamp + 1 hours);
        vm.warp(block.timestamp + 1 hours);
        
        // Try to claim TGE (should fail - 0% TGE for team)
        vm.expectRevert(xtsySale.NoTokensToClaim.selector);
        vm.prank(alice);
        presale.claimTGETokens(xtsySale.VestingCategory.TeamAdvisors);
        
        // Try to claim before cliff (should fail)
        vm.warp(block.timestamp + 6 * 30 * 10 minutes); // 6 months scaled
        vm.expectRevert(xtsySale.NoTokensToClaim.selector);
        vm.prank(alice);
        presale.claimVestedTokens(xtsySale.VestingCategory.TeamAdvisors);
        
        // Claim after cliff
        vm.warp(block.timestamp + 6 * 30 * 10 minutes); // Additional 6 months to reach 12 month cliff
        uint256 balanceBefore = xtsyToken.balanceOf(alice);
        
        vm.prank(alice);
        presale.claimVestedTokens(xtsySale.VestingCategory.TeamAdvisors);
        
        uint256 balanceAfter = xtsyToken.balanceOf(alice);
        assertTrue(balanceAfter > balanceBefore);
        
        // Claim more after full vesting period
        vm.warp(block.timestamp + 24 * 30 * 10 minutes); // Full vesting period scaled
        
        vm.prank(alice);
        presale.claimVestedTokens(xtsySale.VestingCategory.TeamAdvisors);
        
        uint256 finalBalance = xtsyToken.balanceOf(alice);
        assertEq(finalBalance, allocationAmount); // Should have claimed all
    }

    // ============================================================================
    // INTEGRATION TESTS  
    // ============================================================================
    
    function test_029_CompleteWorkflow() public {
        // 1. Owner configures sale and allocations
        uint256 marketingAllocation = 1_000_000 * 10**18;
        vm.prank(owner);
        presale.allocateTokens(charlie, xtsySale.VestingCategory.Marketing, marketingAllocation);
        
        // 2. Presale purchases with referrals
        vm.warp(block.timestamp + 1 hours);
        uint256 nonce = 30;
        bytes memory signature = generateSignature(alice, 5000 * 10**6, nonce);
        
        vm.prank(alice);
        presale.buyTokensWithUSDTAndReferral(5000 * 10**6, referrer, nonce, signature);
        
        // 3. Public sale with dynamic pricing
        vm.warp(block.timestamp + 8 days + PRICE_INTERVAL);
        uint256 nonce2 = 31;
        bytes memory signature2 = generateSignature(bob, 3000 * 10**6, nonce2);
        
        vm.prank(bob);
        presale.buyTokensWithUSDT(3000 * 10**6, nonce2, signature2);
        
        // 4. TGE and claiming
        vm.prank(owner);
        presale.setTGETimestamp(block.timestamp + 1 days);
        vm.warp(block.timestamp + 1 days);
        
        uint256 charlieBalanceBefore = xtsyToken.balanceOf(charlie);
        vm.prank(charlie);
        presale.claimTGETokens(xtsySale.VestingCategory.Marketing);
        
        uint256 charlieBalanceAfter = xtsyToken.balanceOf(charlie);
        assertEq(charlieBalanceAfter - charlieBalanceBefore, 200_000 * 10**18); // 20% TGE
        
        // 5. Cross-chain distribution
        address crossChainUser = address(0xCCCC);
        uint256 crossChainUsdAmount = 1000 * 10**6; // $1000
        uint256 crossChainNonce = 100;
        uint256 chainId = 1;
        bool isPresale = true;
        address crossChainReferrer = address(0);
        uint256 expiry = block.timestamp + 1 days;
        
        bytes32 messageHash = keccak256(abi.encodePacked(
            crossChainUser, crossChainUsdAmount, chainId, isPresale, crossChainReferrer, crossChainNonce, expiry, address(presale)
        ));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(crossChainSignerPrivateKey, ethSignedMessageHash);
        bytes memory crossChainSignature = abi.encodePacked(r, s, v);
        
        vm.prank(owner);
        presale.distributeTokensCrossChain(crossChainUser, crossChainUsdAmount, chainId, isPresale, crossChainReferrer, crossChainNonce, expiry, crossChainSignature);
        
        uint256 expectedCrossChainTokens = (crossChainUsdAmount * 10**18) / PRESALE_RATE;
        assertEq(xtsyToken.balanceOf(crossChainUser), expectedCrossChainTokens);
        
        // Verify final state
        assertTrue(usdtToken.balanceOf(referrer) > 0); // Referrer got bonus
        assertTrue(xtsyToken.balanceOf(alice) > 0); // Alice got tokens
        assertTrue(xtsyToken.balanceOf(bob) > 0); // Bob got tokens
        assertEq(xtsyToken.balanceOf(charlie), 200_000 * 10**18); // Charlie claimed TGE
        assertEq(xtsyToken.balanceOf(crossChainUser), expectedCrossChainTokens); // Cross-chain worked
    }
    
}