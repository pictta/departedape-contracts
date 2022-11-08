// SPDX-License-Identifier: MIT
/*
                                                                     
                  @@@FORTUNE@@@                                      
            @@@@+++++++++++++99++@@@                                 
         @@++++++++++++++++9+9=99+++++@@                             
       @++++++++++++++++++99+9==99+++++++@@@                         
      +++++++++++++++++++999++9===99+++@@+++++@                      
     +++++++++++++++++9=9999+++====99+++++@++99+@                    
    +++9999+++++++++99+999999+++====99+++++@@@+99++@                 
   @++99++9+++++++++9999999999+++====999+++++@@++999+@               
   +++++++++++++++++9999999999+++9====9999+++++@@++99++@             
  @+++999++++99++9+99999999999+++++=====999+++++++@++99+@            
  @++9999999999999999999=99999999+++====99999++++++++++99+@          
   +9+999999999999999====9=9==999++++====99999+++++++++++++@         
   +9+99999999999999999====999999+++++=====9999+++++++++++9+@        
   +999999999999999999=====999999+9++++======9999++++++++++++@       
   @99999999999999=99999==9999999999++++======99999++++++++++++@     
    @99+99999999999999==99999999999++++++9=====999999+++++++++++@    
     @99999999=9==999=99999999999999++++++9======9999999++++99+++    
      @99999999999=====99999999999999++++++9=====99999999+9++9++++   
       @999999===99999===999999999999+++++++9=======999999999+++++@  
         +99999===99=======9999999999+++++++++@+99======9999999999@  
          @9=99999============99999999+++++++++   @@@++999999===9+   
            +9999999=============99=999+++++++++           @@@@+@    
              +9==9999=99========99999999++9++++@                    
                +99===9999======9=99999999+++++++                    
                  @9======9999====9999999999+++++@                   
                    @+9==66==9999===9999999999++++                   
                      @+9==666======999999999+++++@                  
                         @+9==6666========999999+++@                 
                            @@+9==6666666========99@                 
                                @@++9====666666=9+@                  
                                      @@@@+++@@     
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

contract FortuneCookiesSBT is ERC721AUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    string public baseURI; 
    string public tokenURISuffix;
    uint256 public constant MAX_SUPPLY = 4000;    
    uint256 public MAX_PER_ADDRESS;

    uint256 public thisRoundStart;
    uint256 public thisRoundEnd;
    uint256 public thisRoundSupply;
    uint256 public totalMinted;
    uint256 public thisRoundMinted;
    bool public isPublic;

    bytes32 public merkleRoot;

    mapping(address => uint256) mintedAccountsWL;
    mapping(address => uint256) mintedAccountsPublic;

    function initialize(
        uint256 _MAX_PER_ADDRESS,
        string memory _coverBaseURI,
        string memory _tokenURISuffix,
        uint256 _thisRoundStart,
        uint256 _thisRoundEnd,
        uint256 _thisRoundSupply,
        bytes32 _merkleRoot        
    ) initializerERC721A initializer public {
        __ERC721A_init('FortuneCookiesSBT', 'FKSBT');
        __Ownable_init();

        baseURI = _coverBaseURI;
        tokenURISuffix = _tokenURISuffix;
        MAX_PER_ADDRESS = _MAX_PER_ADDRESS;
        thisRoundStart = _thisRoundStart;
        thisRoundEnd = _thisRoundEnd;
        thisRoundSupply = _thisRoundSupply;
        totalMinted = 0;
        thisRoundMinted = 0;
        isPublic = false;
        merkleRoot = _merkleRoot;
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
    function setFreeMintInfo(uint256 _thisRoundMinted, uint256 _thisRoundStart, uint256 _thisRoundEnd, uint256 _thisRoundSupply) public onlyOwner {        
        thisRoundMinted = _thisRoundMinted;
        thisRoundStart = _thisRoundStart;  // block.timestamp to start mint
        thisRoundEnd = _thisRoundEnd; // block.timestamp to end mint
        thisRoundSupply = _thisRoundSupply;  // total tokens available for this round
    }

    function setPublicMint(bool _bool) public onlyOwner {
       isPublic = _bool;
    }

    // Mint
    function freeMint(uint256 _quantity, bytes32[] calldata proof) external nonReentrant whenNotPaused {
        require(
            (thisRoundStart <= block.timestamp && thisRoundEnd > block.timestamp), 
            "Mint is not active."
        ); 
        require(
            thisRoundMinted + _quantity <= thisRoundSupply,
            "This round is sold out!"
        );    
        require(
            totalMinted + _quantity <= MAX_SUPPLY,
            "ALL SOLD!"
        );  
        if (!isPublic) {
            require(
                mintedAccountsWL[msg.sender] + _quantity <= MAX_PER_ADDRESS,
                "Sorry, you have minted all your quota for Whitelist Round."
            ); 
            require(_merkleTreeVerify(_merkleTreeLeaf(msg.sender), proof),
                "Sorry, you are not whitelisted for this round. Come back later!"
            );
            _safeMint(msg.sender, _quantity);
            totalMinted += _quantity;
            thisRoundMinted += _quantity;
            mintedAccountsWL[msg.sender] += _quantity;
        } else {
            require(
                mintedAccountsPublic[msg.sender] + _quantity <= MAX_PER_ADDRESS,
                "Sorry, you have minted all your quota for Public Round."
            );            
            _safeMint(msg.sender, _quantity);
            totalMinted += _quantity;
            thisRoundMinted += _quantity;
            mintedAccountsPublic[msg.sender] += _quantity;
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

    // Burn function
    function burn(uint tokenId) external whenNotPaused {
        _burn(tokenId, true);
    }
    
    function burnBatch(uint[] calldata tokenIds) external onlyOwner {
        for (uint256 index = 0; index < tokenIds.length;) {
            _burn(tokenIds[index]);
            unchecked { index++; }
        }
    }

    // Soulbound token implementation
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override {
        require(from == address(0) || to == address(0), "Soulbound token is non-transferrable!");
        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }
}