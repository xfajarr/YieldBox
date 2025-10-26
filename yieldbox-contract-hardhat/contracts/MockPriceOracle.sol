// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockPriceOracle
 * @dev Mock price oracle for testing - provides fixed USD/IDR exchange rate
 * @notice 1 USD = Rp 16,500 (Indonesian Rupiah)
 */
contract MockPriceOracle is Ownable {
    // Price with 2 decimals: 16,500 = 1650000 (represents Rp 16,500.00)
    uint256 public constant IDR_PER_USD = 1650000; // 16,500.00 with 2 decimals
    uint256 public constant DECIMALS = 2;
    
    struct TokenPrice {
        uint256 priceUsd; // Price in USD with 2 decimals
        uint256 lastUpdated;
        bool active;
    }
    
    mapping(address => TokenPrice) private _tokenPrices;
    address[] private _supportedTokens;
    
    event PriceUpdated(address indexed token, uint256 priceUsd, uint256 timestamp);
    event TokenAdded(address indexed token, uint256 priceUsd);
    event TokenRemoved(address indexed token);
    
    error TokenNotSupported(address token);
    error InvalidPrice();
    error ZeroAddress();
    
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    /**
     * @notice Sets the price for a token in USD
     * @param token The token address
     * @param priceUsd The price in USD (2 decimals, e.g., 100 = $1.00)
     */
    function setTokenPrice(address token, uint256 priceUsd) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (priceUsd == 0) revert InvalidPrice();
        
        bool exists = _tokenPrices[token].lastUpdated > 0;
        
        _tokenPrices[token] = TokenPrice({
            priceUsd: priceUsd,
            lastUpdated: block.timestamp,
            active: true
        });
        
        if (!exists) {
            _supportedTokens.push(token);
            emit TokenAdded(token, priceUsd);
        }
        
        emit PriceUpdated(token, priceUsd, block.timestamp);
    }
    
    /**
     * @notice Sets prices for multiple tokens in a single transaction
     * @param tokens Array of token addresses
     * @param pricesUsd Array of prices in USD (2 decimals)
     */
    function setTokenPricesBatch(
        address[] calldata tokens,
        uint256[] calldata pricesUsd
    ) external onlyOwner {
        require(tokens.length == pricesUsd.length, "Length mismatch");
        
        uint256 length = tokens.length;
        for (uint256 i = 0; i < length;) {
            if (tokens[i] == address(0)) revert ZeroAddress();
            if (pricesUsd[i] == 0) revert InvalidPrice();
            
            bool exists = _tokenPrices[tokens[i]].lastUpdated > 0;
            
            _tokenPrices[tokens[i]] = TokenPrice({
                priceUsd: pricesUsd[i],
                lastUpdated: block.timestamp,
                active: true
            });
            
            if (!exists) {
                _supportedTokens.push(tokens[i]);
                emit TokenAdded(tokens[i], pricesUsd[i]);
            }
            
            emit PriceUpdated(tokens[i], pricesUsd[i], block.timestamp);
            unchecked { ++i; }
        }
    }
    
    /**
     * @notice Removes a token from the oracle
     * @param token The token address to remove
     */
    function removeToken(address token) external onlyOwner {
        if (!_tokenPrices[token].active) revert TokenNotSupported(token);
        
        _tokenPrices[token].active = false;
        emit TokenRemoved(token);
    }
    
    /**
     * @notice Gets the USD price for a token
     * @param token The token address
     * @return priceUsd The price in USD (2 decimals)
     */
    function getTokenPriceUsd(address token) external view returns (uint256 priceUsd) {
        TokenPrice memory price = _tokenPrices[token];
        if (!price.active) revert TokenNotSupported(token);
        return price.priceUsd;
    }
    
    /**
     * @notice Gets the IDR price for a token
     * @param token The token address
     * @return priceIdr The price in IDR (2 decimals)
     */
    function getTokenPriceIdr(address token) external view returns (uint256 priceIdr) {
        TokenPrice memory price = _tokenPrices[token];
        if (!price.active) revert TokenNotSupported(token);
        
        // Convert USD to IDR: priceUsd * IDR_PER_USD / 100 (to maintain 2 decimals)
        return (price.priceUsd * IDR_PER_USD) / 100;
    }
    
    /**
     * @notice Converts USD amount to IDR
     * @param amountUsd Amount in USD (2 decimals)
     * @return amountIdr Amount in IDR (2 decimals)
     */
    function convertUsdToIdr(uint256 amountUsd) external pure returns (uint256 amountIdr) {
        return (amountUsd * IDR_PER_USD) / 100;
    }
    
    /**
     * @notice Converts IDR amount to USD
     * @param amountIdr Amount in IDR (2 decimals)
     * @return amountUsd Amount in USD (2 decimals)
     */
    function convertIdrToUsd(uint256 amountIdr) external pure returns (uint256 amountUsd) {
        return (amountIdr * 100) / IDR_PER_USD;
    }
    
    /**
     * @notice Gets token price information
     * @param token The token address
     * @return price The token price struct
     */
    function getTokenInfo(address token) external view returns (TokenPrice memory price) {
        return _tokenPrices[token];
    }
    
    /**
     * @notice Gets all supported token addresses
     * @return tokens Array of supported token addresses
     */
    function getSupportedTokens() external view returns (address[] memory tokens) {
        return _supportedTokens;
    }
    
    /**
     * @notice Gets the USD/IDR exchange rate
     * @return rate The exchange rate (1 USD = rate IDR, with 2 decimals)
     */
    function getUsdIdrRate() external pure returns (uint256 rate) {
        return IDR_PER_USD;
    }
}