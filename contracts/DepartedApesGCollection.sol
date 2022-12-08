// SPDX-License-Identifier: MIT
/*
ascii art   
*/
pragma solidity ^0.8.14;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import 'erc721a-upgradeable/contracts/ERC721AUpgradeable.sol';
import 'erc721a-upgradeable/contracts/IERC721AUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {RevokableDefaultOperatorFiltererUpgradeable} from "./opensea/upgradeable/RevokableDefaultOperatorFiltererUpgradeable.sol";
import {RevokableOperatorFiltererUpgradeable} from "./opensea/upgradeable/RevokableOperatorFiltererUpgradeable.sol";

contract DepartedApesGCollection is 
    ERC721AUpgradeable, 
    ReentrancyGuardUpgradeable, 
    PausableUpgradeable,
    RevokableDefaultOperatorFiltererUpgradeable,
    OwnableUpgradeable
{
    string public baseURI; 
    string public tokenURISuffix;
    uint256 public constant MAX_SUPPLY = 10000;    
    uint256 public MAX_PER_FC_WL;
    uint256 public MAX_PER_ADDRESS_WL;
    uint256 public MAX_PER_ADDRESS_PUB;

    uint256 public mintStart;
    uint256 public mintEnd;
    uint256 public fortuneCookiesEnd;
    uint256 public waitlistEnd;
    uint256 public totalMinted;

    address public constant FC_NFT_PROXY = 0x25e83E339B5414909CDE81F7BF0A5401B21201F9;

    bytes32 public merkleRoot;

    mapping(address => uint256) mintedAccountsB4Pub;
    mapping(address => uint256) mintedAccountsPUB;

    struct MintQuota {        
        uint256 leftQuota;
        uint256 maxQuota;
        uint256 currentPrice;
    }
    
    struct MintPrices {
        uint256 fortuneCookiesPrice;
        uint256 waitlistPrice;
        uint256 publicPrice;
    }

    MintPrices public mintPrices;

    using SafeERC20Upgradeable for IERC20Upgradeable;

    function initialize(        
        string memory _coverBaseURI,
        string memory _tokenURISuffix,
        uint256 _MAX_PER_FC_WL,
        uint256 _MAX_PER_ADDRESS_WL,
        uint256 _MAX_PER_ADDRESS_PUB,
        uint256 _mintStart,
        uint256 _mintEnd,
        uint256 _fortuneCookiesEnd,
        uint256 _waitlistEnd,
        bytes32 _merkleRoot,
        MintPrices calldata _mintPrices

    ) initializerERC721A initializer public {
        __ERC721A_init('DepartedApesGCollection', 'DAGC');
        __Ownable_init();
        __RevokableDefaultOperatorFilterer_init();

        baseURI = _coverBaseURI;
        tokenURISuffix = _tokenURISuffix;

        MAX_PER_FC_WL = _MAX_PER_FC_WL;
        MAX_PER_ADDRESS_WL = _MAX_PER_ADDRESS_WL;
        MAX_PER_ADDRESS_PUB = _MAX_PER_ADDRESS_PUB;

        mintStart = _mintStart;
        mintEnd = _mintEnd;
        fortuneCookiesEnd = _fortuneCookiesEnd;
        waitlistEnd = _waitlistEnd;
        totalMinted = 0;
        merkleRoot = _merkleRoot;

        mintPrices = _mintPrices;
    }

    // utility
    function setNewMerkleRoot(bytes32 _newRoot) external onlyOwner {
        merkleRoot = _newRoot;
    }

    function _merkleTreeLeaf(address _address) internal pure returns (bytes32) {
        return keccak256((abi.encodePacked(_address)));
    }
    
    function _merkleTreeVerify(bytes32 _leaf, bytes32[] memory _proof) internal view returns(bool) {
        return MerkleProof.verify(_proof, merkleRoot, _leaf);
    }

    // balanceOf for owned FC
    function getWhitelistQuota(address _user) public view returns(uint256)  {
        IERC721AUpgradeable fcContract = IERC721AUpgradeable(FC_NFT_PROXY);
        return fcContract.balanceOf(_user) * MAX_PER_FC_WL;
    }

    // Mint Setup
    function setMintInfo(uint256 _mintStart, uint256 _mintEnd, uint256 _fortuneCookiesEnd, uint256 _waitlistEnd, uint256 _MAX_PER_FC_WL, uint256 _MAX_PER_ADDRESS_PUB, uint256 _MAX_PER_ADDRESS_WL) public onlyOwner {                
        mintStart = _mintStart;  // block.timestamp to start mint
        mintEnd = _mintEnd; // block.timestamp to end mint
        fortuneCookiesEnd = _fortuneCookiesEnd;
        waitlistEnd = _waitlistEnd;
        MAX_PER_FC_WL = _MAX_PER_FC_WL;
        MAX_PER_ADDRESS_PUB = _MAX_PER_ADDRESS_PUB;
        MAX_PER_ADDRESS_WL = _MAX_PER_ADDRESS_WL;
    }

    function setMintPrices(uint256 _fortuneCookiesPrice, uint256 _waitlistPrice, uint256 _publicPrice) public onlyOwner {
        mintPrices = MintPrices(
            _fortuneCookiesPrice,
            _waitlistPrice,
            _publicPrice
        );
    }

    // Mint status query
    function getMintStatus(address _user) public view returns (MintQuota memory) {
        if (block.timestamp <= fortuneCookiesEnd) {
            return MintQuota(
                getWhitelistQuota(_user) - mintedAccountsB4Pub[_user],
                getWhitelistQuota(_user),
                mintPrices.fortuneCookiesPrice
            );
        } else if (block.timestamp <= waitlistEnd) {
            return MintQuota(
                MAX_PER_ADDRESS_WL - mintedAccountsB4Pub[_user],
                MAX_PER_ADDRESS_WL,
                mintPrices.waitlistPrice
            );
        } else {
            return MintQuota(
                MAX_PER_ADDRESS_PUB - mintedAccountsPUB[_user],
                MAX_PER_ADDRESS_PUB,
                mintPrices.publicPrice
            );
        }
    }

    // Team mint
    function devMint(address _to, uint256 _quantity) external onlyOwner {
        require(_quantity + totalMinted <= MAX_SUPPLY);
        _mintBatch(_to, _quantity);
    }

    function _mintBatch(address _to, uint256 _quantity) virtual internal {
        require(_quantity > 0, "Quantity must be greater than 0");
        _safeMint(_to, _quantity);   
        totalMinted += _quantity;
    }

    // Mint
    function mint(uint256 _quantity, bytes32[] calldata proof) external nonReentrant payable whenNotPaused {
        require(
            (mintStart <= block.timestamp && mintEnd > block.timestamp), 
            "Mint is not active."
        );        
        require(
            totalMinted + _quantity <= MAX_SUPPLY,
            "SOLD OUT!"
        );  

        if(block.timestamp <= fortuneCookiesEnd) {
            // fortune cookies round
            require(
                mintedAccountsB4Pub[msg.sender] + _quantity <= getWhitelistQuota(msg.sender),
                "Sorry, you have minted all your quota in non-public round."
            ); 
            require(
                msg.value == mintPrices.fortuneCookiesPrice * _quantity,
                "Insufficient payment."
            );
            _mintBatch(msg.sender, _quantity);      
            mintedAccountsB4Pub[msg.sender] += _quantity;   

        } else if (block.timestamp <= waitlistEnd) {
            // waitlist round
            require(_merkleTreeVerify(_merkleTreeLeaf(msg.sender), proof),
                "Sorry, you are not in this waitlist, please come back later at public round."
            );
            require(
                mintedAccountsB4Pub[msg.sender] + _quantity <= MAX_PER_ADDRESS_WL,
                "Sorry, you have minted all your quota in non-public round."
            ); 
            require(
                msg.value == mintPrices.waitlistPrice * _quantity,
                "Insufficient payment."
            );
            _mintBatch(msg.sender, _quantity);      
            mintedAccountsB4Pub[msg.sender] += _quantity; 
        } else {
            // Public tier
            require(
                mintedAccountsPUB[msg.sender] + _quantity <= MAX_PER_ADDRESS_PUB,
                "Sorry, you have minted all your quota in public round."
            );
            require(
                msg.value == mintPrices.publicPrice * _quantity,
                "Insufficient payment."
            );            
            _mintBatch(msg.sender, _quantity);       
            mintedAccountsPUB[msg.sender] += _quantity;  
        }  
    }

    // Post Mint
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function setTokenURISuffix(string memory _newTokenURISuffix) external onlyOwner {
        tokenURISuffix = _newTokenURISuffix;
    }
    function tokenURI(uint256 _tokenId) public view override returns(string memory) {
        return string.concat(super.tokenURI(_tokenId), tokenURISuffix);
    }

    // Fund Withdraw
    function withdrawETH(address _to) external onlyOwner {
        require(_to != address(0), "Cant transfer to 0 address!");
        (bool withdrawSucceed, ) = payable(_to).call{ value: address(this).balance }("");
        require(withdrawSucceed, "Withdraw Failed");
    }

    function withdrawERC20(address _to, address _tokenContract, uint256 _amount) external onlyOwner {
        require(_to != address(0), "Cant transfer to 0 address!");
        IERC20Upgradeable tokenContract = IERC20Upgradeable(_tokenContract);
        tokenContract.safeTransfer(_to, _amount);
    }

    // Admin pause
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Opensea Operator filter registry
    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId) public override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function owner() public view virtual override (OwnableUpgradeable, RevokableOperatorFiltererUpgradeable) returns (address) {
        return OwnableUpgradeable.owner();
    }
}