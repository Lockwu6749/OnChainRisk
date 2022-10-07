const main = async () => {
  const mintContractFactory = await ethers.getContractFactory("mintContract");
  const mintContract = await mintContractFactory.deploy(
    ["NA", "BLACK", "BLUE", "GREEN", "GRAY", "RED", "YELLOW"],
    ["NA", "https://i.imgur.com/kbejWBd.png",
    "https://i.imgur.com/lreWZsa.png",
    "https://i.imgur.com/NGCvIAg.png",
    "https://i.imgur.com/Bm4Bvpx.png",
    "https://i.imgur.com/j2VMPZW.png",
    "https://i.imgur.com/KRZYJ4J.png"]
  );

  await mintContract.deployed();
  console.log("mintContract deployed to:", mintContract.address);

  const playerContractFactory = await ethers.getContractFactory("Players");
  const playerContract = await playerContractFactory.deploy();
  await playerContract.deployed();
  console.log("playerContract deployed to: ", playerContract.address);
  await playerContract.setMintContract(mintContract.address);
  await playerContract.setSale();
  console.log("Finished Deploying contracts.");
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

// npx hardhat run scripts/deploy.js --network <network-name>