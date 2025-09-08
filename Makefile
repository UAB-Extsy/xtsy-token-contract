# Extsy Token Development Makefile
.PHONY: help build test coverage clean deploy-local deploy-sepolia deploy-mainnet format lint

# Default target
help:
	@echo "Available targets:"
	@echo "  build          - Compile all contracts"
	@echo "  test           - Run all tests"
	@echo "  test-unit      - Run unit tests only"
	@echo "  test-integration - Run integration tests only"
	@echo "  coverage       - Generate test coverage report"
	@echo "  format         - Format Solidity files"
	@echo "  lint           - Run linter (slither if available)"
	@echo "  clean          - Clean build artifacts"
	@echo "  install        - Install dependencies"
	@echo "  deploy-local   - Deploy to local Anvil"
	@echo "  deploy-sepolia - Deploy to Sepolia testnet"
	@echo "  deploy-mainnet - Deploy to Ethereum mainnet"
	@echo "  verify         - Verify contract on Etherscan"
	@echo "  gas-report     - Generate gas usage report"

# Build targets
install:
	forge install

build:
	forge build

clean:
	forge clean
	rm -rf cache/ out/

# Testing targets
test:
	forge test

test-unit:
	forge test --match-contract ExtsyTokenTest

test-integration:
	forge test --match-contract ExtsyTokenIntegrationTest

test-verbose:
	forge test -vvv

coverage:
	forge coverage

gas-report:
	forge test --gas-report

# Code quality targets
format:
	forge fmt

lint:
	@if command -v slither >/dev/null 2>&1; then \
		slither src/ExtsyToken.sol; \
	else \
		echo "Slither not installed. Install with: pip install slither-analyzer"; \
	fi

# Deployment targets
deploy-local:
	forge script script/DeployExtsyToken.s.sol --fork-url http://localhost:8545 --broadcast

deploy-sepolia:
	@if [ -z "$$SEPOLIA_RPC_URL" ]; then \
		echo "Error: SEPOLIA_RPC_URL not set in .env"; \
		exit 1; \
	fi
	forge script script/DeployExtsyToken.s.sol --rpc-url $$SEPOLIA_RPC_URL --broadcast --verify

deploy-mainnet:
	@if [ -z "$$ETHEREUM_RPC_URL" ]; then \
		echo "Error: ETHEREUM_RPC_URL not set in .env"; \
		exit 1; \
	fi
	@echo "WARNING: Deploying to mainnet. Press Ctrl+C to cancel, or wait 10 seconds to continue..."
	@sleep 10
	forge script script/DeployExtsyToken.s.sol --rpc-url $$ETHEREUM_RPC_URL --broadcast --verify

# Verification (if deployment was done without --verify)
verify:
	@if [ -z "$$CONTRACT_ADDRESS" ]; then \
		echo "Error: CONTRACT_ADDRESS not set"; \
		exit 1; \
	fi
	@if [ -z "$$CONSTRUCTOR_ARGS" ]; then \
		echo "Error: CONSTRUCTOR_ARGS not set (format: '0x...')"; \
		exit 1; \
	fi
	forge verify-contract $$CONTRACT_ADDRESS src/ExtsyToken.sol:ExtsyToken --constructor-args $$CONSTRUCTOR_ARGS

# Anvil local node
anvil:
	anvil --host 0.0.0.0

# Full check - runs all quality checks
check: build test coverage format
	@echo "All checks passed!"

# Development setup
dev-setup:
	@echo "Setting up development environment..."
	@if [ ! -f .env ]; then cp .env.example .env; echo "Created .env from template"; fi
	forge install
	forge build
	@echo "Development environment ready!"

# Security checks
security:
	@echo "Running security checks..."
	@if command -v slither >/dev/null 2>&1; then \
		slither src/ExtsyToken.sol; \
	else \
		echo "Slither not found. Install with: pip install slither-analyzer"; \
	fi
	@if command -v mythril >/dev/null 2>&1; then \
		myth analyze src/ExtsyToken.sol; \
	else \
		echo "Mythril not found. Install with: pip install mythril"; \
	fi