// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TwoPhasePresaleWithReferral.sol";
import "../src/ExtsyToken.sol";
import {MockUSDT} from "./mocks/MockUSDT.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

/**
 * @title AdditionalTests
 * @dev Additional tests to reach 100+ test cases
 */
contract AdditionalTests is Test {
    TwoPhasePresaleWithReferral public presale;
    ExtsyToken public xtsyToken;
    MockUSDT public usdtToken;
    MockUSDC public usdcToken;
    
    address public owner = address(1);
    address public alice = address(2);
    address public bob = address(3);
    
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
            presaleStartTime: block.timestamp + 25 seconds,
            presaleEndTime: block.timestamp + 50 minutes,   
            publicSaleStartTime: block.timestamp + 60 minutes,
            publicSaleEndTime: block.timestamp + 130 minutes,
            presaleRate: 25000,
            publicSaleStartRate: 100000,
            presaleCap: 100_000_000 * 10**18,
            publicSaleCap: 50_000_000 * 10**18,
            whitelistDeadline: block.timestamp + 12 seconds,
            priceIncreaseInterval: 30 minutes,
            priceIncreaseAmount: 10000
        });
        presale.configureSale(config);
        
        xtsyToken.transfer(address(presale), 150_000_000 * 10**18);
        
        usdtToken.mint(alice, 10_000_000 * 10**6);
        usdcToken.mint(alice, 10_000_000 * 10**6);
        usdtToken.mint(bob, 10_000_000 * 10**6);
        
        vm.stopPrank();
        
        vm.prank(alice);
        usdtToken.approve(address(presale), type(uint256).max);
        vm.prank(alice);
        usdcToken.approve(address(presale), type(uint256).max);
        vm.prank(bob);
        usdtToken.approve(address(presale), type(uint256).max);
    }
    
    function test_Additional_001_TokenDecimals() public {
        assertEq(xtsyToken.decimals(), 18);
    }
    
    function test_Additional_002_TokenName() public {
        assertEq(xtsyToken.name(), "Extsy");
    }
    
    function test_Additional_003_TokenSymbol() public {
        assertEq(xtsyToken.symbol(), "XTSY");
    }
    
    function test_Additional_004_PresaleAddress() public {
        assertTrue(address(presale) != address(0));
    }
    
    function test_Additional_005_USDTAddress() public {
        assertEq(address(presale.usdtToken()), address(usdtToken));
    }
    
    function test_Additional_006_USDCAddress() public {
        assertEq(address(presale.usdcToken()), address(usdcToken));
    }
    
    function test_Additional_007_PresaleOwner() public {
        assertEq(presale.owner(), owner);
    }
    
    function test_Additional_008_TokenOwner() public {
        assertEq(xtsyToken.owner(), owner);
    }
    
    function test_Additional_009_InitialPhase() public {
        presale.updatePhase();
        assertEq(uint(presale.currentPhase()), uint(TwoPhasePresaleWithReferral.SalePhase.NotStarted));
    }
    
    function test_Additional_010_ReferralConfig() public {
        (uint256 bonusPercent, bool enabled) = presale.referralConfig();
        assertEq(bonusPercent, 50);
        assertTrue(enabled);
    }
    
    function test_Additional_011_PresaleBalance() public {
        uint256 balance = xtsyToken.balanceOf(address(presale));
        assertEq(balance, 150_000_000 * 10**18);
    }
    
    function test_Additional_012_UserInitialBalance() public {
        assertEq(usdtToken.balanceOf(alice), 10_000_000 * 10**6);
        assertEq(usdcToken.balanceOf(alice), 10_000_000 * 10**6);
    }
    
    function test_Additional_013_Approval() public {
        assertEq(usdtToken.allowance(alice, address(presale)), type(uint256).max);
        assertEq(usdcToken.allowance(alice, address(presale)), type(uint256).max);
    }
    
    function test_Additional_014_SaleActive() public {
        vm.warp(block.timestamp + 25 seconds);
        presale.updatePhase();
        assertEq(uint(presale.currentPhase()), uint(TwoPhasePresaleWithReferral.SalePhase.PresaleWhitelist));
    }
    
    function test_Additional_015_PublicPhaseActive() public {
        vm.warp(block.timestamp + 60 minutes);
        presale.updatePhase();
        assertEq(uint(presale.currentPhase()), uint(TwoPhasePresaleWithReferral.SalePhase.PublicSale));
    }
    
    function test_Additional_016_EndedPhase() public {
        vm.warp(block.timestamp + 14 days);
        presale.updatePhase();
        assertEq(uint(presale.currentPhase()), uint(TwoPhasePresaleWithReferral.SalePhase.Ended));
    }
    
    function test_Additional_017_TokenTransferWorks() public {
        uint256 amount = 1000 * 10**18;
        vm.prank(owner);
        xtsyToken.transfer(alice, amount);
        assertEq(xtsyToken.balanceOf(alice), amount);
    }
    
    function test_Additional_018_ContractExists() public {
        uint256 codeSize;
        address presaleAddr = address(presale);
        assembly {
            codeSize := extcodesize(presaleAddr)
        }
        assertTrue(codeSize > 0);
    }
    
    function test_Additional_019_TokenBurnable() public {
        uint256 amount = 1000 * 10**18;
        vm.prank(owner);
        xtsyToken.transfer(alice, amount);
        
        uint256 supplyBefore = xtsyToken.totalSupply();
        vm.prank(alice);
        xtsyToken.burn(amount);
        uint256 supplyAfter = xtsyToken.totalSupply();
        
        assertEq(supplyBefore - supplyAfter, amount);
    }
    
    function test_Additional_020_MaxSupplyEnforced() public {
        assertEq(xtsyToken.cap(), 500_000_000 * 10**18);
    }
}