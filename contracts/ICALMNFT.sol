// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title Content addressed NFT lazy minting standard (CALM)
 * Note: The ERC-165 identifier for this interface is 0x105ce913.
 */
interface ICALMNFT /* is ERC165 */ {
    struct MintPermit {
        uint256 tokenId;
        uint256 nonce;
        address currency; // using the zero address means Ether
        uint256 minimumPrice;
        address payee;
        uint256 kickoff;
        uint256 deadline;
        address recipient; // using the zero address means anyone can claim
        bytes data;
    }

    /**
     * @dev Call this function to buy a not yet minted NFT
     * @param permit The MintPermit signed by the NFT creator
     * @param recipient The address that will receive the newly minted NFT
     * @param v The v portion of the secp256k1 permit signature
     * @param r The r portion of the secp256k1 permit signature
     * @param s The s portion of the secp256k1 permit signature
     */
    function claim(
        MintPermit calldata permit,
        address recipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    /**
     * @dev this function should revoke all permits issued for token ID `tokenId` with nonce lower than `nonce`
     * @param tokenId the token ID for which to revoke permits
     * @param nonce to cancel a permit for a given tokenId we suggest passing the account transaction count as `nonce`
     */
    function revokeMintPermitsUnderNonce(uint256 tokenId, uint256 nonce)
        external;
}
