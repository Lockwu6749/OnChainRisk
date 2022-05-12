const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Game Tests", function () {
  before(async () => {
    [ owner, addr1, addr2, addr3, addr4 ] = await ethers.getSigners();

    const mintContractFactory = await ethers.getContractFactory("mintContract");
    mintContract = await mintContractFactory.deploy(
      ["NA", "BLACK", "BLUE", "GREEN", "GRAY", "RED", "YELLOW"],
      ["NA", "https://i.imgur.com/kbejWBd.png",
      "https://i.imgur.com/lreWZsa.png",
      "https://i.imgur.com/NGCvIAg.png",
      "https://i.imgur.com/Bm4Bvpx.png",
      "https://i.imgur.com/j2VMPZW.png",
      "https://i.imgur.com/KRZYJ4J.png"]
    );
    await mintContract.deployed();

    const playerContractFactory = await ethers.getContractFactory("Players");
    playerContract = await playerContractFactory.deploy();
    await playerContract.deployed();

    const gameContractFactory = await ethers.getContractFactory("Game");
    gameContract = await gameContractFactory.deploy();
    await gameContract.deployed();

    const tokenContractFactory = await ethers.getContractFactory("ARMYToken");
    tokenContract = await tokenContractFactory.deploy();
    await tokenContract.deployed();

    await playerContract.setMintContract(mintContract.address);
    await playerContract.setSale();
    await gameContract.setPlayerContract(playerContract.address);
    await gameContract.setTokenContract(tokenContract.address);
    await tokenContract.setGameContract(gameContract.address);

    LANDNAMES = await gameContract.getAllLandnames();
    DECIMALS = await tokenContract.decimals();
  });

  describe("playerContract", function () {
    it("Should set the right owner", async function () {
      expect(await playerContract.owner()).to.equal(owner.address);
    });

    it("Should prevent sales with setSale()", async function () {
      await playerContract.setSale(); // Turn mints off

      await expect(playerContract.mint()).to.be.revertedWith("Minting not active");
    
      await playerContract.setSale(); // Turn mints back on
    });

    it("Should mint the NFT", async function () {
      await playerContract.mint();

      expect(await playerContract.ownerOf(1)).to.equal(owner.address);
    });

    it("Should transfer tokens from a mint account", async function () {
      await playerContract.transferFrom(owner.address, addr1.address, 1);

      expect(await playerContract.ownerOf(1)).to.equal(addr1.address);
    });

    it("Should transfer tokens from secondary accounts", async function () {
      await playerContract.connect(addr1).transferFrom(addr1.address, addr2.address, 1);

      expect(await playerContract.ownerOf(1)).to.equal(addr2.address);

      // Transfer back to addr1:
      await playerContract.connect(addr2).transferFrom(addr2.address, addr1.address, 1);
    });

    it("Should prevent more than maxPlayers to mint", async function () {
      await playerContract.setMaxPlayers(1);

      await expect(playerContract.mint()).to.be.revertedWith("Max Players already minted");

      await playerContract.setMaxPlayers(6);
    });

    it("Should return the correct name", async function () {
      txn = await playerContract.getName(1);

      expect(txn).to.equal("BLACK");
    });

    it("Should return the correct PlayerAttributes object", async function () {
      txn = await playerContract.getPlayer(1);

      expect(txn['playerIndex'].toNumber()).to.equal(1);
      expect(txn['name']).to.equal('BLACK');
      expect(txn['imageURI']).to.equal('https://i.imgur.com/kbejWBd.png');
    });

    it("Should get all PlayerAttribute objects", async function () {
      txn = await playerContract.getAllPlayers();

      expect(txn[2].name).to.equal('BLUE');
      expect(txn[3].playerIndex.toNumber()).to.equal(3);
      expect(txn[4].imageURI).to.equal('https://i.imgur.com/Bm4Bvpx.png');
      expect(txn[5].name).to.equal('RED');
      expect(txn[6].imageURI).to.equal('https://i.imgur.com/KRZYJ4J.png');
    });

    it("Should get all minted PlayerAttribute objects", async function () {
      await playerContract.connect(addr2).mint(); // 2
      await playerContract.connect(addr3).mint(); // 3
      await playerContract.connect(addr4).mint(); // 4

      txn = await playerContract.getMintedPlayers();

      expect(txn.length).to.equal(5); // There is a 0 indexed unused object
      expect(txn[2].name).to.equal('BLUE');
      expect(txn[2].imageURI).to.equal('https://i.imgur.com/lreWZsa.png');
      expect(txn[3].name).to.equal('GREEN');
      expect(txn[4].imageURI).to.equal('https://i.imgur.com/Bm4Bvpx.png');
    });

    it("Should return the correct totalSupply", async function () {
      txn = await playerContract.totalSupply();

      expect(txn.toNumber()).to.equal(4);
    });
  });

  describe("tokenContract", function () {
    it("should prevent anyone but Game contract from minting", async function () {
      await expect(tokenContract.mint(owner.address, 100)).to.be.revertedWith("Only Game Contract can mint tokens");
    });

    it("should prevent anyone but Game Contract from burning", async function () {
      await expect(tokenContract.burn(owner.address, 100)).to.be.revertedWith("Only Game Contract can burn tokens");
    });
  });

  describe("gameContract", function () {
    it("startGame() initializes game correctly", async function () {
      await gameContract.startGame();

      for (let i = 0; i < LANDNAMES.length; i++) {
        let landOwner = (await gameContract.getLandOwner(i)).toNumber();
        let armySize = (await gameContract.getArmySize(i)).toNumber();

        expect(landOwner).to.not.equal(0);
        expect(landOwner).to.not.equal(5);
        expect(armySize).to.equal(1);
      }
      expect((await gameContract.getAvailableReward(1)).toNumber()).to.equal(3 * 10 ** DECIMALS);
      expect((await gameContract.getAvailableReward(2)).toNumber()).to.equal(3 * 10 ** DECIMALS);
      expect((await gameContract.getAvailableReward(3)).toNumber()).to.equal(3 * 10 ** DECIMALS);
      expect((await gameContract.getAvailableReward(4)).toNumber()).to.equal(3 * 10 ** DECIMALS);
    });

    it("should correctly return connected lands", async function () {
      let i1 = 0;
      let i2 = 3;

      txn = await gameContract.isConnectedTo(i1, i2);
      expect(txn).to.equal(true);

      i1 = 1;
      i2 = 4;
      txn = await gameContract.isConnectedTo(i1, i2);
      expect(txn).to.equal(true);

      i1 = 1;
      i2 = 5;
      txn = await gameContract.isConnectedTo(i1, i2);
      expect(txn).to.equal(false);
    });

    // At this point:
    // There are four Player NFTs. One belonging to each: owner, addr1, addr2, and addr3
    // They each hold randomized land with 1 army on each peice of land
    // They each have 3 ARMY tokens to claim
    it("claim ARMY tokens should fail if not owner of Player NFT", async function () {
      await expect(gameContract.claimArmyTokens(2)).to.be.revertedWith("Sender not owner of _playerTokenId");
    });

    it("should claim ARMY tokens", async function () {
      await gameContract.connect(addr1).claimArmyTokens(1);
      await gameContract.connect(addr2).claimArmyTokens(2);
      await gameContract.connect(addr3).claimArmyTokens(3);
      await gameContract.connect(addr4).claimArmyTokens(4);

      expect(await tokenContract.balanceOf(addr1.address)).to.equal(3 * 10 ** DECIMALS);
      expect(await tokenContract.balanceOf(addr2.address)).to.equal(3 * 10 ** DECIMALS);
      expect(await tokenContract.balanceOf(addr3.address)).to.equal(3 * 10 ** DECIMALS);
      expect(await tokenContract.balanceOf(addr4.address)).to.equal(3 * 10 ** DECIMALS);
    });

    it("should place armies", async function () {
      let addr1LandIds = [];
      let addr2LandIds = [];
      let addr3LandIds = [];
      let addr4LandIds = [];

      for(let i = 0; i < LANDNAMES.length; i++) {
        let landOwner = await gameContract.getLandOwner(i);

        if(landOwner == 1) {
          addr1LandIds.push(i);
        } else if(landOwner == 2) {
          addr2LandIds.push(i);
        } else if(landOwner == 3) {
          addr3LandIds.push(i);
        } else if(landOwner == 4) {
          addr4LandIds.push(i);
        } else {
          console.log("landId:", i, " not assigned an owner. Owner:", landOwner);
        }
      }

      await gameContract.connect(addr1).placeArmy(addr1LandIds[0], 3, 1);
      await gameContract.connect(addr2).placeArmy(addr2LandIds[1], 3, 2);
      await gameContract.connect(addr3).placeArmy(addr3LandIds[2], 2, 3);
      await gameContract.connect(addr4).placeArmy(addr4LandIds[3], 1, 4);

      expect(await gameContract.getArmySize(addr1LandIds[0])).to.equal(4);
      expect(await gameContract.getArmySize(addr2LandIds[1])).to.equal(4);
      expect(await gameContract.getArmySize(addr3LandIds[2])).to.equal(3);
      expect(await gameContract.getArmySize(addr4LandIds[3])).to.equal(2);

      expect(await tokenContract.balanceOf(addr1.address)).to.equal(0);
      expect(await tokenContract.balanceOf(addr2.address)).to.equal(0);
      expect(await tokenContract.balanceOf(addr3.address)).to.equal(1 * 10 ** DECIMALS);
      expect(await tokenContract.balanceOf(addr4.address)).to.equal(2 * 10 ** DECIMALS);
    });

    it("should reset part of board for testing purposes", async function () {
      await gameContract.changeLandOwner(6, 1);
      await gameContract.changeLandOwner(7, 2);
      await gameContract.changeLandOwner(4, 2);
      await gameContract.changeLandOwner(8, 3);
      await gameContract.changeLandOwner(9, 4);

      await gameContract.setArmySize(6, 2);
      await gameContract.setArmySize(7, 3);
      await gameContract.setArmySize(4, 1);
      await gameContract.setArmySize(8, 10);

      expect(await gameContract.getLandOwner(6)).to.equal(1);
      expect(await gameContract.getLandOwner(7)).to.equal(2);
      expect(await gameContract.getLandOwner(4)).to.equal(2);
      expect(await gameContract.getLandOwner(8)).to.equal(3);
      expect(await gameContract.getLandOwner(9)).to.equal(4);

      expect(await gameContract.getArmySize(6)).to.equal(2);
      expect(await gameContract.getArmySize(7)).to.equal(3);
      expect(await gameContract.getArmySize(4)).to.equal(1);
      expect(await gameContract.getArmySize(8)).to.equal(10);
    });

    it("should prevent anyone but owner of the territory from attacking", async function () {
      await expect(gameContract.connect(addr1).attack(7, 8, 1, 2)).to.be.revertedWith("Not owner of _playerTokenId");
      await expect(gameContract.connect(addr1).attack(7, 8, 1, 1)).to.be.revertedWith("_playerTokenId not owner of territory");
    });

    it("should prevent attacking non-adjacent territory", async function () {
      await expect(gameContract.connect(addr1).attack(6, 9, 1, 1)).to.be.revertedWith("Territories are not connected");
      await expect(gameContract.connect(addr2).attack(7, 9, 1, 2)).to.be.revertedWith("Territories are not connected");
    });

    it("should prevent attacking your own territory", async function () {
      await expect(gameContract.connect(addr2).attack(7, 4, 1, 2)).to.be.revertedWith("Cannot attack your own territory");
    });

    it("should prevent attacking when designated _armySize is larger than Army minus one", async function () {
      await expect(gameContract.connect(addr1).attack(6, 7, 2, 1)).to.be.revertedWith("Attacking army larger than allowable army size");
    });

    it("should prevent attacking from territory with only 1 army", async function () {
      await expect(gameContract.connect(addr2).attack(4, 6, 1, 2)).to.be.revertedWith("Attacking army larger than allowable army size");
    });

    it("should prevent attacking with 0 armies", async function () {
      await expect(gameContract.connect(addr3).attack(8, 9, 0, 3)).to.be.revertedWith("Attacking army must be greater than 0");
    });

    it("roll2Dice() and roll3Dice() work correctly", async function () {
      let seedId = 41;
      let output = await gameContract.testRoll2Dice(seedId);
      output = output.map((i) => Number(i)); // Convert array to int
      expect(output[0]).to.be.greaterThanOrEqual(output[1]);

      output = await gameContract.testRoll3Dice(seedId + 5);
      output = output.map((i) => Number(i)); // Convert array to int
      expect(output[0]).to.be.greaterThanOrEqual(output[1]);
      expect(output[1]).to.be.greaterThanOrEqual(output[2]);
    });

    it("should return the correct _battleResult()", async function () {
      let losses = await gameContract.testBattleResult(5, 3, 0);
      let attackerLoss = losses[0];
      let defenderLoss = losses[1];
      let attackerDice = losses[2];
      let defenderDice = losses[3];
      // console.log("attackerLoss:", attackerLoss.toString());
      // console.log("defenderLoss:", defenderLoss.toString());
      // console.log("attackerDice:", attackerDice.toString());
      // console.log("defenderDice:", defenderDice.toString());
      if(attackerDice[0] > defenderDice[0]) {
        if(attackerDice[1] > defenderDice[1]) {
          expect(attackerLoss).to.equal(0);
          expect(defenderLoss).to.equal(2);
        } else {
          expect(attackerLoss).to.equal(1);
          expect(defenderLoss).to.equal(1);
        }
      } else {
        if(attackerDice[1] > defenderDice[1]) {
          expect(attackerLoss).to.equal(1);
          expect(defenderLoss).to.equal(1);
        } else {
          expect(attackerLoss).to.equal(2);
          expect(defenderLoss).to.equal(0);
        }
      }
    });

    it("attack should have correct result", async function () {
      let fromId = 8;
      let toId = 7;
      let attackingArmySize = 3;
      let attackerTokenId = 3;

      let defenderTokenId = Number(await gameContract.getLandOwner(toId));
      let attackingTerritoryArmyAtStart = Number(await gameContract.getArmySize(fromId));
      let defendingTerritoryArmyAtStart = Number(await gameContract.getArmySize(toId));

      let txn = await gameContract.connect(addr3).attack(fromId, toId, attackingArmySize, attackerTokenId);
      let args = (await txn.wait()).events[0].args;
      let attackerLoss = Number(args.battleResult.attackerLoss);
      let defenderLoss = Number(args.battleResult.defenderLoss);

      if(args.defenderDefeated) {
        expect(Number(await gameContract.getLandOwner(fromId))).to.equal(attackerTokenId);
        expect(Number(await gameContract.getLandOwner(toId))).to.equal(attackerTokenId);
        expect(Number(await gameContract.getArmySize(fromId))).to.equal(attackingTerritoryArmyAtStart - attackingArmySize);
        expect(Number(await gameContract.getArmySize(toId))).to.equal(attackingArmySize - attackerLoss);
      } else {
        expect(Number(await gameContract.getLandOwner(fromId))).to.equal(attackerTokenId);
        expect(Number(await gameContract.getLandOwner(toId))).to.equal(defenderTokenId);
        expect(Number(await gameContract.getArmySize(fromId))).to.equal(attackingTerritoryArmyAtStart - attackerLoss);
        expect(Number(await gameContract.getArmySize(toId))).to.equal(defendingTerritoryArmyAtStart - defenderLoss);
      }
    });

    // // Not finished:
    // it("retrieves Landname", async function () {
    //   let i = 8;
    //   let landConnections;
    //   landConnections = await gameContract.getLandConnections(i);
    //   txn = await gameContract.getLandname(i);
    //   console.log("Landname[", i, "]: ", txn);
    //   console.log("Is connected to: ");

    //   for(let i = 0; i < landConnections.length; i++) {
    //     txn = await gameContract.getLandname(landConnections[i]);
    //     console.log("Landname[", i, "]: ", txn);
    //   }
    // });

    
  });
});