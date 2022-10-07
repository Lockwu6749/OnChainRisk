require('@nomiclabs/hardhat-waffle');
require('dotenv').config();

module.exports = {
  solidity: '0.8.7',
  networks: {
    rinkeby: {
      url: process.env.STAGING_ALCHEMY_URL_RINKEBY,
      accounts: [process.env.PRIVATE_KEY2],
    },
    ropsten: {
      url: process.env.STAGING_ALCHEMY_URL_ROPSTEN,
      accounts: [process.env.PRIVATE_KEY2],
    },
  },
};
