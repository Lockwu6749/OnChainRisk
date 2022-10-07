//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

import "hardhat/console.sol";

contract mintContract is ERC721Enumerable, ReentrancyGuard, Ownable {
    event PlayerMinted(address _minter, uint256 _tokenId);

    address playerContract;

    struct PlayerAttributes {
        uint playerIndex;
        string name;
        string imageURI;
    }

    PlayerAttributes[] availablePlayers;

    function getName(uint256 tokenId) public view returns (string memory) {
        return availablePlayers[tokenId].name;
    }

    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        PlayerAttributes memory p = availablePlayers[tokenId];
        bytes memory dataURI = abi.encodePacked(
            '{',
                '"name": "', p.name, '",',
                '"description": "You find yourself put in charge of the army while your enemies multiply and surround you.",',
                '"image": "', p.imageURI, '",',
                '"attributes": [ { "trait_type": "color", "value": "', p.name, '" } ]',
            '}'
        );

        string memory output = string(
            abi.encodePacked("data:application/json;base64,", Base64.encode(dataURI))
        );

        return output;
    }

    function getPlayer(uint256 tokenId) external view returns (PlayerAttributes memory) {
        if (tokenId > 0) {
            return availablePlayers[tokenId];
        } else {
            PlayerAttributes memory emptyStruct;
            return emptyStruct;
        }
    }

    function getAllPlayers() public view returns (PlayerAttributes[] memory) {
        return availablePlayers;
    }

    function setPlayerContract(address contractAddress) public onlyOwner {
        playerContract = contractAddress;
    }

    constructor(
        string[] memory _names,
        string[] memory _imageURIs        
    ) ERC721("Players", "RISK") {
        for(uint i = 0; i < _names.length; i++) {
            availablePlayers.push(PlayerAttributes({
                playerIndex: i, // Will match tokenId
                name: _names[i],
                imageURI: _imageURIs[i]
            }));
        }
    }
}
