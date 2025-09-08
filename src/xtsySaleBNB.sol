// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
/**
 * @title ERC20 Interface
 * @notice USDT-compatible ERC20 interface (no return values)
 */
interface IERC20 {
    function transfer(address to, uint256 value) external;
    function transferFrom(address from, address to, uint256 value) external;
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./interfaces/AggregatorV3Interface.sol";

/**
 * @title xtsySaleBNB
 * @dev Simplified BNB Chain presale contract - only tracks purchases, no token allocation or vesting
 * @notice Presale Price: $0.025 | Public Price: $0.10+ (dynamic)
 * @notice Backend handles all token distribution on Ethereum mainnet
 * @notice Accepts BNB, USDT, and USDC on BNB Chain
 */
contract xtsySaleBNB is ReentrancyGuard, Ownable, Pausable {
    
    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    IERC20 public immutable usdtToken;
    IERC20 public immutable usdcToken;
    AggregatorV3Interface public bnbUsdPriceFeed;
    
    // Backend signer for signature verification
    address public backendSigner;
    
    // Mapping to prevent signature replay attacks
    mapping(bytes32 => bool) public usedSignatures;
    
    enum SalePhase { NotStarted, PresaleWhitelist, PublicSale, Ended }
    SalePhase public currentPhase;
    
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
    
    // =============================================================================
    // USER DATA STRUCTS - Only tracking purchases
    // =============================================================================
    
    struct UserPurchase {
        uint256 presalePurchased;       // USD spent in presale (6 decimals)
        uint256 publicSalePurchased;    // USD spent in public sale (6 decimals)  
        uint256 totalUsdSpent;          // Total USD spent across all phases
        address referrer;               // Who referred this user
        uint256 purchaseCount;          // Number of purchases made
    }
    
    mapping(address => UserPurchase) public userPurchases;
    
    struct ReferralInfo {
        uint256 totalReferred;          // Number of successful referrals
        uint256 totalReferralVolume;    // Total volume from referrals
    }
    
    mapping(address => ReferralInfo) public referralInfo;
    
    // =============================================================================
    // PURCHASE STATISTICS - Only tracking money raised
    // =============================================================================
    
    uint256 public totalPresaleVolume;  // Total USD spent in presale
    uint256 public totalPublicVolume;   // Total USD spent in public sale
    uint256 public totalUsdtRaised;     // Total USDT collected
    uint256 public totalUsdcRaised;     // Total USDC collected
    uint256 public totalBnbRaised;      // Total BNB collected
    uint256 public totalPurchasers;     // Number of unique purchasers
    
    // =============================================================================
    // REFERRAL CONFIG
    // =============================================================================
    
    uint256 public referralBonusPercent = 50; // 5% = 50/1000
    bool public referralEnabled = true;
    
    // =============================================================================
    // BULLETPROOF ERC20 TRANSFER FUNCTIONS
    // =============================================================================
    
    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool callSuccess, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        
        require(callSuccess, "Token transfer call failed");
        
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "Token transfer returned false");
        }
    }
    
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool callSuccess, bytes memory data) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amount)
        );
        
        require(callSuccess, "Token transferFrom call failed");
        
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "Token transferFrom returned false");
        }
    }
    
    
    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event PurchaseRecorded(
        address indexed buyer,
        uint256 usdAmount,
        uint256 expectedTokens,
        SalePhase phase,
        address referrer,
        string paymentMethod
    );
    
    event ReferralRecorded(address indexed referrer, address indexed referee, uint256 usdVolume);
    event SalePhaseUpdated(SalePhase newPhase);
    event FundsWithdrawn(uint256 usdtAmount, uint256 usdcAmount, uint256 bnbAmount);
    event SignatureUsed(bytes32 indexed signatureHash);
    event CrossChainPurchase(
        address indexed buyer,
        uint256 usdAmount,
        uint256 expectedTokens,
        SalePhase phase,
        address referrer,
        string paymentMethod,
        uint256 chainId
    );
    
    // =============================================================================
    // ERRORS
    // =============================================================================
    
    error ZeroAddress();
    error InvalidSignature();
    error SignatureAlreadyUsed();
    error SaleNotActive();
    error InvalidAmount();
    error TransferFailed();
    error SaleNotEnded();
    error InvalidPrice();
    
    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================
    
    constructor(
        address _usdtToken,
        address _usdcToken,
        address _bnbUsdPriceFeed,
        address _owner,
        address _backendSigner
    ) Ownable(_owner) {
        if (_usdtToken == address(0) || _usdcToken == address(0) || _owner == address(0) || _backendSigner == address(0)) revert ZeroAddress();
        
        usdtToken = IERC20(_usdtToken);
        usdcToken = IERC20(_usdcToken);
        backendSigner = _backendSigner;
        currentPhase = SalePhase.NotStarted;
        
        if (_bnbUsdPriceFeed != address(0)) {
            bnbUsdPriceFeed = AggregatorV3Interface(_bnbUsdPriceFeed);
        }
    }
    
    // =============================================================================
    // CONFIGURATION FUNCTIONS
    // =============================================================================
    
    function configureSale(SaleConfig memory _config) external onlyOwner {
        saleConfig = _config;
    }
    
    function setBnbUsdPriceFeed(address _priceFeed) external onlyOwner {
        if (_priceFeed == address(0)) revert ZeroAddress();
        bnbUsdPriceFeed = AggregatorV3Interface(_priceFeed);
    }
    
    function setBackendSigner(address _signer) external onlyOwner {
        if (_signer == address(0)) revert ZeroAddress();
        backendSigner = _signer;
    }
    
    function setReferralConfig(uint256 _bonusPercent, bool _enabled) external onlyOwner {
        referralBonusPercent = _bonusPercent;
        referralEnabled = _enabled;
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
    
    // =============================================================================
    // PURCHASE FUNCTIONS - Only record purchases, no token allocation
    // =============================================================================
    
    function buyTokensWithBNB(
        uint256 nonce,
        bytes calldata signature
    ) external payable nonReentrant whenNotPaused {
        _buyTokensWithBNB(address(0), nonce, signature);
    }
    
    function buyTokensWithBNBAndReferral(
        address referrer,
        uint256 nonce,
        bytes calldata signature
    ) external payable nonReentrant whenNotPaused {
        _buyTokensWithBNB(referrer, nonce, signature);
    }
    
    function buyTokensWithUSDT(
        uint256 amount,
        address referrer,
        uint256 nonce,
        bytes calldata signature
    ) external nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        
        // Verify signature for presale access
        updatePhase();
        if (currentPhase == SalePhase.PresaleWhitelist) {
            _verifySignature(msg.sender, amount, nonce, signature);
        }
        
        _safeTransferFrom(address(usdtToken), msg.sender, address(this), amount);
        
        // Handle referral - give 5% of USDT to referrer
        if (referralEnabled && referrer != address(0) && referrer != msg.sender) {
            uint256 referrerUsdtBonus = (amount * referralBonusPercent) / 1000; // 5% of USDT payment
            if (referrerUsdtBonus > 0) {
                _safeTransfer(address(usdtToken), referrer, referrerUsdtBonus);
            }
        }
        
        _recordPurchase(msg.sender, amount, referrer, "USDT");
        totalUsdtRaised += amount;
    }
    
    function buyTokensWithUSDC(
        uint256 amount,
        address referrer,
        uint256 nonce,
        bytes calldata signature
    ) external nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        
        // Verify signature for presale access
        updatePhase();
        if (currentPhase == SalePhase.PresaleWhitelist) {
            _verifySignature(msg.sender, amount, nonce, signature);
        }
        
        _safeTransferFrom(address(usdcToken), msg.sender, address(this), amount);
        
        // Handle referral - give 5% of USDC to referrer
        if (referralEnabled && referrer != address(0) && referrer != msg.sender) {
            uint256 referrerUsdcBonus = (amount * referralBonusPercent) / 1000; // 5% of USDC payment
            if (referrerUsdcBonus > 0) {
                _safeTransfer(address(usdcToken), referrer, referrerUsdcBonus);
            }
        }
        
        _recordPurchase(msg.sender, amount, referrer, "USDC");
        totalUsdcRaised += amount;
    }
    
    function _buyTokensWithBNB(
        address referrer,
        uint256 nonce,
        bytes calldata signature
    ) internal {
        if (msg.value == 0) revert InvalidAmount();
        
        // Verify signature for presale access
        updatePhase();
        if (currentPhase == SalePhase.PresaleWhitelist) {
            _verifySignature(msg.sender, msg.value, nonce, signature);
        }
        
        // Get BNB price in USD (with 8 decimals from Chainlink)
        uint256 bnbPriceUsd = getLatestBNBPrice();
        
        // Convert BNB amount to USD (6 decimals to match USDT/USDC)
        // msg.value is in wei (18 decimals), bnbPriceUsd is 8 decimals
        // Result: (wei * price_8_decimals) / 10^20 = USD_6_decimals
        uint256 usdAmount = (msg.value * bnbPriceUsd) / (10**20);
        
        // Handle referral - give 5% of BNB to referrer
        if (referralEnabled && referrer != address(0) && referrer != msg.sender) {
            uint256 referrerBnbBonus = (msg.value * referralBonusPercent) / 1000; // 5% of BNB payment
            if (referrerBnbBonus > 0) {
                (bool success, ) = referrer.call{value: referrerBnbBonus}("");
                require(success, "BNB referral transfer failed");
            }
        }
        
        _recordPurchase(msg.sender, usdAmount, referrer, "BNB");
        
        // Update BNB total
        totalBnbRaised += msg.value;
    }
    
    function _recordPurchase(address buyer, uint256 usdAmount, address referrer, string memory paymentMethod) internal {
        updatePhase();
        
        if (currentPhase != SalePhase.PresaleWhitelist && currentPhase != SalePhase.PublicSale) revert SaleNotActive();
        
        
        uint256 currentRate = getCurrentRate();
        uint256 expectedTokens = (usdAmount * 10**18) / currentRate; // For display purposes only
        
        // Update user purchase data - only tracking spending
        UserPurchase storage purchase = userPurchases[buyer];
        
        // Track if this is a new purchaser
        bool isNewPurchaser = (purchase.totalUsdSpent == 0);
        
        if (currentPhase == SalePhase.PresaleWhitelist) {
            purchase.presalePurchased += usdAmount;
            totalPresaleVolume += usdAmount;
        } else {
            purchase.publicSalePurchased += usdAmount;
            totalPublicVolume += usdAmount;
        }
        
        purchase.totalUsdSpent += usdAmount;
        purchase.purchaseCount += 1;
        
        if (isNewPurchaser) {
            totalPurchasers += 1;
        }
        
        // Handle referrals - record info and update stats
        if (referralEnabled && referrer != address(0) && referrer != buyer && purchase.referrer == address(0)) {
            purchase.referrer = referrer;
            
            // Update referrer info
            ReferralInfo storage refInfo = referralInfo[referrer];
            refInfo.totalReferred += 1;
            refInfo.totalReferralVolume += usdAmount;
            
            emit ReferralRecorded(referrer, buyer, usdAmount);
        }
        
        emit PurchaseRecorded(buyer, usdAmount, expectedTokens, currentPhase, referrer, paymentMethod);
        
        // Emit cross-chain event for backend processing (BNB Chain ID = 56)
        emit CrossChainPurchase(buyer, usdAmount, expectedTokens, currentPhase, referrer, paymentMethod, 56);
    }
    
    // =============================================================================
    // PRICE & PHASE FUNCTIONS
    // =============================================================================
    
    function getCurrentRate() public view returns (uint256) {
        if (currentPhase == SalePhase.PresaleWhitelist) {
            return saleConfig.presaleRate;
        } else if (currentPhase == SalePhase.PublicSale) {
            uint256 timeElapsed = block.timestamp - saleConfig.publicSaleStartTime;
            uint256 priceIncreases = timeElapsed / saleConfig.priceIncreaseInterval;
            return saleConfig.publicSaleStartRate + (priceIncreases * saleConfig.priceIncreaseAmount);
        }
        return 0;
    }
    
    function updatePhase() public {
        uint256 currentTime = block.timestamp;
        SalePhase newPhase = currentPhase;
        
        if (currentTime >= saleConfig.publicSaleEndTime) {
            newPhase = SalePhase.Ended;
        } else if (currentTime >= saleConfig.publicSaleStartTime) {
            newPhase = SalePhase.PublicSale;
        } else if (currentTime >= saleConfig.presaleStartTime) {
            newPhase = SalePhase.PresaleWhitelist;
        }
        
        if (newPhase != currentPhase) {
            currentPhase = newPhase;
            emit SalePhaseUpdated(newPhase);
        }
    }
    
    function getCurrentPhase() external view returns (SalePhase) {
        uint256 currentTime = block.timestamp;
        
        if (currentTime >= saleConfig.publicSaleEndTime) {
            return SalePhase.Ended;
        } else if (currentTime >= saleConfig.publicSaleStartTime) {
            return SalePhase.PublicSale;
        } else if (currentTime >= saleConfig.presaleStartTime) {
            return SalePhase.PresaleWhitelist;
        }
        
        return SalePhase.NotStarted;
    }
    
    function getLatestBNBPrice() public view returns (uint256) {
        if (address(bnbUsdPriceFeed) == address(0)) revert ZeroAddress();
        
        (, int256 price, , uint256 updatedAt, ) = bnbUsdPriceFeed.latestRoundData();
        require(price > 0, "Invalid BNB price");
        require(updatedAt > 0, "Price data stale");
        require(block.timestamp - updatedAt <= 3600, "Price feed too old"); // 1 hour max
        
        return uint256(price);
    }
    
    function getLatestBNBPriceUnchecked() public view returns (uint256) {
        if (address(bnbUsdPriceFeed) == address(0)) return 0;
        
        try bnbUsdPriceFeed.latestRoundData() returns (uint80, int256 price, uint256, uint256, uint80) {
            return price > 0 ? uint256(price) : 0;
        } catch {
            return 0;
        }
    }
    
    // Debug function to see what's happening in the calculation
    function debugBNBCalculation(uint256 bnbAmount) external view returns (
        uint256 bnbPriceUsd,
        uint256 currentRate,
        uint256 bnbInUsd, 
        uint256 tokensFromBNB,
        bool priceFeedExists,
        bool bnbAmountPositive,
        bool currentRatePositive
    ) {
        currentRate = getCurrentRate();
        priceFeedExists = address(bnbUsdPriceFeed) != address(0);
        bnbAmountPositive = bnbAmount > 0;
        currentRatePositive = currentRate > 0;
        
        if (bnbAmount > 0 && currentRate > 0 && address(bnbUsdPriceFeed) != address(0)) {
            try this.getLatestBNBPrice() returns (uint256 price) {
                bnbPriceUsd = price;
                bnbInUsd = (bnbAmount * bnbPriceUsd) / (10**20);
                tokensFromBNB = (bnbInUsd * 10**18) / currentRate;
            } catch {
                bnbPriceUsd = 999999999; // Error marker
            }
        }
    }
    
    // =============================================================================
    // ADMIN FUNCTIONS
    // =============================================================================
    
    function withdrawFunds() external onlyOwner {
        if (currentPhase != SalePhase.Ended) revert SaleNotEnded();
        
        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        uint256 bnbBalance = address(this).balance;
        
        if (usdtBalance > 0) {
            _safeTransfer(address(usdtToken), owner(), usdtBalance);
        }
        if (usdcBalance > 0) {
            _safeTransfer(address(usdcToken), owner(), usdcBalance);
        }
        if (bnbBalance > 0) {
            (bool success, ) = payable(owner()).call{value: bnbBalance}("");
            require(success, "BNB withdrawal failed");
        }
        
        emit FundsWithdrawn(usdtBalance, usdcBalance, bnbBalance);
    }
    
    function emergencyPause() external onlyOwner {
        _pause();
    }
    
    function emergencyUnpause() external onlyOwner {
        _unpause();
    }
    
    // =============================================================================
    // VIEW FUNCTIONS - Only purchase tracking data
    // =============================================================================
    
    function getContractStats() external view returns (
        uint256 _totalPresaleVolume,
        uint256 _totalPublicVolume,
        uint256 _totalUsdtRaised,
        uint256 _totalUsdcRaised,
        uint256 _totalBnbRaised,
        SalePhase _phase
    ) {
        return (
            totalPresaleVolume,
            totalPublicVolume,
            totalUsdtRaised,
            totalUsdcRaised,
            totalBnbRaised,
            this.getCurrentPhase()
        );
    }
    
    function getUserInfo(address user) external view returns (UserPurchase memory purchase, ReferralInfo memory referral) {
        return (userPurchases[user], referralInfo[user]);
    }
    
    function getExpectedTokens(address user) external view returns (uint256 expectedFromPresale, uint256 expectedFromPublic) {
        UserPurchase memory purchase = userPurchases[user];
        
        if (purchase.presalePurchased > 0) {
            expectedFromPresale = (purchase.presalePurchased * 10**18) / saleConfig.presaleRate;
        }
        
        if (purchase.publicSalePurchased > 0) {
            // Use average public sale rate for estimation
            expectedFromPublic = (purchase.publicSalePurchased * 10**18) / saleConfig.publicSaleStartRate;
        }
        
        return (expectedFromPresale, expectedFromPublic);
    }
    
    function getTokenAmountForPayment(uint256 usdAmount, uint256 bnbAmount) external view returns (uint256 tokensFromUSD, uint256 tokensFromBNB) {
        uint256 currentRate = getCurrentRate();
        
        // If sale is not active, use presale rate for estimation
        if (currentRate == 0) {
            currentRate = saleConfig.presaleRate;
        }
        
        // Calculate tokens from USD amount (USDT/USDC)
        if (usdAmount > 0 && currentRate > 0) {
            tokensFromUSD = (usdAmount * 10**18) / currentRate;
        }
        
        // Calculate tokens from BNB amount
        if (bnbAmount > 0 && currentRate > 0 && address(bnbUsdPriceFeed) != address(0)) {
            uint256 bnbPriceUsd = getLatestBNBPriceUnchecked();
            if (bnbPriceUsd > 0) {
                // Convert BNB to USD (6 decimals)
                uint256 bnbInUsd = (bnbAmount * bnbPriceUsd) / (10**20);
                tokensFromBNB = (bnbInUsd * 10**18) / currentRate;
            }
        }
        
        return (tokensFromUSD, tokensFromBNB);
    }
    
    function getTotalStats() external view returns (
        uint256 _totalVolume,
        uint256 _totalPurchasers,
        uint256 _avgPurchaseSize,
        uint256 _currentRate
    ) {
        uint256 totalVolume = totalPresaleVolume + totalPublicVolume;
        uint256 avgSize = totalPurchasers > 0 ? totalVolume / totalPurchasers : 0;
        
        return (
            totalVolume,
            totalPurchasers,
            avgSize,
            getCurrentRate()
        );
    }
}