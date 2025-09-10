// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ExtsyToken} from "../../src/ExtsyToken.sol";

/**
 * @title TestHelpers
 * @dev Helper contract for common test utilities and setup functions
 */
contract TestHelpers is Test {
    // Common test addresses
    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal charlie = makeAddr("charlie");
    address internal dave = makeAddr("dave");
    address internal eve = makeAddr("eve");
    
    // Common amounts
    uint256 internal constant TOKEN_CAP = 500_000_000 * 10**18;  // 500M XTSY
    uint256 internal constant MILLION_TOKENS = 1_000_000 * 10**18;
    uint256 internal constant THOUSAND_TOKENS = 1_000 * 10**18;
    uint256 internal constant HUNDRED_TOKENS = 100 * 10**18;
    uint256 internal constant TEN_TOKENS = 10 * 10**18;
    uint256 internal constant ONE_TOKEN = 1 * 10**18;
    
    // Events for testing
    event TokensMinted(address indexed to, uint256 amount, address indexed minter);
    event TokensBurned(address indexed from, uint256 amount);
    event OwnershipTransferInitiated(address indexed previousOwner, address indexed newOwner);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Deploy a new ExtsyToken with owner
     */
    function deployToken() internal returns (ExtsyToken) {
        vm.prank(owner);
        // Deploy with all allocations going to owner for test simplicity
        return new ExtsyToken(
            owner, // presale
            owner, // public sale
            owner, // liquidity  
            owner, // team advisors
            owner, // ecosystem
            owner, // treasury
            owner, // staking
            owner  // marketing
        );
    }

    /**
     * @dev Deploy token and transfer initial supply to an address
     */
    function deployTokenAndTransfer(address to, uint256 amount) internal returns (ExtsyToken) {
        ExtsyToken token = deployToken();
        
        // Transfer from owner who has all tokens
        vm.prank(owner);
        token.transfer(to, amount);
        
        return token;
    }

    /**
     * @dev Setup token with multiple users having balances
     */
    function setupTokenWithBalances() internal returns (ExtsyToken) {
        ExtsyToken token = deployToken();
        
        // Transfer from owner who has all tokens
        vm.startPrank(owner);
        token.transfer(alice, MILLION_TOKENS);
        token.transfer(bob, THOUSAND_TOKENS);
        token.transfer(charlie, HUNDRED_TOKENS);
        vm.stopPrank();
        
        return token;
    }

    /**
     * @dev Expect a revert with custom error
     */
    function expectRevertWithCustomError(bytes4 selector) internal {
        vm.expectRevert(selector);
    }

    /**
     * @dev Expect a revert with custom error and parameters
     */
    function expectRevertWithCustomError(bytes memory errorData) internal {
        vm.expectRevert(errorData);
    }

    /**
     * @dev Check token balance matches expected amount
     */
    function assertTokenBalance(ExtsyToken token, address account, uint256 expected) internal {
        assertEq(token.balanceOf(account), expected, "Token balance mismatch");
    }

    /**
     * @dev Check total supply matches expected amount
     */
    function assertTotalSupply(ExtsyToken token, uint256 expected) internal {
        assertEq(token.totalSupply(), expected, "Total supply mismatch");
    }

    /**
     * @dev Check allowance matches expected amount
     */
    function assertAllowance(ExtsyToken token, address tokenOwner, address spender, uint256 expected) internal {
        assertEq(token.allowance(tokenOwner, spender), expected, "Allowance mismatch");
    }

    /**
     * @dev Skip time forward (useful for time-based tests)
     */
    function skipTime(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
    }

    /**
     * @dev Skip blocks forward
     */
    function skipBlocks(uint256 blocks_) internal {
        vm.roll(block.number + blocks_);
    }

    /**
     * @dev Get current timestamp
     */
    function currentTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }

    /**
     * @dev Get current block number
     */
    function currentBlock() internal view returns (uint256) {
        return block.number;
    }

    /**
     * @dev Create array of addresses for batch operations
     */
    function createAddressArray(uint256 count) internal pure returns (address[] memory) {
        address[] memory addresses = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            addresses[i] = address(uint160(0x1000 + i));
        }
        return addresses;
    }

    /**
     * @dev Create array of amounts for batch operations
     */
    function createAmountArray(uint256 count, uint256 baseAmount) internal pure returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            amounts[i] = baseAmount * (i + 1);
        }
        return amounts;
    }

    /**
     * @dev Calculate total of amount array
     */
    function sumAmounts(uint256[] memory amounts) internal pure returns (uint256 total) {
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
    }

    /**
     * @dev Fund an address with ETH for gas
     */
    function fundAddress(address addr, uint256 ethAmount) internal {
        vm.deal(addr, ethAmount);
    }

    /**
     * @dev Fund multiple addresses with ETH
     */
    function fundAddresses(address[] memory addresses, uint256 ethAmount) internal {
        for (uint256 i = 0; i < addresses.length; i++) {
            fundAddress(addresses[i], ethAmount);
        }
    }

    /**
     * @dev Check if address is valid (not zero address)
     */
    function isValidAddress(address addr) internal pure returns (bool) {
        return addr != address(0);
    }

    /**
     * @dev Generate pseudo-random address (for testing only)
     */
    function randomAddress(uint256 seed) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(seed)))));
    }

    /**
     * @dev Generate pseudo-random amount (for testing only)
     */
    function randomAmount(uint256 seed, uint256 max) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(seed))) % max;
    }

    /**
     * @dev Measure gas usage of a function call
     */
    function measureGas(function() external func) internal returns (uint256 gasUsed) {
        uint256 gasBefore = gasleft();
        func();
        gasUsed = gasBefore - gasleft();
    }

    /**
     * @dev Compare gas usage between two functions
     */
    function compareGas(
        function() external funcA,
        function() external funcB
    ) internal returns (uint256 gasA, uint256 gasB, int256 difference) {
        gasA = measureGas(funcA);
        gasB = measureGas(funcB);
        difference = int256(gasA) - int256(gasB);
    }
}