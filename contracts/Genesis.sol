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

interface IERC20 {
    function transfer(address _to, uint256 _amount) external returns (bool);
}

interface IFortuneCookies {
    function burnBatchPublic(uint[] calldata tokenIds) external;
}

contract Genesis is ERC721AUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    string public baseURI; 
    string public tokenURISuffix;
    uint256 public constant MAX_SUPPLY = 10000;    
    uint256 public constant QUOTA_PER_BURN = 2;    
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
    address public BURN_CONTRACT_PROXY;
    

    mapping(address => uint256) mintedAccounts;

    function initialize(
        uint256 _MAX_PER_ADDRESS,
        string memory _coverBaseURI,
        string memory _tokenURISuffix,
        uint256 _mintStartAt,
        uint256 _mintEndAt,        
        bytes32 _merkleRoot,
        uint256 _FFEndAt,
        uint256 _WLEndAt,
        address _burnProxy
    ) initializerERC721A initializer public {
        __ERC721A_init('Genesis', 'GENZ');
        __Ownable_init();

        baseURI = _coverBaseURI;
        tokenURISuffix = _tokenURISuffix;
        MAX_PER_ADDRESS = _MAX_PER_ADDRESS;
        mintStartAt = _mintStartAt;
        mintEndAt = _mintEndAt;
        merkleRoot = _merkleRoot;        
        FFEndAt = _FFEndAt;
        WLEndAt = _WLEndAt;
        totalMinted = 0;
        BURN_CONTRACT_PROXY = _burnProxy;
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

    function setBurnProxy(address _BURN_CONTRACT_PROXY) external onlyOwner {
        BURN_CONTRACT_PROXY = _BURN_CONTRACT_PROXY;
    }
    
    // Mint Setup
    function setMintInfo(uint256 _mintStartAt, uint256 _mintEndAt, uint256 _FFEndAt, uint256 _WLEndAt) public onlyOwner {                
        mintStartAt = _mintStartAt;  // block.timestamp to start mint
        mintEndAt = _mintEndAt; // block.timestamp to end mint
        FFEndAt = _FFEndAt;
        WLEndAt = _WLEndAt;
    }

    // Mint
    function mint(uint256 _quantity, bytes32[] calldata proof, uint256[] calldata _tokens2burn) external nonReentrant payable whenNotPaused {
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
                    msg.value >= earlyBirdPrice * _quantity,
                    "Insufficient payment."
                );
                _safeMint(msg.sender, _quantity);                  
            } else {
            // Fortune Cookies tier  
                require(
                    totalMinted + _quantity <= earlyBirdSupply + WLSupply,
                    "White list round is sold out!"
                );
                require(
                    _quantity <= QUOTA_PER_BURN * _tokens2burn.length,
                    "Exceeding quota per burnt token."
                );
                require(
                    msg.value >= whitelistPrice * _quantity,
                    "Insufficient payment."
                );
                _burnToMint(msg.sender, _quantity, _tokens2burn);
            }            
        } else {
            // Public tier
            require(
                msg.value >= publicPrice * _quantity,
                "Insufficient payment."
            );
            _safeMint(msg.sender, _quantity);
        }

        totalMinted += _quantity;        
        mintedAccounts[msg.sender] += _quantity;        
    }

    function _burnToMint(address minter, uint256 _quantity, uint256[] calldata _tokens2burn) internal virtual {
        IFortuneCookies fortuneCookies = IFortuneCookies(BURN_CONTRACT_PROXY);
        fortuneCookies.burnBatchPublic(_tokens2burn);
        _safeMint(minter, _quantity);       
    }

    function batchMint(address[] calldata _to, uint256[] calldata _quantities) external payable onlyOwner {
        for (uint256 index = 0; index < _to.length; index++) {
            _safeMint(_to[index], _quantities[index]);
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
        payable(_to).transfer(address(this).balance);
    }

    function withdrawERC20(address _to, address _tokenContract, uint256 _amount) external onlyOwner {
        IERC20 tokenContract = IERC20(_tokenContract);
        tokenContract.transfer(_to, _amount);
    }

    // Admin pause
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}