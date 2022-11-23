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
    uint256 public MAX_PER_FC_WL;
    uint256 public MAX_PER_ADDRESS_PUB;

    uint256 public mintStart;
    uint256 public mintEnd;
    uint256 public whitelistEnd;
    uint256 public totalMinted;

    uint256 public constant whitelistPrice = 0.000001 ether;
    uint256 public constant publicPrice = 0.000002 ether;

    address public constant WL_NFT_PROXY = 0x82AF3E65666Ca9fb0cd7C7A08b534373a797e416;
    address public constant VAULT = 0x1BC7A57b2da9368d8b25a5C94408e1ad2e20B1A9; 

    mapping(address => uint256) mintedAccountsWL;
    mapping(address => uint256) mintedAccountsPUB;

    using SafeERC20Upgradeable for IERC20Upgradeable;

    function initialize(        
        string memory _coverBaseURI,
        string memory _tokenURISuffix,
        uint256 _MAX_PER_FC_WL,
        uint256 _MAX_PER_ADDRESS_PUB,
        uint256 _mintStart,
        uint256 _mintEnd,
        uint256 _whitelistEnd
    ) initializerERC721A initializer public {
        __ERC721A_init('GenesisSBTV2', 'GSBTV2');
        __Ownable_init();
        __RevokableDefaultOperatorFilterer_init();

        baseURI = _coverBaseURI;
        tokenURISuffix = _tokenURISuffix;

        MAX_PER_FC_WL = _MAX_PER_FC_WL;
        MAX_PER_ADDRESS_PUB = _MAX_PER_ADDRESS_PUB;

        mintStart = _mintStart;
        mintEnd = _mintEnd;
        whitelistEnd = _whitelistEnd;
        totalMinted = 0;
    }
    // balanceOf for owned FC
    function getWhitelistQuota(address _user) public view returns(uint256)  {
        IERC721AUpgradeable fcContract = IERC721AUpgradeable(WL_NFT_PROXY);
        return fcContract.balanceOf(_user) * MAX_PER_FC_WL;
    }

    // Mint Setup
    function setMintInfo(uint256 _mintStart, uint256 _mintEnd, uint256 _whitelistEnd, uint256 _MAX_PER_FC_WL, uint256 _MAX_PER_ADDRESS_PUB) public onlyOwner {                
        mintStart = _mintStart;  // block.timestamp to start mint
        mintEnd = _mintEnd; // block.timestamp to end mint
        whitelistEnd = _whitelistEnd;
        MAX_PER_FC_WL = _MAX_PER_FC_WL;
        MAX_PER_ADDRESS_PUB = _MAX_PER_ADDRESS_PUB;
    }

    // Mint
    function mint(uint256 _quantity) external nonReentrant payable whenNotPaused {
        require(
            (mintStart <= block.timestamp && mintEnd > block.timestamp), 
            "Mint is not active."
        );        
        require(
            totalMinted + _quantity <= MAX_SUPPLY,
            "SOLD OUT!"
        );  

        if(block.timestamp <= whitelistEnd) {
            // WL tier
            require(
                mintedAccountsWL[msg.sender] + _quantity <= getWhitelistQuota(msg.sender),
                "Sorry, you have minted all your quota."
            ); 
            require(
                msg.value == whitelistPrice * _quantity,
                "Insufficient payment."
            );

            _safeMint(msg.sender, _quantity);   
            totalMinted += _quantity;         
            mintedAccountsWL[msg.sender] += _quantity;   

        } else {
            // Public tier
            require(
                mintedAccountsPUB[msg.sender] + _quantity <= MAX_PER_ADDRESS_PUB,
                "Sorry, you have minted all your quota in public round."
            );
            require(
                msg.value == publicPrice * _quantity,
                "Insufficient payment."
            );
            
            _safeMint(msg.sender, _quantity);   
            totalMinted += _quantity;         
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