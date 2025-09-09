# XTSY Token

A professional ERC20 token implementation with capped supply, burnable functionality, and comprehensive security features.

## Features

- **ERC20 Standard**: Fully compliant with ERC20 token standard
- **Capped Supply**: Maximum supply of 500 million XTSY tokens
- **Burnable**: Token holders can burn their tokens using OpenZeppelin ERC20Burnable
- **Mintable**: Only contract owner can mint new tokens (up to cap)
- **Automatic Distribution**: All tokens are distributed at deployment according to tokenomics
- **Ownership Control**: Secure ownership transfer mechanism
- **Comprehensive Events**: Detailed event emissions for all operations
- **Security Features**: Custom error handling and input validation

## Token Details

- **Name**: XTSY
- **Symbol**: XTSY
- **Decimals**: 18
- **Max Supply**: 500,000,000 XTSY (500 million tokens)
- **Initial Supply**: 500,000,000 XTSY (all tokens distributed at deployment)

## Token Distribution

| Allocation      | Percentage | Amount (XTSY) | Description                              |
| --------------- | ---------- | ------------- | ---------------------------------------- |
| Presale         | 2%         | 10,000,000    | Distributed during presale phases        |
| Public Sale     | 6%         | 30,000,000    | Distributed during public sale phases    |
| Liquidity       | 7%         | 35,000,000    | Liquidity & market making allocation     |
| Team & Advisors | 15%        | 75,000,000    | Team allocation (should be vested)       |
| Ecosystem       | 20%        | 100,000,000   | Ecosystem growth and development         |
| Treasury        | 25%        | 125,000,000   | Protocol treasury for future development |
| Staking         | 15%        | 75,000,000    | Staking rewards and incentives           |
| Marketing       | 10%        | 50,000,000    | Marketing & partnerships allocation      |

## Contract Architecture

### Inheritance

- `ERC20Capped`: Provides capped token supply functionality
- `ERC20Burnable`: Allows token burning (OpenZeppelin standard)
- `Ownable`: Provides ownership control

### Key Functions

#### Owner Functions

- `mint(address to, uint256 amount)`: Mint additional tokens to specified address
- `transferOwnership(address newOwner)`: Transfer contract ownership
- `renounceOwnership()`: Renounce ownership

#### User Functions

- `burn(uint256 amount)`: Burn tokens from caller's balance (OpenZeppelin)
- `burnFrom(address account, uint256 amount)`: Burn tokens from specified account (requires allowance)

#### View Functions

- `MAX_SUPPLY`: Get the maximum supply cap (500M XTSY)
- `totalSupply()`: Get current total supply
- `balanceOf(address account)`: Get token balance of account
- `cap()`: Get the maximum supply cap

## Development Setup

### Prerequisites

- [Foundry](https://github.com/foundry-rs/foundry)
- Node.js (for additional tooling)

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd extsy-token

# Install dependencies
forge install

# Build contracts
forge build
```

### Testing

Run the comprehensive test suite:

```bash
# Run all tests
forge test

# Run tests with verbose output
forge test -vvv

# Run specific test file
forge test --match-contract ExtsyTokenTest

# Run integration tests
forge test --match-contract ExtsyTokenIntegrationTest

# Generate test coverage report
forge coverage
```

### Deployment

1. Copy the environment template:

```bash
cp .env.example .env
```

2. Edit `.env` with your deployment parameters:

   - `PRIVATE_KEY`: Your deployment wallet private key
   - `INITIAL_OWNER`: Address that will own the contract
   - `PRESALE_ADDRESS`: Address for presale allocation (10M XTSY)
   - `PUBLIC_SALE_ADDRESS`: Address for public sale allocation (30M XTSY)
   - `LIQUIDITY_ADDRESS`: Address for liquidity allocation (35M XTSY)
   - `TEAM_ADVISORS_ADDRESS`: Address for team allocation (75M XTSY)
   - `ECOSYSTEM_ADDRESS`: Address for ecosystem allocation (100M XTSY)
   - `TREASURY_ADDRESS`: Address for treasury allocation (125M XTSY)
   - `STAKING_ADDRESS`: Address for staking allocation (75M XTSY)
   - `MARKETING_ADDRESS`: Address for marketing allocation (50M XTSY)
   - `<NETWORK>_RPC_URL`: RPC endpoint for target network

3. Deploy to local testnet:

```bash
forge script script/DeployExtsyToken.s.sol --fork-url http://localhost:8545 --broadcast
```

4. Deploy to testnet (e.g., Sepolia):

```bash
forge script script/DeployExtsyToken.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

5. Deploy to mainnet:

```bash
forge script script/DeployExtsyToken.s.sol --rpc-url $ETHEREUM_RPC_URL --broadcast --verify
```

## Security Features

### Access Control

- Only contract owner can mint additional tokens
- Ownership can be transferred or renounced
- All privileged functions are protected by `onlyOwner` modifier

### Supply Management

- Hard cap of 500 million tokens enforced at contract level
- Tokens can be burned but never created beyond cap
- Minting automatically checks against remaining supply
- All tokens are distributed at deployment according to tokenomics

### Input Validation

- Zero address validation for minting
- Custom error messages for better debugging
- OpenZeppelin's battle-tested burnable implementation

### Custom Errors

- Gas-efficient custom errors instead of revert strings
- Clear error messages for different failure scenarios

## Gas Optimization

- OpenZeppelin's optimized ERC20 implementation
- Custom errors save gas compared to revert strings
- Efficient supply tracking with cached calculations
- Immutable allocation addresses for gas efficiency

## Testing Strategy

### Unit Tests (`ExtsyToken.t.sol`)

- Basic functionality testing
- Access control verification
- Edge case handling
- Fuzz testing for random inputs

### Integration Tests (`ExtsyToken.integration.t.sol`)

- Complex multi-step scenarios
- Gas optimization validation
- Large-scale operation testing
- Cross-function interaction testing

### Test Helpers (`TestHelpers.sol`)

- Common test utilities
- Address and amount generators
- Gas measurement tools
- Balance assertion helpers

## Events

The contract emits the following events:

### Standard ERC20 Events

- `Transfer(address indexed from, address indexed to, uint256 value)`
- `Approval(address indexed owner, address indexed spender, uint256 value)`

### OpenZeppelin Events

- `OwnershipTransferred(address indexed previousOwner, address indexed newOwner)`

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## Security Considerations

- Always verify the contract address before interacting
- The owner has minting privileges - ensure secure key management
- Contract is immutable once deployed - thoroughly test before mainnet deployment
- Consider timelock mechanisms for additional security in production
- All allocation addresses are validated during deployment

## Support

For questions, issues, or contributions, please open an issue on the repository.
