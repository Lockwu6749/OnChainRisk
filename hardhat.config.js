require('@nomiclabs/hardhat-waffle');
require('dotenv').config();

module.exports = {
  solidity: '0.8.9',
  networks: {
    rinkeby: {
      url: process.env.STAGING_ALCHEMY_URL,
      accounts: [process.env.PRIVATE_KEY],
    },
  },
};
