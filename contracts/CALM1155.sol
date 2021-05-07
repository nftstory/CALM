pragma solidity 0.8.4;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICALMNFT} from "./ICALMNFT.sol";

/**
 * @notice this implementation of https://eips.ethereum.org/EIPS/eip-1155 does not support multiple issuance (fungible tokens)
 */
contract CALM1155 is ERC1155, ICALMNFT {
    modifier onlyCreator(uint256 tokenId) {
        require(
            tokenIdMatchesCreator(tokenId, _msgSender()),
            "CALM: message sender does not own token id"
        );

        _;
    }

    using SafeERC20 for IERC20;

    /*=========== EIP-712 types ============*/

    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    //keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant EIP712DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    //keccak256("MintPermit(uint256 tokenId,uint256 nonce,address currency,uint256 minimumPrice,address payee,uint256 kickoff,uint256 deadline,address recipient,bytes data)");
    bytes32 public constant MINT_PERMIT_TYPEHASH =
        0x44de264c48147fa7ed15dd168260e2e4cdf0378584f33f1a4428c7aed9658aa8;

    // Mapping from token ID to minimum nonce accepted for MintPermits to mint this token
    mapping(uint256 => uint256) private _mintPermitMinimumNonces;

    // The bitmask to apply to a token ID to get the creator short address
    uint256 public constant TOKEN_ID_CREATOR_SHORT_IDENTIFIER_BITMASK =
        0x0000000000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;

    // The EIP-712 Domain separator for this contract
    // solhint-disable-next-line private-vars-leading-underscore, var-name-mixedcase
    bytes32 private DOMAIN_SEPARATOR;

    //when we call functions on _thisAsOperator we can change _msgSender() to be this contract, making sure isApprovedForAll passes when transfering tokens
    //see {IERC1155-safeTransferFrom}
    CALM1155 private _thisAsOperator;

    constructor() public ERC1155("ipfs://") {
        uint256 chainId;

        // solhint-disable-next-line
        assembly {
            chainId := chainid()
        }

        DOMAIN_SEPARATOR = _hash(
            EIP712Domain({
                name: "CALM",
                version: "1",
                chainId: chainId,
                verifyingContract: address(this)
            })
        );
    }

    /**
     * @dev we override isApprovedForAll to return true if the operator is this contract
     */
    function isApprovedForAll(address account, address operator)
        public
        view
        override
        returns (bool)
    {
        if (operator == address(this)) {
            return true;
        }

        return ERC1155.isApprovedForAll(account, operator);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155)
        returns (bool)
    {
        return
            interfaceId == type(ICALMNFT).interfaceId ||
            ERC1155.supportsInterface(interfaceId);
    }

    /*============================ EIP-712 encoding functions ================================*/

    /**
     * @dev see https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator
     */
    function _hash(EIP712Domain memory eip712Domain)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    EIP712DOMAIN_TYPEHASH,
                    keccak256(bytes(eip712Domain.name)),
                    keccak256(bytes(eip712Domain.version)),
                    eip712Domain.chainId,
                    eip712Domain.verifyingContract
                )
            );
    }

    /**
     * @dev see https://eips.ethereum.org/EIPS/eip-712#definition-of-encodedata
     */
    function _hash(MintPermit memory permit)
        internal
        pure
        returns (bytes32 hash)
    {
        return
            keccak256(
                abi.encode(
                    MINT_PERMIT_TYPEHASH,
                    permit.tokenId,
                    permit.nonce,
                    permit.currency,
                    permit.minimumPrice,
                    permit.payee,
                    permit.kickoff,
                    permit.deadline,
                    permit.recipient,
                    keccak256(permit.data)
                )
            );
    }

    /*========================================================================================*/

    /**
     * @notice revoke all MintPermits issued for token ID `tokenId` with nonce lower than `nonce`
     * @param tokenId the token ID for which to revoke permits
     * @param nonce to cancel a permit for a given tokenId we suggest passing the account transaction count as `nonce`
     */
    function revokeMintPermitsUnderNonce(uint256 tokenId, uint256 nonce)
        external
        override
        onlyCreator(tokenId)
    {
        _mintPermitMinimumNonces[tokenId] = nonce + 1;
    }

    /**
     * @dev verifies a signed MintPermit against its token ID for validity (see "../docs/lazyminting.md" or {computeTokenId})
     * also checks that the permit is still valid
     * throws errors on invalid permit
     */
    function requireValidMintPermit(
        MintPermit memory permit,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public view returns (address) {
        // EIP712 encoded
        bytes32 digest =
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, _hash(permit))
            );

        address signer = ecrecover(digest, v, r, s);

        require(
            tokenIdMatchesCreator(permit.tokenId, signer),
            "CALM: message sender does not own token id"
        );

        require(
            permit.nonce >= _mintPermitMinimumNonces[permit.tokenId],
            "CALM: permit revoked"
        );

        return signer;
    }

    /**
     * @dev see "../docs/lazyminting.md" or {computeTokenId})
     */
    function tokenIdMatchesCreator(uint256 tokenId, address creatorAddress)
        public
        pure
        returns (bool isCreator)
    {
        uint160 metadataSHA1 = (uint160)(tokenId >> 96);

        uint256 tokenSpecificCreatorIdentifier =
            (uint256)(keccak256(abi.encode(metadataSHA1, creatorAddress)));

        return
            tokenId & TOKEN_ID_CREATOR_SHORT_IDENTIFIER_BITMASK ==
            (tokenSpecificCreatorIdentifier >> 160) &
                TOKEN_ID_CREATOR_SHORT_IDENTIFIER_BITMASK;
    }

    /**
     * @notice Call this function to buy a not yet minted NFT
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
    ) external payable override {
        require(
            permit.kickoff <= block.timestamp &&
                permit.deadline >= block.timestamp,
            "CALM: permit period invalid"
        );

        //address 0 as recipient in the permit means anyone can claim it
        if (permit.recipient != address(0)) {
            require(recipient == permit.recipient, "CALM: recipient does not match permit");
        }

        address signer = requireValidMintPermit(permit, v, r, s);

        if (permit.currency == address(0)) {
            require(
                msg.value >= permit.minimumPrice,
                "CALM: transaction value under minimum price"
            );

            payable(signer).transfer(msg.value);
        } else {
            IERC20 token = IERC20(permit.currency);
            token.safeTransferFrom(msg.sender, signer, permit.minimumPrice);
        }

        _mint(signer, permit.tokenId, 1, "");
        _thisAsOperator.safeTransferFrom(
            signer,
            recipient,
            permit.tokenId,
            1,
            ""
        );
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        /*
            extract the JSON metadata sha1 digest from `tokenId` and convert to hex string
            */
        bytes32 value = bytes32(tokenId >> 96);
        bytes memory alphabet = "0123456789abcdef";

        bytes memory sha1Hex = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            sha1Hex[i * 2] = alphabet[(uint8)(value[i + 12] >> 4)];
            sha1Hex[1 + i * 2] = alphabet[(uint8)(value[i + 12] & 0x0f)];
        }

        //with IPFS we can retrieve a SHA1 hashed file with a CID of the following format : "f01551114{_sha1}"
        //only works if the file has been uploaded with "ipfs add --raw-leaves --hash=sha1 <path>"
        // see {#../docs/lazyminting.md#Notes-on-IPFS-compatibility}
        return string(abi.encodePacked(ERC1155.uri(0), "f01551114", sha1Hex));
    }
}
