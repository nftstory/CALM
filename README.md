# [Solutions Bounty] Content Addressed Lazy Minting (CALM)

[Bounty](https://gitcoin.co/issue/GreenNFT/GreenNFTs/1/)

[Github Repo](https://github.com/nftstory/CALM)

[MATIC CALM721 Contract](https://explorer-mainnet.maticvigil.com/address/0xa9cC685d44d083E43f19B041931ABA04995df0db)

## Summary
In the interest of making NFTs as ecologically responsible as possible, we propose an open source lazy minting standard called Content Addressed Lazy Minting (CALM) and an open source reference implementation. We also provide access to a deployed version of the contract on Matic.

## Rationale

The ecological impact of NFTs has become a matter of public interest and concern since NFTs achieved mainstream awareness in early 2021.

In the interest of making NFTs as ecologically responsible as possible, in the first section, we propose an open source lazy minting standard called Content Addressed Lazy Minting (CALM), and an open source reference implementation. 

Together, the CALM standard and reference implementation aim to make gas-efficient NFT minting accessible to all, so that present and future platforms may enable more participants to enter the NFT space on the most trustworthy blockchain, while also reducing block space consumed by NFTs that are never purchased or transferred.

In the second section, we present a deployment of the CALM standard on Matic, the Layer 2 EVM blockchain. This section demonstrates that the ecological advantages of NFTs on Proof of Stake (PoS) blockchains are available today. We assert that EVM-based Layer 2 solutions provide a superior compromise between security and ecological cost than non-EVM chains such as Tezos and Flow, while also maintaining compatibility with popular ecosystem tooling such as MetaMask, OpenSea, and Hardhat.

## Layer 1 Scaling Solution: Content Addressed Lazy Minting (CALM)

### Lazy Minting
Content Addressed Lazy Minting is an extension and improvement upon the lazy minting technique [introduced by OpenSea on December 29, 2020](https://opensea.io/blog/announcements/introducing-the-collection-manager/). When lazy minting, the creator signs a permit stating their willingness to create a given NFT, and uploads it to the minting platform off-chain. The platform serves this permit to potential buyers through their website. Should a buyer choose to purchase the NFT, they execute an on-chain transaction including the signed permit. The lazy minting contract confirms that the permit is legitimate, then mints the token and immediately transfers it to the buyer. The token's on-chain provenance correctly identifies the NFT creator as the minter. 

OpenSea explains the mechanism of their [presently closed-source lazy minting implementation](https://etherscan.io/address/0x495f947276749ce646f68ac8c248420045cb7b5e#code) as follows. "When you create an NFT, you encode your address and its total supply in the token’s ID. That way, no one except you can mint more of them, and buyers can count on a hard cap on supply that’s enforced by code." ([OpenSea](https://opensea.io/blog/announcements/introducing-the-collection-manager/)).

Mintable's ["gasless" lazy minting contract](https://etherscan.io/address/0x8c5aCF6dBD24c66e6FD44d4A4C3d7a2D955AAad2#code) is also to our knowledge closed source at present. 

In addition to its gas saving environmental benefits, by dint of being open source, CALM enables NFT creators to deploy their own minting contracts to Ethereum. We believe that enabling NFT creators to deploy their own contracts will increase their participation in network governance. If NFT creators express their concerns, such as their interest in the environmental impact of consensus mechanisms to the core development community, this will positively affect the prioritization of more ecological solutions.

Accomplished NFT artists such as Murat Pak have [appealed to NFT platforms on Twitter](https://twitter.com/muratpak/status/1362900587247992833) to broaden support for lazy minting for its ecological and cost-saving advantages. In the next subsection, we explain in detail how CALM NFTs answer the call for an open source lazy minting standard, while also introducing guaranteed NFT immutability, thus eliminating the risk of [NFT rug pulls](https://twitter.com/neitherconfirm/status/1369285946198396928).

### Content Addressed Lazy Minting (CALM) Technical Explanation

Content Addressed Lazy Minted (CALM) NFTs employ content address token IDs to permit the future minting of a given NFT with additional security affordances beyond existing implementations. We achieve this by concatenating a shortened identifier of the creator's Ethereum address and the SHA1 digest (the hash) of the NFT JSON metadata to obtain a `tokenId`. 

Complete CALM implementations for both ERC-721 and ERC-1155 are [available on Github](https://github.com/nftstory/CALM).

We call these content-addressed NFTs because a given token ID created using this method is provably unique to its JSON metadata and creator.

A contract using this strategy would only mint tokens with IDs that pack a certain data structure. In the example below we demonstrate Solidity code that makes use of this structure.

The following code gets the id of a CALM NFT given a JSON metadata SHA1 digest `metadataSHA1` and a creator address `msg.sender`.

```solidity
function computeTokenId(uint160 metadataSHA1) external pure returns (uint256 tokenId) {

    // Compute a 96bit (12 bytes) id for the creator based on ther Ethereum address (160 bits / 20 bytes) and the metadata SHA1 digest
    bytes12 tokenSpecificCreatorIdentifier = bytes12(keccak256(abi.encode(msg.sender)));

    // Pack `metadataSHA1` (160bit) and `tokenSpecificCreatorIdentifier` (96bit) into a 256bit uint that will be our token id
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
             SHA1 digest of JSON metadata     Token specific creator identifier
                                             
                                             (truncated keccak256 digest of
                                             metadata SHA1 and ethereum address)

```

`computeTokenId` is a pure view function so it may be called without executing a transaction on-chain.

Mint must be called to save the token ownership on-chain. For example:

```solidity
function mint(uint256 tokenId, address creatorAddress, address recipient) {
    // Verify that the truncated keccak256 digest of the creatorAddress (tokenSpecificCreatorIdentifier) passed as an argument matches the last 96 bits in the tokenId
    require(tokenIdMatchesCreator(tokenId, creatorAddress), "lazy-mint/creator-does-not-correspond-to-id");
    
    // Mint happens here
    // _mintOne is implementation specific, see https://eips.ethereum.org/EIPS/eip-721 or https://eips.ethereum.org/EIPS/eip-1155
    _mintOne(creatorAddress, tokenId);
    
    // The `msg.sender` can choose who will receive the NFT
    // TransferFrom is implementation specific, see https://eips.ethereum.org/EIPS/eip-721 or https://eips.ethereum.org/EIPS/eip-1155
    transferFrom(creatorAddress, recipient, tokenId);
}
```

### Notes on IPFS compatibility
IPFS can be used to retrieve files with their SHA1 digest if those were uploaded to the network as raw leaves. This can be done with the following command.

```shell=
ipfs add --raw-leaves --hash=sha1 <path>
```

An IPFS CID can also be constructed from a SHA1 digest.

JavaScript example:

```Javascript
import CID from 'cids'
import multihashes from 'multihashes'

const SHA1_DIGEST = '2fd4e1c67a2d28fced849ee1bb76e7391b93eb12'
const sha1Buffer = Buffer.from(SHA1_DIGEST, 'hex')

const multihash = multihashes.encode(sha1Buffer, 'sha1')

const cid = new CID(1, 'raw', multihash)
```

Or more succintly, taking advantage of the base16 encoding of CIDs:

```Javascript
const SHA1_DIGEST = '2fd4e1c67a2d28fced849ee1bb76e7391b93eb12'

//IPFS v1 CIDS that are pointing to SHA1 raw leaves always start with f01551114 in base16 (hex) form
const cid = `f01551114${SHA1_DIGEST}`
```

## Layer 2 Scaling Solution: CALM on Matic

### Why Layer 2? 

While CALM NFTs reduce the ecological impact of NFT creation, all subsequent transaction activity (e.g., minting, selling, transferring) remains on the blockchain. 

Ethereum's Mainnet (L1) uses a Proof of Work (PoW) consensus mechanism at present ([Ethereum Foundation](https://ethereum.org/en/developers/docs/consensus-mechanisms/pow/)). PoW blockchain mining is the energy intensive process responsible for the ecological concerns surrounding NFTs ([NYTimes](https://www.nytimes.com/2021/04/14/climate/coinbase-cryptocurrency-energy.html)). Eth2, the upcoming Ethereum protocol upgrade, will transition the blockchain from PoW to Proof of Stake (PoS), a consensus mechanism with a negligible ecological impact ([Ethereum Foundation](https://ethereum.org/en/eth2/merge/)). The Eth2 upgrade is planned to arrive in 2021 or 2022.

Until Eth2 arrives, NFT activity on Ethereum can be argued to incentivize PoW mining by consuming L1 block space, thus adding congestion to the network, driving up gas prices, and increasing miner rewards. NFT critics argue that planned upgrades are an insufficient argument to justify NFT minting on Ethereum's PoW L1 today ([Memo Akten](https://memoakten.medium.com/the-unreasonable-ecological-cost-of-cryptoart-2221d3eb2053)). 

In the absence of PoS Ethereum Mainnet, some NFT artists have migrated their practices to alternative L1 PoS blockchains such as Tezos and Flow (see [Hic et Nunc](https://www.hicetnunc.xyz/) and [Versus](https://www.versus-flow.art/) platforms). These blockchains exhibit inferior security due to [relatively centralized token ownership](https://www.onflow.org/token-distribution#:~:text=phase%20ii%3A%20token%20generation%20and%20distribution) and [governance uncertainty](https://www.coindesk.com/tezos-investors-win-25m-settlement-in-court-case-over-230m-ico). Moreover, these blockchains fracture the NFT marketplace because they are not [Ethereum Virtual Machine (EVM)](https://ethereum.org/en/developers/docs/evm/) based. This makes them incompatible with existing ecosystem tools and platforms such as OpenSea marketplace, MetaMask and other Ethereum-compatible wallets, and development tooling such as Hardhat.

To further reduce the ecological impact of NFTs while delivering creators high security NFTs, we present a deployment of the CALM standard to the Matic PoS chain, a Layer 2 EVM network ([Matic PoS Chain](https://docs.matic.network/docs/develop/ethereum-matic/pos/getting-started/)). Matic PoS chain delivers the ecological and EVM gas saving advantages of Eth2, today, while maintaining compatibility with existing Ethereum wallets, NFT EIP standards, development languages, and tooling ([Bankless](https://www.youtube.com/watch?v=rCJUBUTFElE)). Matic's Ethereum-Matic Bridge also enables NFTs to be transferred between Ethereum L1, Matic, and future EVM chains with the help of Polygon and equivalent multichain infrastructure ([Matic Bridge](https://docs.matic.network/docs/develop/ethereum-matic/getting-started/)).

In addition to Matic, CALM is natively compatible with all EVM Layer 1 and Layer 2 blockchains, such as xDai, Fantom, and Binance Smart Chain. CALM will also be relevant for use in conjunction with forthcoming rollups such as Optimism's OVM and Arbitrum. Rapid adoption of nascent rollup technology has even accelerated the Eth2 PoS transition timeline ([Consensys](https://consensys.net/blog/ethereum-2-0/proof-of-stake-is-coming-to-ethereum-sooner-than-we-think/#:~:text=this%20also%20means%20that%20moving%20ethereum%20off%20proof%20of%20work%20and%20onto%20proof%20of%20stake%20can%20happen%20even%20sooner%2C%20perhaps%20this%20year.%20)). 

### CALM on Matic

CALM is deployed to the Matic chain (see contract address [here](https://github.com/nftstory/CALM/blob/main/addresses/CALM721.json)). Instructions for interacting with the contract are [available on Github](https://github.com/nftstory/CALM).

We will be deploying an interface to interact with an extended version of the CALM on Matic contract on [nftstory.life](https://nftstory.life) later this month (May 2021). An alpha version of that interface is currently available on Rinkeby at [rinkeby.nftstory.life](https://rinkeby.nftstory.life). Access to the Rinkeby alpha is currently restricted to whitelisted accounts. We invite you to send us your Rinkeby wallet address so that we may add you to the whitelist. Please contact dev at nftstory.life.

## Next Steps

If there is interest amongst the developer community, we would be interested in formalizing and refining the CALM standard through the EIP process.

Should this submission win the GreenNFT bounty, we intend to use the reward to refine our existing submission with a professional contract audit.

If you have additional ideas for funding the auditing and development of this contract and related NFT minting tools, please contact us at dev at nftstory.life or https://twitter.com/nnnnicholas.

# Project structures

`contracts/` contains both the CALM solidity interface and ERC721 as well as ERC1155 reference implementations

`docs/` contains minimal documentation for content addressed token IDs, the contract expands on this with EIP-712 mint permits

`test` minimal tests, can be used as a reference on how to talk to the contracts