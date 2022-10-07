//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/Strings.sol";

import "hardhat/console.sol";

contract Players is ERC721Enumerable, ReentrancyGuard, Ownable {
    event PlayerMinted(address _to, uint256 _tokenId);

    bool saleActive;
    uint16 maxPlayers;
    uint256 newestPlayer;
    address mintContract;
    address gameContract;

    struct PlayerAttributes {
        uint256 playerIndex;
        string name;
        string imageURI;
    }

    function setMaxPlayers(uint16 _maxPlayers) public onlyOwner {
    	maxPlayers = _maxPlayers;
    }

    function setSale() public onlyOwner {
    	saleActive = !saleActive;
    }

    function mint() public nonReentrant {
    	require(saleActive, "Minting not active");
    	require(newestPlayer < maxPlayers, "Max Players already minted");

    	_safeMint(_msgSender(), newestPlayer + 1);
    	newestPlayer++;

    	emit PlayerMinted(_msgSender(), newestPlayer);
    }

    function tokenURI(uint256 _tokenId) override public view returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory output;

        Players dataContract = Players(mintContract);
        output = dataContract.tokenURI(_tokenId);

        return output;
    }

    function getColor(uint256 _tokenId) public view returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory output;
        
        Players dataContract = Players(mintContract);
        output = dataContract.getColor(_tokenId);

        return output;
    }

    function getName(uint256 _tokenId) public view returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory output;
        
        Players dataContract = Players(mintContract);
        output = dataContract.getName(_tokenId);

        return output;
    }

    function getPlayer(uint256 _tokenId) public view returns (PlayerAttributes memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
        PlayerAttributes memory output;
        
        Players dataContract = Players(mintContract);
        output = dataContract.getPlayer(_tokenId);

        return output;
    }

    function getAllPlayers() public view returns (PlayerAttributes[] memory) {
        PlayerAttributes[] memory output;
        
        Players dataContract = Players(mintContract);
        output = dataContract.getAllPlayers();

        return output;
    }

    function getMintedPlayers() public view returns (PlayerAttributes[] memory) {
        uint n = newestPlayer + 1;
        PlayerAttributes[] memory output = new PlayerAttributes[](n);
        PlayerAttributes[] memory allPlayers;
        allPlayers = getAllPlayers();

        for(uint i = 0; i < n; i++) {
            output[i] = allPlayers[i];
        }

        return output;
    }

    function setMintContract(address _contractAddress) public onlyOwner {
        mintContract = _contractAddress;
    }

    function setGameContract(address _contractAddress) public onlyOwner {
        gameContract = _contractAddress;
    }

    constructor() ERC721("Players", "RISK") Ownable() {
    	saleActive = false;
    	maxPlayers = 6;
    }
}