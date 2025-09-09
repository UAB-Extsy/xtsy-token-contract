// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/xtsySaleBNB.sol";
import {MockUSDT} from "../src/mocks/MockUSDT.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

contract BNBSaleTest is Test {
    xtsySaleBNB public presale;
    MockUSDT public usdtToken;
    MockUSDC public usdcToken;
    
    // Private key for owner (used for signing)
    uint256 ownerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public owner = vm.addr(ownerPrivateKey);
    address public alice = address(2);
    address public bob = address(3);
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy tokens
        usdtToken = new MockUSDT();
        usdcToken = new MockUSDC();
        
        // Deploy BNB presale (mock price feed address)
        presale = new xtsySaleBNB(
            address(usdtToken),
            address(usdcToken),
            address(0x1), // mock price feed address
            owner,
            owner  // backend signer
        );
        
        // Configure sale with scaled times
        xtsySaleBNB.SaleConfig memory config = xtsySaleBNB.SaleConfig({
            presaleStartTime: block.timestamp + 25 seconds,
            presaleEndTime: block.timestamp + 50 minutes,
            publicSaleStartTime: block.timestamp + 60 minutes,
            publicSaleEndTime: block.timestamp + 130 minutes,
            presaleRate: 100000,        // $0.10 per token
            publicSaleStartRate: 350000, // $0.35 per token
            priceIncreaseInterval: 6 days,
            priceIncreaseAmount: 17500 // 5% increase ($0.0175)
        });
        
        presale.configureSale(config);
        
        // Mint tokens for test users
        usdtToken.mint(alice, 10000 * 10**6);  // $10,000
        usdcToken.mint(alice, 10000 * 10**6);  // $10,000
        
        vm.stopPrank();
    }
    
    function generateSignature(address user, uint256 amount, uint256 nonce) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encodePacked(user, amount, nonce, address(presale)));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }
    
    function testBasicSetup() public {
        // Check initial stats - BNB contract only tracks volume, not caps
        (uint256 totalPresaleVolume, uint256 totalPublicVolume,,,,) = presale.getContractStats();
        assertEq(totalPresaleVolume, 0);
        assertEq(totalPublicVolume, 0);
        
        // Check backend signer is set
        assertEq(presale.backendSigner(), owner);
    }
    
    function testUSDTPurchase() public {
        vm.warp(block.timestamp + 25 seconds); // Start presale
        
        uint256 purchaseAmount = 1000 * 10**6; // $1000
        uint256 expectedTokens = (purchaseAmount * 10**18) / 100000; // 10,000 XTSY
        uint256 nonce = 1;
        bytes memory signature = generateSignature(alice, purchaseAmount, nonce);
        
        vm.startPrank(alice);
        usdtToken.approve(address(presale), purchaseAmount);
        
        presale.buyTokensWithUSDT(purchaseAmount, address(0), nonce, signature);
        
        // Check user purchase data (BNB contract only tracks spending)
        (xtsySaleBNB.UserPurchase memory purchase,) = presale.getUserInfo(alice);
        assertEq(purchase.presalePurchased, purchaseAmount);
        assertEq(purchase.totalUsdSpent, purchaseAmount);
        
        vm.stopPrank();
    }
    
    function testPublicSalePurchase() public {
        vm.warp(block.timestamp + 60 minutes); // Start public sale
        
        uint256 purchaseAmount = 500 * 10**6; // $500
        uint256 expectedTokens = (purchaseAmount * 10**18) / 350000; // ~1,429 XTSY at $0.35
        
        vm.startPrank(alice);
        usdcToken.approve(address(presale), purchaseAmount);
        
        // No signature needed for public sale
        presale.buyTokensWithUSDC(purchaseAmount, address(0), 0, "");
        
        // Check user purchase data
        (xtsySaleBNB.UserPurchase memory purchase,) = presale.getUserInfo(alice);
        assertEq(purchase.publicSalePurchased, purchaseAmount);
        assertEq(purchase.totalUsdSpent, purchaseAmount);
        
        vm.stopPrank();
    }
    
    function testReferralPurchase() public {
        vm.warp(block.timestamp + 60 minutes); // Start public sale
        
        uint256 purchaseAmount = 1000 * 10**6; // $1000
        uint256 expectedTokens = (purchaseAmount * 10**18) / 350000; // ~2,857 XTSY at $0.35
        uint256 expectedReferralBonus = (expectedTokens * 50) / 1000; // 5% referral volume
        
        vm.startPrank(alice);
        usdtToken.approve(address(presale), purchaseAmount);
        
        presale.buyTokensWithUSDT(purchaseAmount, bob, 0, "");
        
        // Check buyer purchase data
        (xtsySaleBNB.UserPurchase memory purchase,) = presale.getUserInfo(alice);
        assertEq(purchase.publicSalePurchased, purchaseAmount);
        assertEq(purchase.referrer, bob);
        
        // Check referrer info (BNB contract only tracks referral volume, no bonus tokens)
        (, xtsySaleBNB.ReferralInfo memory refInfo) = presale.getUserInfo(bob);
        assertEq(refInfo.totalReferred, 1);
        assertEq(refInfo.totalReferralVolume, purchaseAmount);
        
        vm.stopPrank();
    }
    
    function testContractStats() public {
        vm.warp(block.timestamp + 25 seconds); // Start presale
        
        uint256 purchaseAmount = 1000 * 10**6;
        uint256 nonce = 1;
        bytes memory signature = generateSignature(alice, purchaseAmount, nonce);
        
        vm.startPrank(alice);
        usdtToken.approve(address(presale), purchaseAmount);
        presale.buyTokensWithUSDT(purchaseAmount, address(0), nonce, signature);
        vm.stopPrank();
        
        (
            uint256 totalPresaleSold,
            uint256 totalPublicSaleSold,
            uint256 totalUsdtRaised,
            uint256 totalUsdcRaised,
            uint256 totalBnbRaised,
            xtsySaleBNB.SalePhase currentPhase
        ) = presale.getContractStats();
        
        assertTrue(totalPresaleSold > 0);
        assertEq(totalPublicSaleSold, 0);
        assertEq(totalUsdtRaised, purchaseAmount);
        assertEq(totalUsdcRaised, 0);
        assertEq(totalBnbRaised, 0);
        assertEq(uint8(currentPhase), uint8(xtsySaleBNB.SalePhase.PresaleWhitelist));
    }
}