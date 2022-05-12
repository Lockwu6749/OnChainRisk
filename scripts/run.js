const main = async () => {
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

  await playerContract.connect(addr1).mint();
  await playerContract.connect(addr2).mint();
  await playerContract.connect(addr3).mint();
  await playerContract.connect(addr4).mint();

  let attackerSize = 3;
  let defenderSize = 2;
  let attackerLosses = 0;
  let defenderLosses = 0;
  let result;
  let txn;
  for(let i = 0; i < 10000; i++) {
    result = await gameContract.testBattleResult(attackerSize, defenderSize, 0);
    attackerLosses += parseInt(result[0]);
    defenderLosses += parseInt(result[1]);
    txn = await gameContract.setCardTokenContract(tokenContract.address);
    txn.wait();
    if(i % 10 == 0) {
      console.log(i);
    }
    
    // console.log("attackerDice:", result[2].toString());
    // console.log("defenderDice:", result[3].toString());
    // console.log("attackerLosses:", attackerLosses);
    // console.log("defenderLosses:", defenderLosses);
    // console.log("\n");
  }
  console.log("attackerLosses:", attackerLosses);
  console.log("defenderLosses:", defenderLosses);
};

const runMain = async () => {
  try {
    await main();
    process.exit(0);
  } catch (error) {
    console.log(error);
    process.exit(1);
  }
};

runMain();