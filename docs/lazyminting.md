# Lazy Minting Content-Addressed NFTs

Our lazy minted NFTs employ content address token IDs to permit the future minting of a given NFT. We achieve this by concatenating a shortened identifier of the creator's Ethereum address and the SHA1 digest (the hash) of the NFT JSON metadata to obtain a `tokenId`. 

We call these content-addressed NFTs because a given token ID created using this method is provably unique to its JSON metadata and creator.

A contract using this strategy would only mint tokens with IDs that pack a a certain data structure. In the example below we demonstrate Solidity code that makes use of this structure.

The code to get the id of a to-be-minted NFT looks like this, given a JSON metadata SHA1 digest `metadataSHA1` and a creator address `msg.sender`.

```solidity
function computeTokenId(uint160 metadataSHA1) external pure returns (uint256 tokenId) {

    //compute a 96bit (12 bytes) id for the creator based on ther Ethereum address (160 bits / 20 bytes) and the metadata SHA1 digest
    bytes12 tokenSpecificCreatorIdentifier = bytes12(keccak256(abi.encode(msg.sender)));

    //pack `metadataSHA1` (160bit) and `tokenSpecificCreatorIdentifier` (96bit) into a 256bit uint that will be our token id
    uint256 tokenId =
        bytesToUint256(
            abi.encodePacked(metadataSHA1, tokenSpecificCreatorIdentifier)
        );

    return tokenId;
}
```


Example token ID:
```
0x7c54dd4d58f49026d084c3edd77bcccb8d08c9e4029fa8c2b3aeba73ac39ba1f
--|----------------------160bit------------------|-----96bit-----|
                           |                                 |
                           |                                 |
                           |                                 |
                           |                                 |
                           |                                 |
             SHA1 digest of JSON metadata     token specific creator identifier
                                             
                                             (truncated keccak256 digest of
                                             metadata SHA1 and ethereum address)

```

`computeTokenId` is a pure view function so it's free to call. It doesn't save anything on the blockchain.


Mint needs to be called to save the token ownership on-chain. For example:


```solidity
//we need to pass creatorAddress as an argument because the id only contains a hash of it
function mint(uint256 tokenId, address creatorAddress, address recipient) {
    //verify that the truncated keccak256 digest of the creatorAddress (tokenSpecificCreatorIdentifier) passed as an argument matches the last 96 bits in the tokenId
    require(tokenIdMatchesCreator(tokenId, creatorAddress), "lazy-mint/creator-does-not-correspond-to-id");
    
    //mint happens here
    //_mintOne is implementation specific, see https://eips.ethereum.org/EIPS/eip-721 or https://eips.ethereum.org/EIPS/eip-1155
    _mintOne(creatorAddress, tokenId);
    
    //the person who pays for gas can decide who will receive the freshly minted nft
    //transferFrom is implementation specific, see https://eips.ethereum.org/EIPS/eip-721 or https://eips.ethereum.org/EIPS/eip-1155
    transferFrom(creatorAddress, recipient, tokenId);
}
```

<br/>

# Notes on IPFS compatibility
IPFS can be used to retrieve files with their SHA1 digest if those were uploaded to the network as raw leaves

This can be done with the following command

```shell=
ipfs add --raw-leaves --hash=sha1 <path>
```

An IPFS CID can also be constructed from a SHA1 digest

Javascript example : 
```javascript
import CID from 'cids'
import multihashes from 'multihashes'

const SHA1_DIGEST = '2fd4e1c67a2d28fced849ee1bb76e7391b93eb12'
const sha1Buffer = Buffer.from(SHA1_DIGEST, 'hex')

const multihash = multihashes.encode(sha1Buffer, 'sha1')

const cid = new CID(1, 'raw', multihash)
```

Or more succintly, taking advantage of the base16 encoding of CIDs
```javascript
const SHA1_DIGEST = '2fd4e1c67a2d28fced849ee1bb76e7391b93eb12'

//IPFS v1 CIDS that are pointing to SHA1 raw leaves always start with f01551114 in base16 (hex) form
const cid = `f01551114${SHA1_DIGEST}`
```