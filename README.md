# Extsy Token (EXT)

A professional ERC20 token implementation with capped supply, burnable functionality, and comprehensive security features.

## Features

- **ERC20 Standard**: Fully compliant with ERC20 token standard
- **Capped Supply**: Maximum supply of 1 billion EXT tokens
- **Burnable**: Token holders can burn their tokens to reduce total supply
- **Mintable**: Only contract owner can mint new tokens (up to cap)
- **Batch Operations**: Efficient batch minting functionality
- **Ownership Control**: Secure ownership transfer mechanism
- **Comprehensive Events**: Detailed event emissions for all operations
- **Security Features**: ReentrancyGuard protection and custom error handling

## Token Details

- **Name**: Extsy Token
- **Symbol**: EXT
- **Decimals**: 18
- **Max Supply**: 1,000,000,000 EXT (1 billion tokens)
- **Initial Supply**: 0 (tokens must be minted)

## Contract Architecture

### Inheritance
- `ERC20Capped`: Provides capped token supply functionality
- `ERC20Burnable`: Allows token burning
- `Ownable`: Provides ownership control
- `ReentrancyGuard`: Protects against reentrancy attacks

### Key Functions

#### Owner Functions
- `mint(address to, uint256 amount)`: Mint tokens to specified address
- `batchMint(address[] recipients, uint256[] amounts)`: Efficiently mint to multiple addresses
- `transferOwnership(address newOwner)`: Transfer contract ownership

#### User Functions
- `burn(uint256 amount)`: Burn tokens from caller's balance
- `burnFrom(address account, uint256 amount)`: Burn tokens from specified account (requires allowance)

#### View Functions
- `remainingMintableSupply()`: Get remaining tokens that can be minted
- `isCapReached()`: Check if maximum supply has been reached
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
- Only contract owner can mint tokens
- Ownership can be transferred or renounced
- All privileged functions are protected by `onlyOwner` modifier

### Supply Management
- Hard cap of 1 billion tokens enforced at contract level
- Tokens can be burned but never created beyond cap
- Minting automatically checks against remaining supply

### Reentrancy Protection
- All state-changing functions protected by `nonReentrant` modifier
- Custom error messages for better debugging

### Custom Errors
- Gas-efficient custom errors instead of revert strings
- Clear error messages for different failure scenarios

## Gas Optimization

- Batch minting reduces gas costs for multiple recipients
- Custom errors save gas compared to revert strings
- Efficient supply tracking with cached calculations

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

The contract emits the following custom events:

- `TokensMinted(address indexed to, uint256 amount, address indexed minter)`
- `TokensBurned(address indexed from, uint256 amount)`
- `OwnershipTransferInitiated(address indexed previousOwner, address indexed newOwner)`

Plus standard ERC20 events:
- `Transfer(address indexed from, address indexed to, uint256 value)`
- `Approval(address indexed owner, address indexed spender, uint256 value)`

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

## Support

For questions, issues, or contributions, please open an issue on the repository.
