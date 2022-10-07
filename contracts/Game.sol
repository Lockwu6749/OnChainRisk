//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Players.sol";
import "./ARMY.sol";
import "hardhat/console.sol";

contract Game is ReentrancyGuard, Ownable {
    address playerContract;
    address tokenContract;
    address cardTokenContract;
    bool gameActive;
    uint256 turnStartTime;

    bool gameStarted = false;
    bool gameEnded = false;

    uint256 DECK_ID = 9999;
    uint256 SECONDS_IN_DAY = 86400;

    struct BattleResult {
        uint256 attackerLoss;
        uint256 defenderLoss;
        uint256[3] attackerDice;
        uint256[2] defenderDice;
    }

    event Attack(uint256 fromId, uint256 toId, uint256 armySize, BattleResult battleResult, bool defenderDefeated, uint256 playerTokenId);

    string[] public LANDNAMES = ['Alaska', 'Northwest Territory', 'Greenland', 'Alberta', 'Ontario', 'Quebec', 'Western United States', 'Eastern United States', 'Central America', // 8
    							 'Venzuela', 'Peru', 'Brazil', 'Argentina', // 12
    							 'Iceland', 'Scandenavia', 'Ukraine', 'Great Britain', 'Northern Europe', 'Western Europe', 'Southern Europe', // 19
    							 'North Africa', 'Egypt', 'East Africa', 'Congo', 'South Africa', 'Madigascar', // 25
    							 'Middle East', 'Afghanistan', 'Ukal', 'Siberia', 'Yakutsk', 'Kamchatka', 'Irkutsk', 'Mongolia', 'China', 'India', 'Southeast Asia', 'Japan', // 37
    							 'Indonesia', 'New Guinea', 'Western Australia', 'Eastern Australia' ]; // 41


    // CardId to Card value (0 = Army, 1 = Calvary, 2 = Tank, 3 = Joker)
    mapping(uint256 => uint256) public cardValues;
    // LANDNAME Id to list of connected LANDNAME Ids
    mapping(uint256 => uint256[]) public landConnections;
    // LANDNAME Id to PlayerId
    mapping(uint256 => uint256) public landToOwner;
    // LANDNAME Id to ARMY size
    mapping(uint256 => uint256) public landToArmySize;
    // Player tokenId to current claimable reward
    mapping(uint256 => uint256) private _reward;
    // CardId to PlayerId
    mapping(uint256 => uint256) private _cardOwner;
    // PlayerId to list of CardIds in hand
    mapping(uint256 => uint256[]) private _playersCards;
    // Player tokenId to claimable card
    mapping(uint256 => bool) private _claimableCard;
    

    ///////////////////////
    // Reward functions: //
    ///////////////////////
    function claimArmyTokens(uint256 _playerTokenId) public nonReentrant {
        Players playersContract = Players(playerContract);
        ARMYToken tokenContract = ARMYToken(tokenContract);

        require(gameActive, "Game not active");
        require(_reward[_playerTokenId] > 0, "No claimable rewards");
        require(_msgSender() == playersContract.ownerOf(_playerTokenId), "Sender not owner of _playerTokenId");
        
        tokenContract.mint(_msgSender(), _reward[_playerTokenId]);
        _reward[_playerTokenId] = 0;
    }

    function claimCards(uint256 _playerTokenId) public nonReentrant {
        require(gameActive, "Game not active");
        
        Players playersContract = Players(playerContract);
        require(_msgSender() == playersContract.ownerOf(_playerTokenId), "Not owner of _playerTokenId");
        require(_claimableCard[_playerTokenId], "No claimable cards");
    	return;
    }

    function refreshTurn(uint256 _playerTokenId) public nonReentrant {
        Players playersContract = Players(playerContract);

        require(gameActive, "Game not active");        
        require(_msgSender() == playersContract.ownerOf(_playerTokenId), "Not owner of _playerTokenId");
        require(block.timestamp > turnStartTime + SECONDS_IN_DAY, 'Must refresh after 24h from start of turn');
        require(_msgSender() == playersContract.ownerOf(_playerTokenId), "Not owner of _playerTokenId");

        
    }

    ///////////////////////
    // Action functions: //
    ///////////////////////
    function startGame() public onlyOwner {
        Players playersContract = Players(playerContract);
        ARMYToken tokenContract = ARMYToken(tokenContract);

        require(!gameStarted, "Game already started");

        uint256 totalPlayers = playersContract.totalSupply();
        for (uint i = 1; i <= totalPlayers; i++) {
            _reward[i] = 3 * 10 ** tokenContract.decimals();
        }

        uint256[] memory shuffledIndexes = _shuffleLandIndexes();
        for (uint256 i = 0; i < shuffledIndexes.length; i++) {
            landToOwner[shuffledIndexes[i]] = i % totalPlayers + 1;
            landToArmySize[shuffledIndexes[i]] = 1;
        }

        setGameActive();
        turnStartTime = block.timestamp;
    }

    function resetGame() public onlyOwner {

    }

    function placeArmy(uint256 _landId, uint256 _amount, uint256 _playerTokenId) public nonReentrant {
        Players playersContract = Players(playerContract);
        ARMYToken tokenContract = ARMYToken(tokenContract);

        require(gameActive, "Game not active");
        require(_msgSender() == playersContract.ownerOf(_playerTokenId), "Not owner of _playerTokenId");
        require(landToOwner[_landId] == _playerTokenId, "Not owner of land");
    	require(tokenContract.balanceOf(_msgSender()) >= _amount, "_amount exceeds token balance");

        landToArmySize[_landId] += _amount;
        tokenContract.burn(_msgSender(), _amount * 10 ** tokenContract.decimals());
    }

    function attack(uint256 _fromId, uint256 _toId, uint256 _armySize, uint256 _playerTokenId) public nonReentrant {
    	Players playersContract = Players(playerContract);

        require(gameActive, "Game not active");
        require(_msgSender() == playersContract.ownerOf(_playerTokenId), "Not owner of _playerTokenId");
        require(landToOwner[_fromId] == _playerTokenId, "_playerTokenId not owner of territory");
        require(isConnectedTo(_fromId, _toId), "Territories are not connected");
        require(landToOwner[_fromId] != landToOwner[_toId], "Cannot attack your own territory");
        require(getArmySize(_fromId) - _armySize > 0, "Attacking army larger than allowable army size");
        require(_armySize > 0, "Attacking army must be greater than 0");

        BattleResult memory result;
        bool defenderDefeated = false;
        uint256 endingArmySize = _armySize;

        result = _battleResult(_armySize, getArmySize(_toId), _fromId);
        
        landToArmySize[_fromId] -= result.attackerLoss;
        endingArmySize -= result.attackerLoss;
        landToArmySize[_toId] -= result.defenderLoss;

        if(landToArmySize[_toId] < 1) {
            landToArmySize[_fromId] -= _armySize;
            landToArmySize[_toId] = endingArmySize;
            landToOwner[_toId] = _playerTokenId;
            defenderDefeated = true;
        }

        emit Attack(_fromId, _toId, _armySize, result, defenderDefeated, _playerTokenId);
    }

    function moveArmy(uint256 _fromId, uint256 _toId, uint256 _armySize, uint256 _playerTokenId) public nonReentrant {
    	require(gameActive, "Game not active");
        
        Players playersContract = Players(playerContract);
        require(_msgSender() == playersContract.ownerOf(_playerTokenId), "Not owner of _playerTokenId");
        return;
    }

    function playCards(uint256[] memory _cardIds, uint256 _playerTokenId) public nonReentrant {
    	require(gameActive, "Game not active");
        
        Players playersContract = Players(playerContract);
        require(_msgSender() == playersContract.ownerOf(_playerTokenId), "Not owner of _playerTokenId");
        require(_cardIds.length == 3);
    	return;
    }

    function endTurn(uint256 _playerTokenId) public nonReentrant {
    	require(gameActive, "Game not active");
        bool nextTurnReady = (block.timestamp - turnStartTime) >= 86400;
        require(nextTurnReady, "Only one turn per 24h");
        
        Players playersContract = Players(playerContract);
        require(_msgSender() == playersContract.ownerOf(_playerTokenId), "Not owner of _playerTokenId");
        
        turnStartTime = block.timestamp;
        return;
    }

    /////////////////////
    // View functions: //
    /////////////////////
    function getAvailableReward(uint256 _playerTokenId) public view returns (uint256) {
        return _reward[_playerTokenId];
    }

    function getAllLandnames() public view returns (string[] memory) {
        return LANDNAMES;
    }

    function getLandname(uint256 _index) public view returns (string memory) {
        return LANDNAMES[_index];
    }

    function getLandOwner(uint256 _landId) public view returns (uint256) {
        return landToOwner[_landId];
    }

    function getArmySize(uint256 _landId) public view returns (uint256) {
        return landToArmySize[_landId];
    }

    function getLandConnections(uint256 _landId) public view returns (uint256[] memory) {
        return landConnections[_landId];
    }

    function isConnectedTo(uint256 _landId1, uint256 _landId2) public view returns (bool) {
        for (uint i = 0; i < landConnections[_landId1].length; i++) {
            if (landConnections[_landId1][i] == _landId2) {
                return true;
            }
        }
        return false;
    }


    ///////////////////////
    // Helper functions: //
    ///////////////////////
    function _battleResult(uint256 _attackerSize, uint256 _defenderSize, uint256 _fromId) internal view returns (BattleResult memory) {
        BattleResult memory result;

        uint256[2] memory attacker2Dice;
        uint256 attackerDie;
        uint256 defenderDie;

        if(_attackerSize > 1 && _defenderSize > 1) { // 3 vs 2 OR 2 vs 2
            result.defenderDice = _roll2Dice(_fromId + 3);
            if(_attackerSize > 2) {
                result.attackerDice = _roll3Dice(_fromId);
            } else {
                attacker2Dice = _roll2Dice(_fromId);
                result.attackerDice = [attacker2Dice[0], attacker2Dice[1], 0];
            }
            
            if(result.attackerDice[0] > result.defenderDice[0]) {
                if(result.attackerDice[1] > result.defenderDice[1]) {
                    result.attackerLoss = 0;
                    result.defenderLoss = 2;
                } else {
                    result.attackerLoss = 1;
                    result.defenderLoss = 1;
                }
            } else {
                if(result.attackerDice[1] > result.defenderDice[1]) {
                    result.attackerLoss = 1;
                    result.defenderLoss = 1;
                } else {
                    result.attackerLoss = 2;
                    result.defenderLoss = 0;
                }
            }
        } else { // 3 vs 1 OR 2 vs 1 OR 1 vs 2 OR 1 vs 1
            if(_defenderSize > 1) {
                result.defenderDice = _roll2Dice(_fromId + 3);
            } else {
                result.defenderDice = [_rollDie(_fromId + 3), 0];
            }

            if(_attackerSize > 2) {
                result.attackerDice = _roll3Dice(_fromId);
            } else if(_attackerSize > 1) {
                attacker2Dice = _roll2Dice(_fromId);
                result.attackerDice = [attacker2Dice[0], attacker2Dice[1], 0];
            } else {
                result.attackerDice = [_rollDie(_fromId), 0, 0];
            }
            
            if(result.attackerDice[0] > result.defenderDice[0]) {
                result.attackerLoss = 0;
                result.defenderLoss = 1;
            } else {
                result.attackerLoss = 1;
                result.defenderLoss = 0;
            }
        }
        return result;
    }

    function _shuffleLandIndexes() internal returns (uint256[] memory) {
        uint256[] memory output = new uint256[](LANDNAMES.length);
        for(uint256 i = 0; i < LANDNAMES.length; i++) {
            output[i] = i;
        }
        for (uint256 i = 0; i < LANDNAMES.length; i++) {
            uint256 n = i + uint256(keccak256(abi.encodePacked(block.timestamp))) % (LANDNAMES.length - i);
            uint256 temp = output[n];
            output[n] = output[i];
            output[i] = temp;
        }
        return output;
    }

    function _roll2Dice(uint256 _seedId) internal view returns (uint256[2] memory) {
        uint256[2] memory dice = [_rollDie(_seedId), _rollDie(_seedId + 1)];
        
        // Sort
        if(dice[0] > dice[1]) {
            return [dice[0], dice[1]];
        } else {
            return [dice[1], dice[0]];
        }
    }

    function _roll3Dice(uint256 _seedId) internal view returns (uint256[3] memory) {
        uint256[3] memory dice = [_rollDie(_seedId), _rollDie(_seedId + 1), _rollDie(_seedId + 2)];

        // Bubble Sort
        uint256 temp;
        for(uint256 i = 0; i < dice.length; i++) {
            for(uint256 j = 0; j < dice.length - i - 1; j++) {
                if(dice[j + 1] > dice[j]) {
                    temp = dice[j + 1];
                    dice[j + 1] = dice[j];
                    dice[j] = temp;
                }
            }
        }
        return dice; 
    }

    function _rollDie(uint256 _seedId) internal view returns (uint256) {
        return _getRandomNumber(1, 6, getLandname(_seedId % 42));
    }

    // TODO: Add Chainlink implementation
    function _getRandomNumber(uint256 _minValue, uint256 _maxValue, string memory _seed) internal view returns (uint256) {
        uint256 output = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, block.number, _msgSender(), _seed)));
        return  output % _maxValue + _minValue;
    }

    function _getHand(uint256 _playerTokenId) internal view returns (uint256[] memory) {
        return _playersCards[_playerTokenId];
    }
    
    //////////////////////
    // Admin functions: //
    //////////////////////
    function setGameActive() public onlyOwner {
        gameActive = !gameActive;
    }

    function setPlayerContract(address _contractAddress) public onlyOwner {
    	playerContract = _contractAddress;
    }

    function setTokenContract(address _contractAddress) public onlyOwner {
        tokenContract = _contractAddress;
    }

    function setCardTokenContract(address _contractAddress) public onlyOwner {
        cardTokenContract = _contractAddress;
    }

    ////////////////////////
    // Testing functions: //
    ////////////////////////
    function setArmySize(uint256 _landId, uint256 _amount) public onlyOwner {
        require(_amount > 0, "_amount must be greater than 0");
        landToArmySize[_landId] = _amount;
    }

    function changeLandOwner(uint256 _landId, uint256 _playerTokenId) public onlyOwner {
        landToOwner[_landId] = _playerTokenId;
    }

    function testRoll2Dice(uint256 _seedId) public view onlyOwner returns(uint256[2] memory) {
        return _roll2Dice(_seedId);
    }

    function testRoll3Dice(uint256 _seedId) public view onlyOwner returns(uint256[3] memory) {
        return _roll3Dice(_seedId);
    }

    function testBattleResult(uint256 _fromAmount, uint256 _toAmount, uint256 _fromId) public view onlyOwner returns(BattleResult memory) {
        return _battleResult(_fromAmount, _toAmount, _fromId);
    }

    //////////////////
    // Constructor: //
    //////////////////
    constructor() {
        gameActive = false;

    	// Set land connections
    	landConnections[0].push(1);
    	landConnections[0].push(3);
    	landConnections[0].push(31);

    	landConnections[1].push(0);
    	landConnections[1].push(2);
    	landConnections[1].push(3);
    	landConnections[1].push(4);

        landConnections[2].push(1);
        landConnections[2].push(4);
        landConnections[2].push(5);
        landConnections[2].push(13);

        landConnections[3].push(0);
        landConnections[3].push(1);
        landConnections[3].push(4);
        landConnections[3].push(6);

        landConnections[4].push(1);
        landConnections[4].push(2);
        landConnections[4].push(3);
        landConnections[4].push(5);
        landConnections[4].push(6);
        landConnections[4].push(7);

        landConnections[5].push(2);
        landConnections[5].push(4);
        landConnections[5].push(7);

        landConnections[6].push(3);
        landConnections[6].push(4);
        landConnections[6].push(7);
        landConnections[6].push(8);

        landConnections[7].push(4);
        landConnections[7].push(5);
        landConnections[7].push(6);
        landConnections[7].push(8);

        landConnections[8].push(6);
        landConnections[8].push(7);
        landConnections[8].push(9);

        // Initialize cards and put them in the deck
        for(uint i = 0; i < LANDNAMES.length; i++) {
            cardValues[i] = i % 3;
            _cardOwner[i] = DECK_ID;
        }

        // Add Jokers
        cardValues[LANDNAMES.length] = 3;
        _cardOwner[LANDNAMES.length] = DECK_ID;
        cardValues[LANDNAMES.length + 1] = 3;
        _cardOwner[LANDNAMES.length + 1] = DECK_ID;
    }
}
