import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";
import { BigNumberish, Bytes } from "ethers";
import { ethers } from "hardhat";
import { CALM721, CALM721__factory } from "../typechain"
import crypto from "crypto"
import NFTMetadataJSON from "./fixtures/NFTmetatada.json"

const NFTMetadata = NFTMetadataJSON as any[]

export function getSHA1(input: Buffer) {
    // for ipfs : ipfs.add(metadata, { hashAlg: 'sha1', rawLeaves: true })
    return `0x${crypto.createHash('sha1').update(input).digest('hex')}`
}

function computeTokenIdFromMetadata(metadata: Buffer, creatorAddress: string) {
    const sha1 = getSHA1(metadata);
    const creatorAddrHash = ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['uint160', 'address'], [sha1, creatorAddress]));

    return ethers.BigNumber.from(sha1).toHexString() + creatorAddrHash.slice(2).substr(0, 24);
}

export async function getMintPermitForId(tokenId: BigNumberish,
    signer: SignerWithAddress,
    contract: CALM721,
    permitFields: {
        nonce?: number,
        currency?: string,
        minimumPrice?: string,
        payee?: string,
        kickoff?: number,
        deadline?: number,
        recipient?: string,
        data?: Bytes
    }
) {
    const signedData = {
        EIP712Version: '4',
        domain: {
            name: await contract.name(),
            version: '1',
            chainId: ethers.BigNumber.from(await signer.getChainId()),
            verifyingContract: contract.address
        },
        types: {
            MintPermit: [
                { name: 'tokenId', type: 'uint256' },
                { name: 'nonce', type: 'uint256' },
                { name: 'currency', type: 'address' },
                { name: 'minimumPrice', type: 'uint256' },
                { name: 'payee', type: 'address' },
                { name: 'kickoff', type: 'uint256' },
                { name: 'deadline', type: 'uint256' },
                { name: 'recipient', type: 'address' },
                { name: 'data', type: 'bytes' },
            ],
        },
        primaryType: 'MintPermit',
        message: {
            tokenId,
            nonce: permitFields?.nonce ?? await signer.getTransactionCount(),
            currency: permitFields?.currency ?? "0x0000000000000000000000000000000000000000", //using the zero address means Ether
            minimumPrice: permitFields?.minimumPrice ?? "0",
            payee: permitFields?.payee ?? signer.address,
            kickoff: permitFields?.kickoff ?? Math.floor(Date.now() / 1000),
            deadline: permitFields?.deadline ?? Math.floor((Date.now() + 31622400) / 1000), // 1 year late
            recipient: permitFields?.currency ?? "0x0000000000000000000000000000000000000000", // using the zero address means anyone can claim
            data: permitFields?.data ?? []
        }
    };

    const signature = await signer._signTypedData(signedData.domain, signedData.types as any, signedData.message)

    return { signedData, signature };
}


describe("CALM 721", function () {
    let contract: CALM721
    let signer: SignerWithAddress

    before(async () => {
        signer = (await ethers.getSigners())[0]

        const CALM721Factory = await ethers.getContractFactory("CALM721");
        const CALM721Deployment = await CALM721Factory.deploy("CALM", "$CALM");
        const { address } = await CALM721Deployment.deployed();


        contract = CALM721__factory.connect(address, signer);
    });

    it("should be able to claim a lazy mint", async () => {

        const metadata = Buffer.from(JSON.stringify(NFTMetadata[0]), 'utf-8')

        const tokenId = computeTokenIdFromMetadata(metadata, signer.address)

        const minimumPrice = ethers.utils.parseEther("0.01").toString()

        const permit = await getMintPermitForId(tokenId, signer, contract, { minimumPrice: minimumPrice })

        const { r, s, v } = ethers.utils.splitSignature(permit.signature)

        const buyer = (await ethers.getSigners())[1];

        const buyerContract = CALM721__factory.connect(contract.address, buyer);



        try {
            const creatorEtherBalanceBeforeClaim = await signer.getBalance()
            const buyerEtherBalanceBeforeClaim = await buyer.getBalance()

            const tx = await buyerContract.claim(permit.signedData.message, buyer.address, v, r, s, { value: minimumPrice });

            const { gasPrice } = tx;

            const { events, gasUsed } = await tx.wait();

            const claimGasUsedInEther = ethers.BigNumber.from(gasUsed).mul(gasPrice)

            const transfers = events!.filter((e: any) => e.event === 'Transfer')

            expect(transfers.length).to.eq(2);

            expect(transfers[0].args!.tokenId.toHexString()).to.eq(tokenId)
            expect(transfers[1].args!.tokenId.toHexString()).to.eq(tokenId)

            const creatorEtherBalanceAfterClaim = await signer.getBalance()
            const buyerEtherBalanceAfterClaim = await buyer.getBalance()

            expect(creatorEtherBalanceAfterClaim.toString()).to.equal(creatorEtherBalanceBeforeClaim.add(minimumPrice).toString())
            expect(buyerEtherBalanceAfterClaim.toString()).to.equal(buyerEtherBalanceBeforeClaim.sub(minimumPrice).sub(claimGasUsedInEther).toString())
        } catch (e) {
            if (e.message.includes("permit period invalid")) {
                throw new Error("Hardhat test seems to fail when ran without lauching a node, try launching a node in a new terminal window with npm run node and then run npx hardhat --network localhost test");
            }
        }
    })
});