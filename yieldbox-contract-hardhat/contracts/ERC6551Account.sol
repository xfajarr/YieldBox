// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./lib/ERC6551BytecodeLib.sol";
import "./interfaces/IERC6551Account.sol";

/**
 * @title ERC6551Account
 * @dev Token-bound account implementation with reentrancy protection
 * @notice Each NFT gets its own smart contract wallet via this implementation
 */
contract ERC6551Account is IERC165, IERC1271, IERC6551Account, ReentrancyGuard {
    uint256 private _nonce;

    error CallerNotTokenOwner();
    error CallFailed(bytes returnData);
    error InvalidChain();
    error LockedAccount();

    event CallExecuted(address indexed to, uint256 value, bytes data, bytes result);

    receive() external payable {}

    /**
     * @notice Executes a call from the token-bound account
     * @dev Only callable by the NFT owner, includes reentrancy protection
     * @param to The address to call
     * @param value The ETH value to send
     * @param data The calldata to send
     * @return result The result of the call
     */
    function executeCall(
        address to, 
        uint256 value, 
        bytes calldata data
    ) external payable nonReentrant returns (bytes memory result) {
        address accountOwner = owner();
        if (msg.sender != accountOwner) revert CallerNotTokenOwner();

        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            // Bubble up the revert reason
            if (result.length > 0) {
                assembly {
                    revert(add(result, 32), mload(result))
                }
            } else {
                revert CallFailed(result);
            }
        }

        unchecked {
            ++_nonce;
        }

        emit CallExecuted(to, value, data, result);
    }

    /**
     * @notice Returns the token that owns this account
     * @return chainId The chain ID where the token exists
     * @return tokenContract The address of the NFT contract
     * @return tokenId The ID of the NFT token
     */
    function token() public view returns (uint256 chainId, address tokenContract, uint256 tokenId) {
        uint256 length = address(this).code.length;
        return abi.decode(
            Bytecode.codeAt(address(this), length - 0x60, length),
            (uint256, address, uint256)
        );
    }

    /**
     * @notice Returns the owner of the NFT that controls this account
     * @return The address of the NFT owner, or address(0) if on wrong chain
     */
    function owner() public view returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = this.token();
        
        if (chainId != block.chainid) return address(0);

        return IERC721(tokenContract).ownerOf(tokenId);
    }

    /**
     * @notice Returns the current nonce of this account
     * @dev Nonce increments with each successful transaction
     * @return The current nonce value
     */
    function nonce() public view returns (uint256) {
        return _nonce;
    }

    /**
     * @notice Checks if this contract supports a given interface
     * @param interfaceId The interface identifier to check
     * @return true if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return (
            interfaceId == type(IERC165).interfaceId || 
            interfaceId == type(IERC6551Account).interfaceId
        );
    }

    /**
     * @notice Validates a signature for this account (ERC-1271)
     * @dev Checks if the signature is valid for the NFT owner
     * @param hash The hash of the data that was signed
     * @param signature The signature to validate
     * @return magicValue The ERC-1271 magic value if valid, empty bytes otherwise
     */
    function isValidSignature(
        bytes32 hash, 
        bytes memory signature
    ) external view returns (bytes4 magicValue) {
        address accountOwner = owner();
        
        bool isValid = SignatureChecker.isValidSignatureNow(
            accountOwner, 
            hash, 
            signature
        );

        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }

        return bytes4(0);
    }
}