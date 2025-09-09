// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./interfaces/AggregatorV3Interface.sol";

/**
 * @title xtsySale
 * @dev Clean, minimal presale contract with dynamic vesting for XTSY token
 * @notice Presale Price: $0.10 | Public Price: $0.35+ (5% increases every 6 days)
 * @notice Vesting Categories:
 * - Presale (4%): Immediate transfer on purchase
 * - Public Sale (4%): Immediate transfer on purchase  
 * - Liquidity & Market Making (7%): Immediate transfer on purchase
 * - Team & Advisors (15%): 0% TGE, 12m cliff, 24m vest
 * - Ecosystem Growth (20%): 0% TGE, 36m vest
 * - Treasury (25%): 0% TGE, 6m lock, 36m vest
 * - Marketing & Partnerships (10%): 20% TGE, 6m vest
 */
contract xtsySale is ReentrancyGuard, Ownable, Pausable {
    
    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    IERC20 public saleToken;
    IERC20 public usdtToken;
    IERC20 public usdcToken;
    AggregatorV3Interface public ethUsdPriceFeed;
    
    // Backend signer for signature verification
    address public backendSigner;
    
    // Cross-chain backend signer for cross-chain operations
    address public crossChainBackendSigner;
    
    // Mapping to prevent signature replay attacks
    mapping(bytes32 => bool) public usedSignatures;
    
    enum SalePhase { NotStarted, PresaleWhitelist, PublicSale, Ended }
    
    // Vesting categories with their caps
    enum VestingCategory {
        Presale,                // 4% - 20M tokens
        PublicSale,             // 4% - 20M tokens  
        Liquidity,              // 7% - 35M tokens
        TeamAdvisors,           // 15% - 75M tokens
        Ecosystem,              // 20% - 100M tokens
        Treasury,               // 25% - 125M tokens
        Marketing               // 10% - 50M tokens
    }
    
    // Token distribution caps per category
    mapping(VestingCategory => uint256) public categoryCaps;
    mapping(VestingCategory => uint256) public categoryAllocated;
    
    // =============================================================================
    // CONFIGURATION STRUCTS
    // =============================================================================
    
    struct SaleConfig {
        uint256 presaleStartTime;
        uint256 presaleEndTime;
        uint256 publicSaleStartTime;
        uint256 publicSaleEndTime;
        uint256 presaleRate;            // price per token in micro-USD (100000 = $0.10)
        uint256 publicSaleStartRate;    // initial price per token (350000 = $0.35)
        uint256 priceIncreaseInterval;  // 6 days = 518400 seconds
        uint256 priceIncreaseAmount;    // 5% price increase (17500 = $0.0175)
    }
    
    SaleConfig public saleConfig;
    
    struct VestingConfig {
        uint256 tgePercent;         // Percentage at TGE (1000 = 100%)
        uint256 cliffMonths;        // Cliff period in months
        uint256 vestingMonths;      // Total vesting duration in months
    }
    
    // Vesting configurations per category
    mapping(VestingCategory => VestingConfig) public vestingConfigs;
    
    // =============================================================================
    // USER DATA STRUCTS
    // =============================================================================
    
    struct UserPurchase {
        uint256 presalePurchased;       // USD spent in presale (6 decimals)
        uint256 publicSalePurchased;    // USD spent in public sale (6 decimals)  
        uint256 tokensAllocated;        // Total tokens allocated
        uint256 tokensClaimed;          // Tokens already claimed
        address referrer;               // Who referred this user
    }
    
    mapping(address => UserPurchase) public userPurchases;
    
    struct UserAllocation {
        uint256 totalAllocated;         // Total tokens allocated
        uint256 claimedAmount;          // Amount already claimed
        uint256 allocationTime;         // When allocation was made
    }
    
    // Category-specific allocations per user
    mapping(address => mapping(VestingCategory => UserAllocation)) public userAllocations;
    
    struct ReferralInfo {
        uint256 totalReferred;          // Number of successful referrals
        uint256 totalReferralVolume;    // Total volume from referrals
    }
    
    mapping(address => ReferralInfo) public referralInfo;
    
    // =============================================================================
    // SALE TRACKING
    // =============================================================================
    
    uint256 public totalPresaleSold;
    uint256 public totalPublicSaleSold;
    uint256 public totalUsdtRaised;
    uint256 public totalUsdcRaised;
    uint256 public totalEthRaised;
    uint256 public tgeTimestamp;
    
    // Referral configuration
    uint256 public referralBonusPercent = 50; // 5%
    bool public referralEnabled = true;
    
    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event TokensPurchased(address indexed buyer, uint256 usdAmount, uint256 tokens, SalePhase phase);
    event TokensPurchasedWithReferral(address indexed buyer, address indexed referrer, uint256 usdAmount, uint256 tokens, uint256 referrerBonus);
    event TokensAllocated(address indexed recipient, VestingCategory category, uint256 amount);
    event TokensClaimed(address indexed recipient, VestingCategory category, uint256 amount);
    event BackendSignerUpdated(address indexed newSigner);
    event CrossChainBackendSignerUpdated(address indexed newSigner);
    event SignatureUsed(bytes32 indexed signatureHash);
    event FundsWithdrawn(uint256 usdtAmount, uint256 usdcAmount);
    event CrossChainTokensDistributed(address indexed buyer, uint256 tokens, uint256 chainId, SalePhase phase);
    event USDTTokenUpdated(address indexed newToken);
    event USDCTokenUpdated(address indexed newToken);
    event TGESet(uint256 timestamp);
    
    // =============================================================================
    // ERRORS
    // =============================================================================
    
    error InvalidPhase();
    error InvalidSignature();
    error SignatureAlreadyUsed();
    error SignatureExpired();
    error SaleNotActive();
    error InsufficientTokensAvailable();
    error NoTokensToClaim();
    error InvalidConfiguration();
    error ZeroAddress();
    error ZeroAmount();
    error CliffNotReached();
    error CategoryCapExceeded();
    error AlreadyAllocated();
    error TGENotSet();
    
    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================
    
    constructor(
        address _saleToken,
        address _usdtToken,
        address _usdcToken,
        address _owner,
        address _backendSigner,
        address _crossChainBackendSigner
    ) Ownable(_owner) {
        if (_usdtToken == address(0) || _usdcToken == address(0) || _owner == address(0) || _backendSigner == address(0) || _crossChainBackendSigner == address(0)) {
            revert ZeroAddress();
        }
        
        // Sale token can be zero initially and set later
        if (_saleToken != address(0)) {
            saleToken = IERC20(_saleToken);
        }
        usdtToken = IERC20(_usdtToken);
        usdcToken = IERC20(_usdcToken);
        backendSigner = _backendSigner;
        crossChainBackendSigner = _crossChainBackendSigner;
        
        _initializeCategories();
        _initializeVestingConfigs();
    }
    
    // =============================================================================
    // INITIALIZATION
    // =============================================================================
    
    function _initializeCategories() private {
        // Set category caps (based on 500M total supply)
        categoryCaps[VestingCategory.Presale] = 20_000_000 * 10**18;         // 4%
        categoryCaps[VestingCategory.PublicSale] = 20_000_000 * 10**18;      // 4%
        categoryCaps[VestingCategory.Liquidity] = 35_000_000 * 10**18;       // 7%
        categoryCaps[VestingCategory.TeamAdvisors] = 75_000_000 * 10**18;    // 15%
        categoryCaps[VestingCategory.Ecosystem] = 100_000_000 * 10**18;      // 20%
        categoryCaps[VestingCategory.Treasury] = 125_000_000 * 10**18;       // 25%
        categoryCaps[VestingCategory.Marketing] = 50_000_000 * 10**18;       // 10%
    }
    
    function _initializeVestingConfigs() private {
        // Presale: Immediate transfer (no TGE, no vesting)
        vestingConfigs[VestingCategory.Presale] = VestingConfig(1000, 0, 0);
        
        // Public Sale: Immediate transfer (no TGE, no vesting)
        vestingConfigs[VestingCategory.PublicSale] = VestingConfig(1000, 0, 0);
        
        // Liquidity: Immediate transfer (no TGE, no vesting)
        vestingConfigs[VestingCategory.Liquidity] = VestingConfig(1000, 0, 0);
        
        // Team & Advisors: 0% TGE, 12m cliff, 24m vest
        vestingConfigs[VestingCategory.TeamAdvisors] = VestingConfig(0, 12, 24);
        
        // Ecosystem: 0% TGE, 36m vest (no cliff)
        vestingConfigs[VestingCategory.Ecosystem] = VestingConfig(0, 0, 36);
        
        // Treasury: 0% TGE, 6m lock, 36m vest
        vestingConfigs[VestingCategory.Treasury] = VestingConfig(0, 6, 36);
        
        // Marketing: 20% TGE, 6m vest (no cliff)
        vestingConfigs[VestingCategory.Marketing] = VestingConfig(200, 0, 6);
    }
    
    // =============================================================================
    // CONFIGURATION FUNCTIONS
    // =============================================================================
    
    function configureSale(SaleConfig memory _config) external onlyOwner {
        if (_config.presaleStartTime >= _config.presaleEndTime ||
            _config.presaleEndTime >= _config.publicSaleStartTime ||
            _config.publicSaleStartTime >= _config.publicSaleEndTime) {
            revert InvalidConfiguration();
        }
        
        saleConfig = _config;
    }
    
    function updateVestingConfig(VestingCategory category, VestingConfig memory config) external onlyOwner {
        vestingConfigs[category] = config;
    }
    
    
    function setReferralConfig(uint256 _bonusPercent, bool _enabled) external onlyOwner {
        referralBonusPercent = _bonusPercent;
        referralEnabled = _enabled;
    }
    
    function setSaleToken(address _saleToken) external onlyOwner {
        if (_saleToken == address(0)) revert ZeroAddress();
        saleToken = IERC20(_saleToken);
    }
    
    function setEthUsdPriceFeed(address _priceFeed) external onlyOwner {
        if (_priceFeed == address(0)) revert ZeroAddress();
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeed);
    }
    
    function setBackendSigner(address _backendSigner) external onlyOwner {
        if (_backendSigner == address(0)) revert ZeroAddress();
        backendSigner = _backendSigner;
        emit BackendSignerUpdated(_backendSigner);
    }
    
    function setCrossChainBackendSigner(address _crossChainBackendSigner) external onlyOwner {
        if (_crossChainBackendSigner == address(0)) revert ZeroAddress();
        crossChainBackendSigner = _crossChainBackendSigner;
        emit CrossChainBackendSignerUpdated(_crossChainBackendSigner);
    }
    
    function setUSDTToken(address _usdtToken) external onlyOwner {
        if (_usdtToken == address(0)) revert ZeroAddress();
        usdtToken = IERC20(_usdtToken);
        emit USDTTokenUpdated(_usdtToken);
    }
    
    function setUSDCToken(address _usdcToken) external onlyOwner {
        if (_usdcToken == address(0)) revert ZeroAddress();
        usdcToken = IERC20(_usdcToken);
        emit USDCTokenUpdated(_usdcToken);
    }
    
    function setTGETimestamp(uint256 _tgeTimestamp) external onlyOwner {
        tgeTimestamp = _tgeTimestamp;
        emit TGESet(_tgeTimestamp);
    }
    
    // =============================================================================
    // SIGNATURE VERIFICATION FUNCTIONS
    // =============================================================================
    
    function _verifySignature(
        address user,
        uint256 amount,
        uint256 nonce,
        bytes memory signature
    ) internal {
        // Create message hash
        bytes32 messageHash = keccak256(abi.encodePacked(user, amount, nonce, address(this)));
        bytes32 signatureHash = keccak256(signature);
        
        // Check if signature was already used
        if (usedSignatures[signatureHash]) {
            revert SignatureAlreadyUsed();
        }
        
        // Convert to Ethereum signed message hash
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        
        // Recover signer address
        address recoveredSigner = ECDSA.recover(ethSignedMessageHash, signature);
        
        // Verify signature
        if (recoveredSigner != backendSigner) {
            revert InvalidSignature();
        }
        
        // Mark signature as used
        usedSignatures[signatureHash] = true;
        emit SignatureUsed(signatureHash);
    }
    
    function _verifyCrossChainSignature(
        address buyer,
        uint256 usdAmount,
        uint256 chainId,
        bool isPresale,
        address referrer,
        uint256 nonce,
        uint256 expiry,
        bytes memory signature
    ) internal {
        // Check if signature has expired
        if (block.timestamp > expiry) {
            revert SignatureExpired();
        }
        
        // Create cross-chain specific message hash with expiry
        bytes32 messageHash = keccak256(abi.encodePacked(
            buyer,
            usdAmount,
            chainId,
            isPresale,
            referrer,
            nonce,
            expiry,
            address(this)
        ));
        bytes32 signatureHash = keccak256(signature);
        
        // Check if signature was already used
        if (usedSignatures[signatureHash]) {
            revert SignatureAlreadyUsed();
        }
        
        // Convert to Ethereum signed message hash
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        
        // Recover signer address
        address recoveredSigner = ECDSA.recover(ethSignedMessageHash, signature);
        
        // Verify signature with cross-chain backend signer
        if (recoveredSigner != crossChainBackendSigner) {
            revert InvalidSignature();
        }
        
        // Mark signature as used
        usedSignatures[signatureHash] = true;
        emit SignatureUsed(signatureHash);
    }
    
    // =============================================================================
    // PHASE MANAGEMENT
    // =============================================================================
    
    
    function getCurrentPhase() public view returns (SalePhase) {
        uint256 currentTime = block.timestamp;
        
        if (currentTime < saleConfig.presaleStartTime) {
            return SalePhase.NotStarted;
        } else if (currentTime >= saleConfig.presaleStartTime && currentTime < saleConfig.presaleEndTime) {
            return SalePhase.PresaleWhitelist;
        } else if (currentTime >= saleConfig.presaleEndTime && currentTime < saleConfig.publicSaleStartTime) {
            return SalePhase.NotStarted; // Gap between presale and public
        } else if (currentTime >= saleConfig.publicSaleStartTime && currentTime < saleConfig.publicSaleEndTime) {
            return SalePhase.PublicSale;
        } else {
            return SalePhase.Ended;
        }
    }
    
    // =============================================================================
    // PURCHASE FUNCTIONS
    // =============================================================================

    // --- Safe transfer helpers for USDT/USDC compatibility ---
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool callSuccess, bytes memory data) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amount)
        );
        require(callSuccess, "Token transferFrom call failed");
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "Token transferFrom returned false");
        }
    }
    
    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool callSuccess, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        require(callSuccess, "Token transfer call failed");
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "Token transfer returned false");
        }
    }
    
    function buyTokensWithUSDT(
        uint256 usdtAmount,
        uint256 nonce,
        bytes calldata signature
    ) external nonReentrant whenNotPaused {
        _buyTokens(usdtAmount, true, address(0), nonce, signature);
    }
    
    function buyTokensWithUSDC(
        uint256 usdcAmount,
        uint256 nonce,
        bytes calldata signature
    ) external nonReentrant whenNotPaused {
        _buyTokens(usdcAmount, false, address(0), nonce, signature);
    }
    
    function buyTokensWithUSDTAndReferral(
        uint256 usdtAmount,
        address referrer,
        uint256 nonce,
        bytes calldata signature
    ) external nonReentrant whenNotPaused {
        _buyTokens(usdtAmount, true, referrer, nonce, signature);
    }
    
    function buyTokensWithUSDCAndReferral(
        uint256 usdcAmount,
        address referrer,
        uint256 nonce,
        bytes calldata signature
    ) external nonReentrant whenNotPaused {
        _buyTokens(usdcAmount, false, referrer, nonce, signature);
    }
    
    function buyTokensWithETH(
        uint256 nonce,
        bytes calldata signature
    ) external payable nonReentrant whenNotPaused {
        _buyTokensWithETH(address(0), nonce, signature);
    }
    
    function buyTokensWithETHAndReferral(
        address referrer,
        uint256 nonce,
        bytes calldata signature
    ) external payable nonReentrant whenNotPaused {
        _buyTokensWithETH(referrer, nonce, signature);
    }
    
    function _buyTokens(
        uint256 usdAmount,
        bool isUsdt,
        address referrer,
        uint256 nonce,
        bytes calldata signature
    ) private {
        SalePhase phase = getCurrentPhase();
        
        if (phase == SalePhase.NotStarted || phase == SalePhase.Ended) {
            revert SaleNotActive();
        }
        
        // Check if sale token is set
        if (address(saleToken) == address(0)) revert ZeroAddress();
        
        // Verify signature for presale access
        if (phase == SalePhase.PresaleWhitelist) {
            _verifySignature(msg.sender, usdAmount, nonce, signature);
        }
        
        if (usdAmount == 0) revert ZeroAmount();
        
        // Calculate tokens to allocate
        uint256 currentRate = getCurrentRate();
        uint256 tokensToAllocate = (usdAmount * 10**18) / currentRate;
        
        // Check caps
        if (phase == SalePhase.PresaleWhitelist) {
            if (totalPresaleSold + tokensToAllocate > categoryCaps[VestingCategory.Presale]) {
                revert InsufficientTokensAvailable();
            }
            totalPresaleSold += tokensToAllocate;
        } else {
            if (totalPublicSaleSold + tokensToAllocate > categoryCaps[VestingCategory.PublicSale]) {
                revert InsufficientTokensAvailable();
            }
            totalPublicSaleSold += tokensToAllocate;
        }
        
        // Calculate referral bonus before transferring payment
        uint256 referrerPaymentBonus = 0;
        if (referralEnabled && referrer != address(0) && referrer != msg.sender) {
            referrerPaymentBonus = (usdAmount * referralBonusPercent) / 1000; // 5% of payment amount
        }
        
        // Transfer payment using safe transferFrom
        IERC20 paymentToken = isUsdt ? usdtToken : usdcToken;
        _safeTransferFrom(address(paymentToken), msg.sender, address(this), usdAmount);
        
        // Transfer referral bonus to referrer if applicable
        if (referrerPaymentBonus > 0) {
            _safeTransfer(address(paymentToken), referrer, referrerPaymentBonus);
        }
        
        // Update user purchase data
        UserPurchase storage purchase = userPurchases[msg.sender];
        if (phase == SalePhase.PresaleWhitelist) {
            purchase.presalePurchased += usdAmount;
        } else {
            purchase.publicSalePurchased += usdAmount;
        }
        purchase.tokensAllocated += tokensToAllocate;
        // Note: tokensClaimed remains 0 until tokens are actually distributed
        
        // Handle referral info update
        if (referralEnabled && referrer != address(0) && referrer != msg.sender) {
            purchase.referrer = referrer;
            
            ReferralInfo storage refInfo = referralInfo[referrer];
            refInfo.totalReferred++;
            refInfo.totalReferralVolume += usdAmount;
            
            emit TokensPurchasedWithReferral(msg.sender, referrer, usdAmount, tokensToAllocate, referrerPaymentBonus);
        } else {
            emit TokensPurchased(msg.sender, usdAmount, tokensToAllocate, phase);
        }
        
        // Update totals
        if (isUsdt) {
            totalUsdtRaised += usdAmount;
        } else {
            totalUsdcRaised += usdAmount;
        }
    }
    
    function _buyTokensWithETH(
        address referrer,
        uint256 nonce,
        bytes calldata signature
    ) private {
        SalePhase phase = getCurrentPhase();
        
        if (phase == SalePhase.NotStarted || phase == SalePhase.Ended) {
            revert SaleNotActive();
        }
        
        // Check if sale token is set
        if (address(saleToken) == address(0)) revert ZeroAddress();
        
        if (msg.value == 0) revert ZeroAmount();
        
        // Get ETH price in USD (with 8 decimals from Chainlink)
        uint256 ethPriceUsd = getLatestETHPrice();
        
        // Convert ETH amount to USD (6 decimals to match USDT/USDC)
        // msg.value is in wei (18 decimals), ethPriceUsd is 8 decimals
        // Result should be 6 decimals: (18 + 8 - 18 - 2) = 6
        uint256 usdAmount = (msg.value * ethPriceUsd) / (10**20);
        
        // Verify signature for presale access  
        if (phase == SalePhase.PresaleWhitelist) {
            _verifySignature(msg.sender, msg.value, nonce, signature);
        }
        
        // Calculate tokens to allocate
        uint256 currentRate = getCurrentRate();
        uint256 tokensToAllocate = (usdAmount * 10**18) / currentRate;
        
        // Check caps
        if (phase == SalePhase.PresaleWhitelist) {
            if (totalPresaleSold + tokensToAllocate > categoryCaps[VestingCategory.Presale]) {
                revert InsufficientTokensAvailable();
            }
            totalPresaleSold += tokensToAllocate;
        } else {
            if (totalPublicSaleSold + tokensToAllocate > categoryCaps[VestingCategory.PublicSale]) {
                revert InsufficientTokensAvailable();
            }
            totalPublicSaleSold += tokensToAllocate;
        }
        
        // Calculate referral bonus before processing
        uint256 referrerEthBonus = 0;
        if (referralEnabled && referrer != address(0) && referrer != msg.sender) {
            referrerEthBonus = (msg.value * referralBonusPercent) / 1000; // 5% of ETH payment
        }
        
        // Transfer referral bonus to referrer if applicable
        if (referrerEthBonus > 0) {
            (bool success, ) = referrer.call{value: referrerEthBonus}("");
            require(success, "ETH referral transfer failed");
        }
        
        // Update user purchase data
        UserPurchase storage purchase = userPurchases[msg.sender];
        if (phase == SalePhase.PresaleWhitelist) {
            purchase.presalePurchased += usdAmount;
        } else {
            purchase.publicSalePurchased += usdAmount;
        }
        purchase.tokensAllocated += tokensToAllocate;
        // Note: tokensClaimed remains 0 until tokens are actually distributed
        
        // Handle referral info update
        if (referralEnabled && referrer != address(0) && referrer != msg.sender) {
            purchase.referrer = referrer;
            
            ReferralInfo storage refInfo = referralInfo[referrer];
            refInfo.totalReferred++;
            refInfo.totalReferralVolume += usdAmount;
            
            emit TokensPurchasedWithReferral(msg.sender, referrer, usdAmount, tokensToAllocate, referrerEthBonus);
        } else {
            emit TokensPurchased(msg.sender, usdAmount, tokensToAllocate, phase);
        }
        
        // Update ETH total
        totalEthRaised += msg.value;
    }
    
    function getLatestETHPrice() public view returns (uint256) {
        if (address(ethUsdPriceFeed) == address(0)) revert ZeroAddress();
        
        (, int256 price, , uint256 updatedAt, ) = ethUsdPriceFeed.latestRoundData();
        require(price > 0, "Invalid ETH price");
        require(updatedAt > 0, "Price data stale");
        require(block.timestamp - updatedAt <= 3600, "Price feed too old"); // 1 hour max
        
        return uint256(price);
    }
    
    function getLatestETHPriceUnchecked() public view returns (uint256) {
        if (address(ethUsdPriceFeed) == address(0)) return 0;
        
        try ethUsdPriceFeed.latestRoundData() returns (uint80, int256 price, uint256, uint256, uint80) {
            return price > 0 ? uint256(price) : 0;
        } catch {
            return 0;
        }
    }
    
    // Debug function to see what's happening in the calculation
    function debugETHCalculation(uint256 ethAmount) external view returns (
        uint256 ethPriceUsd,
        uint256 currentRate,
        uint256 ethInUsd, 
        uint256 tokensFromETH,
        bool priceFeedExists,
        bool ethAmountPositive,
        bool currentRatePositive
    ) {
        currentRate = getCurrentRate();
        priceFeedExists = address(ethUsdPriceFeed) != address(0);
        ethAmountPositive = ethAmount > 0;
        currentRatePositive = currentRate > 0;
        
        if (ethAmount > 0 && currentRate > 0 && address(ethUsdPriceFeed) != address(0)) {
            try this.getLatestETHPrice() returns (uint256 price) {
                ethPriceUsd = price;
                ethInUsd = (ethAmount * ethPriceUsd) / (10**20);
                tokensFromETH = (ethInUsd * 10**18) / currentRate;
            } catch {
                ethPriceUsd = 999999999; // Error marker
            }
        }
    }
    
    function getCurrentRate() public view returns (uint256) {
        SalePhase phase = getCurrentPhase();
        if (phase == SalePhase.PresaleWhitelist) {
            return saleConfig.presaleRate;
        } else if (phase == SalePhase.PublicSale) {
            // Dynamic pricing for public sale
            uint256 timeElapsed = block.timestamp - saleConfig.publicSaleStartTime;
            uint256 priceIncreases = timeElapsed / saleConfig.priceIncreaseInterval;
            return saleConfig.publicSaleStartRate + (priceIncreases * saleConfig.priceIncreaseAmount);
        }
        return 0;
    }
    
    // =============================================================================
    // ALLOCATION FUNCTIONS
    // =============================================================================
    
    function allocateTokens(
        address recipient,
        VestingCategory category,
        uint256 amount
    ) external onlyOwner {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        
        if (categoryAllocated[category] + amount > categoryCaps[category]) {
            revert CategoryCapExceeded();
        }
        
        UserAllocation storage allocation = userAllocations[recipient][category];
        if (allocation.totalAllocated > 0) {
            revert AlreadyAllocated();
        }
        
        allocation.totalAllocated = amount;
        allocation.allocationTime = block.timestamp;
        categoryAllocated[category] += amount;
        
        emit TokensAllocated(recipient, category, amount);
    }
    
    function batchAllocateTokens(
        address[] calldata recipients,
        VestingCategory category,
        uint256[] calldata amounts
    ) external onlyOwner {
        if (recipients.length != amounts.length) revert InvalidConfiguration();
        
        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0)) revert ZeroAddress();
            if (amounts[i] == 0) revert ZeroAmount();
            
            if (categoryAllocated[category] + amounts[i] > categoryCaps[category]) {
                revert CategoryCapExceeded();
            }
            
            UserAllocation storage allocation = userAllocations[recipients[i]][category];
            if (allocation.totalAllocated > 0) {
                revert AlreadyAllocated();
            }
            
            allocation.totalAllocated = amounts[i];
            allocation.allocationTime = block.timestamp;
            categoryAllocated[category] += amounts[i];
            
            emit TokensAllocated(recipients[i], category, amounts[i]);
        }
    }
    
    // =============================================================================
    // CLAIMING FUNCTIONS
    // =============================================================================
    
    function claimTGETokens(VestingCategory category) external nonReentrant {
        if (address(saleToken) == address(0)) revert ZeroAddress();
        if (tgeTimestamp == 0 || block.timestamp < tgeTimestamp) {
            revert TGENotSet();
        }
        
        UserAllocation storage allocation = userAllocations[msg.sender][category];
        if (allocation.totalAllocated == 0) revert NoTokensToClaim();
        
        VestingConfig storage config = vestingConfigs[category];
        if (config.tgePercent == 0) revert NoTokensToClaim();
        
        uint256 tgeAmount = (allocation.totalAllocated * config.tgePercent) / 1000;
        if (tgeAmount == 0) revert NoTokensToClaim();
        
        // Check if TGE tokens already claimed (using claimedAmount as TGE tracker)
        if (allocation.claimedAmount >= tgeAmount) revert NoTokensToClaim();
        
        uint256 claimableTGE = tgeAmount - allocation.claimedAmount;
        allocation.claimedAmount += claimableTGE;
        
        _safeTransfer(address(saleToken), msg.sender, claimableTGE);
        emit TokensClaimed(msg.sender, category, claimableTGE);
    }
    
    function claimVestedTokens(VestingCategory category) external nonReentrant {
        if (address(saleToken) == address(0)) revert ZeroAddress();
        if (tgeTimestamp == 0) revert TGENotSet();
        
        UserAllocation storage allocation = userAllocations[msg.sender][category];
        if (allocation.totalAllocated == 0) revert NoTokensToClaim();
        
        uint256 claimableAmount = getClaimableAmount(msg.sender, category);
        if (claimableAmount == 0) revert NoTokensToClaim();
        
        allocation.claimedAmount += claimableAmount;
        _safeTransfer(address(saleToken), msg.sender, claimableAmount);
        
        emit TokensClaimed(msg.sender, category, claimableAmount);
    }
    
    function getClaimableAmount(address user, VestingCategory category) public view returns (uint256) {
        if (tgeTimestamp == 0 || block.timestamp < tgeTimestamp) return 0;
        
        UserAllocation storage allocation = userAllocations[user][category];
        if (allocation.totalAllocated == 0) return 0;
        
        VestingConfig storage config = vestingConfigs[category];
        uint256 totalVested = getTotalVested(allocation.totalAllocated, allocation.allocationTime, config);
        
        return totalVested > allocation.claimedAmount ? totalVested - allocation.claimedAmount : 0;
    }
    
    function getTotalVested(
        uint256 totalAmount,
        uint256 allocationTime,
        VestingConfig storage config
    ) private view returns (uint256) {
        if (block.timestamp < tgeTimestamp) return 0;
        
        uint256 tgeAmount = (totalAmount * config.tgePercent) / 1000;
        
        // If no vesting period, return TGE amount only
        if (config.vestingMonths == 0) return tgeAmount;
        
        uint256 cliffEnd = tgeTimestamp + (config.cliffMonths * 30 * 10 minutes); // scaled time: 30 days = 300 minutes = 30 * 10 minutes
        if (block.timestamp < cliffEnd) return tgeAmount;
        
        uint256 vestingEnd = tgeTimestamp + (config.vestingMonths * 30 * 10 minutes); // scaled time
        if (block.timestamp >= vestingEnd) return totalAmount;
        
        // Linear vesting after cliff
        uint256 vestingAmount = totalAmount - tgeAmount;
        uint256 vestingDuration = config.vestingMonths * 30 * 10 minutes; // scaled time
        uint256 timeFromTGE = block.timestamp - tgeTimestamp;
        
        uint256 vestedFromVesting = (vestingAmount * timeFromTGE) / vestingDuration;
        return tgeAmount + vestedFromVesting;
    }
    
    // =============================================================================
    // ADMIN FUNCTIONS
    // =============================================================================
    
    function withdrawFunds() external onlyOwner {
        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 ethBalance = address(this).balance;
        
        if (usdtBalance > 0) {
            _safeTransfer(address(usdtToken), owner(), usdtBalance);
        }
        if (usdcBalance > 0) {
            _safeTransfer(address(usdcToken), owner(), usdcBalance);
        }
        if (ethBalance > 0) {
            payable(owner()).transfer(ethBalance);
        }
        
        emit FundsWithdrawn(usdtBalance, usdcBalance);
    }
    
    function emergencyTokenWithdraw() external onlyOwner {
        uint256 balance = saleToken.balanceOf(address(this));
        if (balance > 0) {
            _safeTransfer(address(saleToken), owner(), balance);
        }
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // =============================================================================
    // CROSS-CHAIN DISTRIBUTION FUNCTION
    // =============================================================================
    
    function distributeTokensCrossChain(
        address buyer,
        uint256 saleTokenAmount,
        uint256 chainId,
        bool isPresale,
        address referrer,
        uint256 nonce,
        uint256 expiry,
        bytes calldata signature
    ) external nonReentrant whenNotPaused onlyOwner {
        // Verify cross-chain backend signature with expiry
        _verifyCrossChainSignature(buyer, saleTokenAmount, chainId, isPresale, referrer, nonce, expiry, signature);
        
        if (address(saleToken) == address(0)) revert ZeroAddress();
        if (buyer == address(0)) revert ZeroAddress();
        if (saleTokenAmount == 0) revert ZeroAmount();
        
        // Check caps
        if (isPresale) {
            if (totalPresaleSold + saleTokenAmount > categoryCaps[VestingCategory.Presale]) {
                revert InsufficientTokensAvailable();
            }
            totalPresaleSold += saleTokenAmount;
        } else {
            if (totalPublicSaleSold + saleTokenAmount > categoryCaps[VestingCategory.PublicSale]) {
                revert InsufficientTokensAvailable();
            }
            totalPublicSaleSold += saleTokenAmount;
        }
        
        // Update user purchase data
        UserPurchase storage purchase = userPurchases[buyer];
        purchase.tokensAllocated += saleTokenAmount;
        purchase.tokensClaimed += saleTokenAmount; // Mark tokens as claimed when distributed
        
        // Transfer tokens immediately to buyer
        _safeTransfer(address(saleToken), buyer, saleTokenAmount);
        
        emit CrossChainTokensDistributed(buyer, saleTokenAmount, chainId, isPresale ? SalePhase.PresaleWhitelist : SalePhase.PublicSale);
    }
    
    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================
    
    function getUserPurchaseInfo(address user) external view returns (UserPurchase memory) {
        return userPurchases[user];
    }
    
    function getUserAllocation(address user, VestingCategory category) external view returns (UserAllocation memory) {
        return userAllocations[user][category];
    }
    
    function getReferralInfo(address user) external view returns (ReferralInfo memory) {
        return referralInfo[user];
    }
    
    function getTokenAmountForPayment(uint256 usdAmount, uint256 ethAmount) external view returns (uint256 tokensFromUSD, uint256 tokensFromETH) {
        uint256 currentRate = getCurrentRate();
        
        // Calculate tokens from USD amount (USDT/USDC)
        if (usdAmount > 0 && currentRate > 0) {
            tokensFromUSD = (usdAmount * 10**18) / currentRate;
        }
        
        // Calculate tokens from ETH amount
        if (ethAmount > 0 && currentRate > 0 && address(ethUsdPriceFeed) != address(0)) {
            uint256 ethPriceUsd = getLatestETHPriceUnchecked();
            if (ethPriceUsd > 0) {
                // Convert ETH to USD (6 decimals)
                uint256 ethInUsd = (ethAmount * ethPriceUsd) / (10**20);
                tokensFromETH = (ethInUsd * 10**18) / currentRate;
            }
        }
        
        return (tokensFromUSD, tokensFromETH);
    }
    
    function getCategoryInfo(VestingCategory category) external view returns (uint256 cap, uint256 allocated, VestingConfig memory config) {
        return (categoryCaps[category], categoryAllocated[category], vestingConfigs[category]);
    }
    
    function getContractStats() external view returns (
        uint256 _totalPresaleSold,
        uint256 _totalPublicSaleSold, 
        uint256 _totalUsdtRaised,
        uint256 _totalUsdcRaised,
        uint256 _totalEthRaised,
        SalePhase _phase
    ) {
        return (totalPresaleSold, totalPublicSaleSold, totalUsdtRaised, totalUsdcRaised, totalEthRaised, getCurrentPhase());
    }
    
    /**
     * @dev Get the number of tokens a user can claim (purchased but not yet distributed)
     * @param user The user address
     * @return The number of tokens that can be claimed
     */
    function getClaimablePurchaseTokens(address user) external view returns (uint256) {
        UserPurchase memory purchase = userPurchases[user];
        return purchase.tokensAllocated - purchase.tokensClaimed;
    }
}