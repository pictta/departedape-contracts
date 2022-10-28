// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import 'erc721a-upgradeable/contracts/ERC721AUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract Airdrop is ERC721AUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    string public baseURI; 
    string public tokenURISuffix;

    function initialize(
        string memory _coverBaseURI,
        string memory _tokenURISuffix
    ) initializerERC721A initializer public {
        __ERC721A_init('Airdrop', 'AIRD');
        __Ownable_init();

        baseURI = _coverBaseURI;
        tokenURISuffix = _tokenURISuffix;
    }

    function airdrop(address[] calldata _to, uint256[] calldata _quantities) external onlyOwner {
        for (uint256 index = 0; index < _to.length;) {
            _safeMint(_to[index], _quantities[index]);
            unchecked { index++; }
        }
    }

    // Post Airdrop
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

    // Admin Functions
    function withdrawETH(address _to) external onlyOwner {
        payable(_to).transfer(address(this).balance);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
    
    function burnBatch(uint[] calldata tokenIds) external onlyOwner {
        for (uint256 index = 0; index < tokenIds.length;) {
            _burn(tokenIds[index]);
            unchecked { index++; }
        }
    }
}