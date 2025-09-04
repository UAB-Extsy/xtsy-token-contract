// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/AggregatorV3Interface.sol";

/**
 * @title xtsySale
 * @dev Clean, minimal presale contract with dynamic vesting for XTSY token
 * @notice Presale Price: $0.025 | Public Price: $0.10+ (dynamic)
 * @notice Vesting Categories:
 * - Presale (2%): 100% TGE
 * - Public Sale (6%): 100% TGE  
 * - Liquidity & Market Making (7%): 100% TGE
 * - Team & Advisors (15%): 12m cliff, 24m vest
 * - Ecosystem Growth (20%): 36m vest
 * - Treasury (25%): 6m lock, 36m vest
 * - Marketing & Partnerships (10%): 20% TGE, 6m vest
 */
contract xtsySale is ReentrancyGuard, Ownable, Pausable {
    
    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    IERC20 public saleToken;
    IERC20 public immutable usdtToken;
    IERC20 public immutable usdcToken;
    AggregatorV3Interface public ethUsdPriceFeed;
    
    enum SalePhase { NotStarted, PresaleWhitelist, PublicSale, Ended }
    SalePhase public currentPhase;
    
    // Vesting categories with their caps
    enum VestingCategory {
        Presale,                // 2% - 10M tokens
        PublicSale,             // 6% - 30M tokens  
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
        uint256 presaleRate;            // price per token in micro-USD (25000 = $0.025)
        uint256 publicSaleStartRate;    // initial price per token (100000 = $0.10)
        uint256 priceIncreaseInterval;  // 30 minutes (3 days scaled)
        uint256 priceIncreaseAmount;    // price increase (10000 = $0.01)
        uint256 whitelistDeadline;
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
        bool hasClaimedTGE;            // Whether TGE tokens claimed
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
        uint256 totalBonusEarned;       // Total bonus tokens earned
        uint256 bonusClaimed;           // Bonus tokens already claimed
    }
    
    mapping(address => ReferralInfo) public referralInfo;
    
    // =============================================================================
    // SALE TRACKING
    // =============================================================================
    
    mapping(address => bool) public whitelist;
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
    event WhitelistUpdated(address indexed user, bool status);
    event PhaseUpdated(SalePhase newPhase);
    event TGESet(uint256 timestamp);
    event FundsWithdrawn(uint256 usdtAmount, uint256 usdcAmount);
    
    // =============================================================================
    // ERRORS
    // =============================================================================
    
    error InvalidPhase();
    error NotWhitelisted();
    error SaleNotActive();
    error InsufficientTokensAvailable();
    error NoTokensToClaim();
    error InvalidConfiguration();
    error ZeroAddress();
    error ZeroAmount();
    error TGENotSet();
    error CliffNotReached();
    error CategoryCapExceeded();
    error AlreadyAllocated();
    
    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================
    
    constructor(
        address _saleToken,
        address _usdtToken,
        address _usdcToken,
        address _owner
    ) Ownable(_owner) {
        if (_usdtToken == address(0) || _usdcToken == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }
        
        // Sale token can be zero initially and set later
        if (_saleToken != address(0)) {
            saleToken = IERC20(_saleToken);
        }
        usdtToken = IERC20(_usdtToken);
        usdcToken = IERC20(_usdcToken);
        currentPhase = SalePhase.NotStarted;
        
        _initializeCategories();
        _initializeVestingConfigs();
    }
    
    // =============================================================================
    // INITIALIZATION
    // =============================================================================
    
    function _initializeCategories() private {
        // Set category caps (based on 500M total supply)
        categoryCaps[VestingCategory.Presale] = 10_000_000 * 10**18;         // 2%
        categoryCaps[VestingCategory.PublicSale] = 30_000_000 * 10**18;      // 6%
        categoryCaps[VestingCategory.Liquidity] = 35_000_000 * 10**18;       // 7%
        categoryCaps[VestingCategory.TeamAdvisors] = 75_000_000 * 10**18;    // 15%
        categoryCaps[VestingCategory.Ecosystem] = 100_000_000 * 10**18;      // 20%
        categoryCaps[VestingCategory.Treasury] = 125_000_000 * 10**18;       // 25%
        categoryCaps[VestingCategory.Marketing] = 50_000_000 * 10**18;       // 10%
    }
    
    function _initializeVestingConfigs() private {
        // Presale: 100% TGE
        vestingConfigs[VestingCategory.Presale] = VestingConfig(1000, 0, 0);
        
        // Public Sale: 100% TGE
        vestingConfigs[VestingCategory.PublicSale] = VestingConfig(1000, 0, 0);
        
        // Liquidity: 100% TGE
        vestingConfigs[VestingCategory.Liquidity] = VestingConfig(1000, 0, 0);
        
        // Team & Advisors: 12m cliff, 24m vest
        vestingConfigs[VestingCategory.TeamAdvisors] = VestingConfig(0, 12, 24);
        
        // Ecosystem: 36m vest (no cliff)
        vestingConfigs[VestingCategory.Ecosystem] = VestingConfig(0, 0, 36);
        
        // Treasury: 6m lock, 36m vest
        vestingConfigs[VestingCategory.Treasury] = VestingConfig(0, 6, 36);
        
        // Marketing: 20% TGE, 6m vest
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
    
    function setTGETimestamp(uint256 _tgeTimestamp) external onlyOwner {
        tgeTimestamp = _tgeTimestamp;
        emit TGESet(_tgeTimestamp);
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
    
    // =============================================================================
    // WHITELIST FUNCTIONS
    // =============================================================================
    
    function addToWhitelist() external onlyOwner {
        whitelist[msg.sender] = true;
        emit WhitelistUpdated(msg.sender, true);
    }
    
    function removeFromWhitelist(address user) external onlyOwner {
        whitelist[user] = false;
        emit WhitelistUpdated(user, false);
    }
    
    function addBatchToWhitelist(address[] calldata users) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            whitelist[users[i]] = true;
            emit WhitelistUpdated(users[i], true);
        }
    }
    
    // =============================================================================
    // PHASE MANAGEMENT
    // =============================================================================
    
    function updatePhase() public {
        SalePhase newPhase = getCurrentPhase();
        if (newPhase != currentPhase) {
            currentPhase = newPhase;
            emit PhaseUpdated(newPhase);
        }
    }
    
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
    
    function buyTokensWithUSDT(uint256 usdtAmount) external nonReentrant whenNotPaused {
        _buyTokens(usdtAmount, true, address(0));
    }
    
    function buyTokensWithUSDC(uint256 usdcAmount) external nonReentrant whenNotPaused {
        _buyTokens(usdcAmount, false, address(0));
    }
    
    function buyTokensWithUSDTAndReferral(uint256 usdtAmount, address referrer) external nonReentrant whenNotPaused {
        _buyTokens(usdtAmount, true, referrer);
    }
    
    function buyTokensWithUSDCAndReferral(uint256 usdcAmount, address referrer) external nonReentrant whenNotPaused {
        _buyTokens(usdcAmount, false, referrer);
    }
    
    function buyTokensWithETH() external payable nonReentrant whenNotPaused {
        _buyTokensWithETH(address(0));
    }
    
    function buyTokensWithETHAndReferral(address referrer) external payable nonReentrant whenNotPaused {
        _buyTokensWithETH(referrer);
    }
    
    function _buyTokens(uint256 usdAmount, bool isUsdt, address referrer) private {
        updatePhase();
        
        if (currentPhase == SalePhase.NotStarted || currentPhase == SalePhase.Ended) {
            revert SaleNotActive();
        }
        
        if (currentPhase == SalePhase.PresaleWhitelist && !whitelist[msg.sender]) {
            revert NotWhitelisted();
        }
        
        if (usdAmount == 0) revert ZeroAmount();
        
        // Calculate tokens to allocate
        uint256 currentRate = getCurrentRate();
        uint256 tokensToAllocate = (usdAmount * 10**18) / currentRate;
        
        // Check caps
        if (currentPhase == SalePhase.PresaleWhitelist) {
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
        
        // Transfer payment
        IERC20 paymentToken = isUsdt ? usdtToken : usdcToken;
        paymentToken.transferFrom(msg.sender, address(this), usdAmount);
        
        // Update user purchase data
        UserPurchase storage purchase = userPurchases[msg.sender];
        if (currentPhase == SalePhase.PresaleWhitelist) {
            purchase.presalePurchased += usdAmount;
        } else {
            purchase.publicSalePurchased += usdAmount;
        }
        purchase.tokensAllocated += tokensToAllocate;
        
        // Handle referral
        uint256 referrerBonus = 0;
        if (referralEnabled && referrer != address(0) && referrer != msg.sender) {
            purchase.referrer = referrer;
            referrerBonus = (tokensToAllocate * referralBonusPercent) / 1000;
            
            ReferralInfo storage refInfo = referralInfo[referrer];
            refInfo.totalReferred++;
            refInfo.totalReferralVolume += usdAmount;
            refInfo.totalBonusEarned += referrerBonus;
            
            emit TokensPurchasedWithReferral(msg.sender, referrer, usdAmount, tokensToAllocate, referrerBonus);
        } else {
            emit TokensPurchased(msg.sender, usdAmount, tokensToAllocate, currentPhase);
        }
        
        // Update totals
        if (isUsdt) {
            totalUsdtRaised += usdAmount;
        } else {
            totalUsdcRaised += usdAmount;
        }
    }
    
    function _buyTokensWithETH(address referrer) private {
        updatePhase();
        
        if (currentPhase == SalePhase.NotStarted || currentPhase == SalePhase.Ended) {
            revert SaleNotActive();
        }
        
        if (currentPhase == SalePhase.PresaleWhitelist && !whitelist[msg.sender]) {
            revert NotWhitelisted();
        }
        
        if (msg.value == 0) revert ZeroAmount();
        
        // Get ETH price in USD (with 8 decimals from Chainlink)
        uint256 ethPriceUsd = getLatestETHPrice();
        
        // Convert ETH amount to USD (6 decimals to match USDT/USDC)
        // msg.value is in wei (18 decimals), ethPriceUsd is 8 decimals
        // Result should be 6 decimals: (18 + 8 - 18 - 2) = 6
        uint256 usdAmount = (msg.value * ethPriceUsd) / (10**20);
        
        // Calculate tokens to allocate
        uint256 currentRate = getCurrentRate();
        uint256 tokensToAllocate = (usdAmount * 10**18) / currentRate;
        
        // Check caps
        if (currentPhase == SalePhase.PresaleWhitelist) {
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
        
        // Update user purchase data
        UserPurchase storage purchase = userPurchases[msg.sender];
        if (currentPhase == SalePhase.PresaleWhitelist) {
            purchase.presalePurchased += usdAmount;
        } else {
            purchase.publicSalePurchased += usdAmount;
        }
        purchase.tokensAllocated += tokensToAllocate;
        
        // Handle referral
        uint256 referrerBonus = 0;
        if (referralEnabled && referrer != address(0) && referrer != msg.sender) {
            purchase.referrer = referrer;
            referrerBonus = (tokensToAllocate * referralBonusPercent) / 1000;
            
            ReferralInfo storage refInfo = referralInfo[referrer];
            refInfo.totalReferred++;
            refInfo.totalReferralVolume += usdAmount;
            refInfo.totalBonusEarned += referrerBonus;
            
            emit TokensPurchasedWithReferral(msg.sender, referrer, usdAmount, tokensToAllocate, referrerBonus);
        } else {
            emit TokensPurchased(msg.sender, usdAmount, tokensToAllocate, currentPhase);
        }
        
        // Update ETH total
        totalEthRaised += msg.value;
    }
    
    function getLatestETHPrice() public view returns (uint256) {
        if (address(ethUsdPriceFeed) == address(0)) revert ZeroAddress();
        
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        
        return uint256(price);
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
    
    function claimTGETokens() external nonReentrant {
        if (address(saleToken) == address(0)) revert ZeroAddress();
        if (tgeTimestamp == 0 || block.timestamp < tgeTimestamp) {
            revert TGENotSet();
        }
        
        UserPurchase storage purchase = userPurchases[msg.sender];
        if (purchase.hasClaimedTGE) revert NoTokensToClaim();
        
        uint256 totalClaimable = purchase.tokensAllocated;
        
        // Add referral bonus
        ReferralInfo storage refInfo = referralInfo[msg.sender];
        totalClaimable += refInfo.totalBonusEarned;
        
        if (totalClaimable == 0) revert NoTokensToClaim();
        
        purchase.hasClaimedTGE = true;
        purchase.tokensClaimed = totalClaimable;
        refInfo.bonusClaimed = refInfo.totalBonusEarned;
        
        saleToken.transfer(msg.sender, totalClaimable);
        emit TokensClaimed(msg.sender, VestingCategory.Presale, totalClaimable);
    }
    
    function claimVestedTokens(VestingCategory category) external nonReentrant {
        if (address(saleToken) == address(0)) revert ZeroAddress();
        if (tgeTimestamp == 0) revert TGENotSet();
        
        UserAllocation storage allocation = userAllocations[msg.sender][category];
        if (allocation.totalAllocated == 0) revert NoTokensToClaim();
        
        uint256 claimableAmount = getClaimableAmount(msg.sender, category);
        if (claimableAmount == 0) revert NoTokensToClaim();
        
        allocation.claimedAmount += claimableAmount;
        saleToken.transfer(msg.sender, claimableAmount);
        
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
            usdtToken.transfer(owner(), usdtBalance);
        }
        if (usdcBalance > 0) {
            usdcToken.transfer(owner(), usdcBalance);
        }
        if (ethBalance > 0) {
            payable(owner()).transfer(ethBalance);
        }
        
        emit FundsWithdrawn(usdtBalance, usdcBalance);
    }
    
    function emergencyTokenWithdraw() external onlyOwner {
        uint256 balance = saleToken.balanceOf(address(this));
        if (balance > 0) {
            saleToken.transfer(owner(), balance);
        }
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
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
    
    function getCategoryInfo(VestingCategory category) external view returns (uint256 cap, uint256 allocated, VestingConfig memory config) {
        return (categoryCaps[category], categoryAllocated[category], vestingConfigs[category]);
    }
    
    function getContractStats() external view returns (
        uint256 _totalPresaleSold,
        uint256 _totalPublicSaleSold, 
        uint256 _totalUsdtRaised,
        uint256 _totalUsdcRaised,
        uint256 _totalEthRaised,
        SalePhase _currentPhase
    ) {
        return (totalPresaleSold, totalPublicSaleSold, totalUsdtRaised, totalUsdcRaised, totalEthRaised, getCurrentPhase());
    }
}