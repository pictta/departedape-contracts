// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;
import 'erc721a-upgradeable/contracts/IERC721AUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract Mission250 is OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    IERC721AUpgradeable immutable genesisCollection;
    IERC721AUpgradeable immutable airdropCollection;
    
    struct Staker {
        // Number of the NFT staked in pairs, should be multiples of two
        uint256 setsStaked;
        // Latest staked time
        uint256 lastUpdate;
        // Accumulated play time
        uint256 karma;
    }

    mapping(address => Staker) public stakers;
    mapping(uint256 => address) genesisStakerAddress;
    mapping(uint256 => address) airdropStakerAddress;

    uint256 public minStakeDuration;  // minimum stake period

    constructor(
        IERC721AUpgradeable _genesisCollection,
        IERC721AUpgradeable _airdropCollection,
        uint256 _minStakeDuration
    ) {
        genesisCollection = _genesisCollection;
        airdropCollection = _airdropCollection;
        minStakeDuration = _minStakeDuration;
    }

    function stake(uint256[] calldata _genesisIds, uint256[] calldata _airdropIds) external nonReentrant {
        require(_genesisIds.length == _airdropIds.length, "Genesis NFTs number NOT matches with airdrop.");
        for (uint256 i; i < _genesisIds.length;) {
            genesisCollection.transferFrom(msg.sender, address(this), _genesisIds[i]);
            genesisStakerAddress[_genesisIds[i]] = msg.sender;

            airdropCollection.transferFrom(msg.sender, address(this), _airdropIds[i]);
            airdropStakerAddress[_airdropIds[i]] = msg.sender;

            unchecked { i++; }
        }

        // Update Staker Info
        stakers[msg.sender].setsStaked += _genesisIds.length;
        stakers[msg.sender].lastUpdate = block.timestamp;
    }

    function unstake(uint256[] calldata _genesisIds, uint256[] calldata _airdropIds) external nonReentrant {
        require(
            stakers[msg.sender].setsStaked > 0,
            "You have no tokens staked"
        );
        require(
            stakers[msg.sender].lastUpdate + minStakeDuration >= block.timestamp,
            "Your staking period is not ended yet"
        );
        require(
            _genesisIds.length == _airdropIds.length, 
            "Genesis NFTs number NOT matches with airdrop."
        );
        
        for (uint256 i; i < _genesisIds.length;) {
            require(
                genesisStakerAddress[_genesisIds[i]] == msg.sender,
                "You are not the owner of this NFT"
            );
            require(
                airdropStakerAddress[_airdropIds[i]] == msg.sender,
                "You are not the owner of this NFT"
            );

            genesisCollection.transferFrom(address(this), msg.sender, _genesisIds[i]);
            genesisStakerAddress[_genesisIds[i]] = address(0);

            airdropCollection.transferFrom(address(this), msg.sender, _airdropIds[i]);
            airdropStakerAddress[_airdropIds[i]] = address(0);
            
            unchecked { i++; }
        }
        stakers[msg.sender].setsStaked -= _genesisIds.length;
        stakers[msg.sender].karma += (block.timestamp - stakers[msg.sender].lastUpdate);
        stakers[msg.sender].lastUpdate = block.timestamp;        
    }

    function getKarmaByAddress(address _stakerAddress) public view returns (uint256 _karma) {
        return (stakers[_stakerAddress].karma);
    }
}