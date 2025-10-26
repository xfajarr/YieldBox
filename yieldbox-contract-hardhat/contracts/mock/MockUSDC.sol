// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockUSDC
 * @dev Mock USDC token for testing purposes
 * @notice This is a mock implementation of USDC for Base Sepolia testing
 */
contract MockUSDC is ERC20, Ownable {
    uint8 private _decimals;
    error ArrayLengthMismatch();
    
    constructor(
        address initialOwner,
        uint256 initialSupply,
        uint8 decimalsValue
    ) ERC20("USD Coin", "USDC") Ownable(initialOwner) {
        _decimals = decimalsValue;
        _mint(initialOwner, initialSupply);
    }
    
    /**
     * @dev Returns the number of decimals the token uses
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    /**
     * @dev Mint new tokens (only owner)
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @dev Burn tokens (only owner)
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
    
    /**
     * @dev Mint tokens for multiple addresses (only owner)
     * @param recipients Array of addresses to mint tokens to
     * @param amounts Array of amounts to mint
     */
    function mintBatch(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyOwner {
        if (recipients.length != amounts.length) revert ArrayLengthMismatch();
        
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
        }
    }
    
    /**
     * @dev Get token information
     */
    function getTokenInfo()
        external
        view
        returns (
            string memory tokenName,
            string memory tokenSymbol,
            uint8 decimalsValue,
            uint256 totalSupplyAmount
        )
    {
        return (name(), symbol(), decimals(), totalSupply());
    }
}
