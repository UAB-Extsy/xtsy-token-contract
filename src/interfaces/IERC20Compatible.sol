// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ERC20 Compatible Interface
 * @notice USDT-compatible ERC20 interface (no return values from transfer functions)
 * @dev This interface works with all ERC20 variants including USDT, USDC, DAI, etc.
 */
interface IERC20Compatible {
    function transfer(address to, uint256 value) external;
    function transferFrom(address from, address to, uint256 value) external;
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}