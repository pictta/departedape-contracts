// SPDX-License-Identifier: MIT
/*
ascii art   
*/
pragma solidity ^0.8.14;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import 'erc721a-upgradeable/contracts/ERC721AUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {RevokableDefaultOperatorFiltererUpgradeable} from "./opensea/upgradeable/RevokableDefaultOperatorFiltererUpgradeable.sol";
import {RevokableOperatorFiltererUpgradeable} from "./opensea/upgradeable/RevokableOperatorFiltererUpgradeable.sol";

contract GenesisSBT is 
    ERC721AUpgradeable, 
    ReentrancyGuardUpgradeable, 
    PausableUpgradeable,
    RevokableDefaultOperatorFiltererUpgradeable,
    OwnableUpgradeable
{
    string public baseURI; 
    string public tokenURISuffix;
    uint256 public constant MAX_SUPPLY = 10000;    
    uint256 public MAX_PER_ADDRESS;
    uint256 public constant earlyBirdSupply = 2000;
    uint256 public constant WLSupply = 3000;
    uint256 public mintStartAt;
    uint256 public mintEndAt;
    uint256 public FFEndAt;
    uint256 public WLEndAt;
    uint256 public totalMinted;
    uint256 public constant earlyBirdPrice = 0.00001 ether;
    uint256 public constant whitelistPrice = 0.00001 ether;
    uint256 public constant publicPrice = 0.000002 ether;
    bytes32 public merkleRoot;
    address public constant VAULT = 0x4962913E3b8Ae6f918eF004c73FbE82A2F19804a; 

    mapping(address => uint256) mintedAccounts;

    using SafeERC20Upgradeable for IERC20Upgradeable;

    function initialize(
        uint256 _MAX_PER_ADDRESS,
        string memory _coverBaseURI,
        string memory _tokenURISuffix,
        uint256 _mintStartAt,
        uint256 _mintEndAt,        
        bytes32 _merkleRoot,
        uint256 _FFEndAt,
        uint256 _WLEndAt
    ) initializerERC721A initializer public {
        __ERC721A_init('GenesisSBT', 'GSBT');
        __Ownable_init();
        __RevokableDefaultOperatorFilterer_init();

        baseURI = _coverBaseURI;
        tokenURISuffix = _tokenURISuffix;
        MAX_PER_ADDRESS = _MAX_PER_ADDRESS;
        mintStartAt = _mintStartAt;
        mintEndAt = _mintEndAt;
        merkleRoot = _merkleRoot;        
        FFEndAt = _FFEndAt;
        WLEndAt = _WLEndAt;
        totalMinted = 0;
    }
    
    // Utilities
    function setNewMerkleRoot(bytes32 _newRoot) external onlyOwner {
        merkleRoot = _newRoot;
    }

    function _merkleTreeLeaf(address _address) internal pure returns (bytes32) {
        return keccak256((abi.encodePacked(_address)));
    }
    
    function _merkleTreeVerify(bytes32 _leaf, bytes32[] memory _proof) internal view returns(bool) {
        return MerkleProof.verify(_proof, merkleRoot, _leaf);
    }
    
    // Mint Setup
    function setMintInfo(uint256 _mintStartAt, uint256 _mintEndAt, uint256 _FFEndAt, uint256 _WLEndAt) public onlyOwner {                
        mintStartAt = _mintStartAt;  // block.timestamp to start mint
        mintEndAt = _mintEndAt; // block.timestamp to end mint
        FFEndAt = _FFEndAt;
        WLEndAt = _WLEndAt;
    }

    // Mint
    function mint(uint256 _quantity, bytes32[] calldata proof) external nonReentrant payable whenNotPaused {
        require(
            (mintStartAt <= block.timestamp && mintEndAt > block.timestamp), 
            "Mint is not active."
        );
        require(
            mintedAccounts[msg.sender] + _quantity <= MAX_PER_ADDRESS,
            "Sorry, you have minted all your quota."
        ); 
        require(
            totalMinted + _quantity <= MAX_SUPPLY,
            "ALL SOLD!"
        );  

        if(block.timestamp < WLEndAt) {
            require(_merkleTreeVerify(_merkleTreeLeaf(msg.sender), proof),
                "Sorry, you are not whitelisted for this round. Come back later!"
            );
            // Frens & Fam tier
            if(block.timestamp < FFEndAt) {
                require(
                    totalMinted + _quantity <= earlyBirdSupply,
                    "earlyBirdSupply round is sold out!"
                );
                require(
                    msg.value == earlyBirdPrice * _quantity,
                    "Insufficient payment."
                );                
            } else {
            // Fortune Cookies tier  
                require(
                    totalMinted + _quantity <= earlyBirdSupply + WLSupply,
                    "White list round is sold out!"
                );
                require(
                    msg.value == whitelistPrice * _quantity,
                    "Insufficient payment."
                );
            }
            _safeMint(msg.sender, _quantity);                              
        } else {
            // Public tier
            require(
                msg.value == publicPrice * _quantity,
                "Insufficient payment."
            );
            _safeMint(msg.sender, _quantity);
        }

        totalMinted += _quantity;        
        mintedAccounts[msg.sender] += _quantity;        
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
    function withdrawETH() external onlyOwner {
        require(VAULT != address(0), "Cant transfer to 0 address!");
        (bool withdrawSucceed, ) = payable(VAULT).call{ value: address(this).balance }("");
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