require('@openzeppelin/hardhat-upgrades');
require('@nomiclabs/hardhat-etherscan');
require('@nomiclabs/hardhat-waffle');

module.exports = {
  solidity: {
    version: '0.8.4',
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    ropsten: {
      url: 'https://ropsten.infura.io/v3/',
      accounts: [/* account private key */],
    },
    local: {
      url: 'http://127.0.0.1:8545',
      accounts: [/* account private key */],
    },
  },
  etherscan: {
    apiKey: {
      /* network api key */
    },
  },
};
