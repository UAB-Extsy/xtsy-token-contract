// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ExtsyToken
 * @dev ERC20 token with capped supply, burnable functionality, and mint control
 * @notice This is the official XTSY token for the Extsy ecosystem
 */
contract ExtsyToken is ERC20Capped, ERC20Burnable, Ownable {
    /// @dev Maximum supply of tokens (500 million XTSY)
    uint256 public constant MAX_SUPPLY = 500_000_000 * 10**18;

    /// @dev Token allocation percentages (in basis points, 10000 = 100%)
    uint256 public constant PRESALE_ALLOCATION = 200;           // 2%
    uint256 public constant PUBLICSALE_ALLOCATION = 600;        // 6%
    uint256 public constant LIQUIDITY_ALLOCATION = 700;         // 7%
    uint256 public constant TEAM_ADVISORS_ALLOCATION = 1500;    // 15%
    uint256 public constant ECOSYSTEM_ALLOCATION = 2000;        // 20%
    uint256 public constant TREASURY_ALLOCATION = 2500;         // 25%
    uint256 public constant STAKING_ALLOCATION = 1500;          // 15%
    uint256 public constant MARKETING_ALLOCATION = 1000;        // 10%

    /// @dev Allocation addresses
    address public immutable presaleAddress;
    address public immutable publicSaleAddress;
    address public immutable liquidityAddress;
    address public immutable teamAdvisorsAddress;
    address public immutable ecosystemAddress;
    address public immutable treasuryAddress;
    address public immutable stakingAddress;
    address public immutable marketingAddress;

    /**
     * @dev Constructor that sets up the token with initial parameters and distributes tokens
     * @param initialOwner The address that will own the contract
     * @param _presaleAddress Address for presale allocation (2% = 10M XTSY)
     * @param _publicSaleAddress Address for public sale allocation (6% = 30M XTSY)
     * @param _liquidityAddress Address for liquidity & market making allocation (7% = 35M XTSY)
     * @param _teamAdvisorsAddress Address for team & advisors allocation (15% = 75M XTSY)
     * @param _ecosystemAddress Address for ecosystem growth allocation (20% = 100M XTSY)
     * @param _treasuryAddress Address for treasury allocation (25% = 125M XTSY)
     * @param _stakingAddress Address for staking rewards allocation (15% = 75M XTSY)
     * @param _marketingAddress Address for marketing & partnerships allocation (10% = 50M XTSY)
     */
    constructor(
        address initialOwner,
        address _presaleAddress,
        address _publicSaleAddress,
        address _liquidityAddress,
        address _teamAdvisorsAddress,
        address _ecosystemAddress,
        address _treasuryAddress,
        address _stakingAddress,
        address _marketingAddress
    )
        ERC20("XTSY", "XTSY")
        ERC20Capped(MAX_SUPPLY)
        Ownable(initialOwner)
    {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }

        require(_presaleAddress != address(0), "Invalid presale address");
        require(_publicSaleAddress != address(0), "Invalid public sale address");
        require(_liquidityAddress != address(0), "Invalid liquidity address");
        require(_teamAdvisorsAddress != address(0), "Invalid team/advisors address");
        require(_ecosystemAddress != address(0), "Invalid ecosystem address");
        require(_treasuryAddress != address(0), "Invalid treasury address");
        require(_stakingAddress != address(0), "Invalid staking address");
        require(_marketingAddress != address(0), "Invalid marketing address");

        presaleAddress = _presaleAddress;
        publicSaleAddress = _publicSaleAddress;
        liquidityAddress = _liquidityAddress;
        teamAdvisorsAddress = _teamAdvisorsAddress;
        ecosystemAddress = _ecosystemAddress;
        treasuryAddress = _treasuryAddress;
        stakingAddress = _stakingAddress;
        marketingAddress = _marketingAddress;

        // Mint tokens according to tokenomics (Total: 500M XTSY)
        _mint(_presaleAddress, (MAX_SUPPLY * PRESALE_ALLOCATION) / 10000);           // 10M XTSY (2%)
        _mint(_publicSaleAddress, (MAX_SUPPLY * PUBLICSALE_ALLOCATION) / 10000);     // 30M XTSY (6%)
        _mint(_liquidityAddress, (MAX_SUPPLY * LIQUIDITY_ALLOCATION) / 10000);       // 35M XTSY (7%)
        _mint(_teamAdvisorsAddress, (MAX_SUPPLY * TEAM_ADVISORS_ALLOCATION) / 10000);// 75M XTSY (15%)
        _mint(_ecosystemAddress, (MAX_SUPPLY * ECOSYSTEM_ALLOCATION) / 10000);       // 100M XTSY (20%)
        _mint(_treasuryAddress, (MAX_SUPPLY * TREASURY_ALLOCATION) / 10000);         // 125M XTSY (25%)
        _mint(_stakingAddress, (MAX_SUPPLY * STAKING_ALLOCATION) / 10000);           // 75M XTSY (15%)
        _mint(_marketingAddress, (MAX_SUPPLY * MARKETING_ALLOCATION) / 10000);       // 50M XTSY (10%)
    }

    /**
     * @dev Mint tokens to a specific address (only owner)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Cannot mint to zero address");
        
        _mint(to, amount);
    }
    
    /**
     * @dev Internal function to update token balances with capped supply check
     * @param from Address tokens are being transferred from
     * @param to Address tokens are being transferred to  
     * @param value Amount of tokens being transferred
     */
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Capped) {
        super._update(from, to, value);
    }
}
