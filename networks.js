const HDWalletProvider = require('@truffle/hdwallet-provider');
require('dotenv').config();

module.exports = {
  networks: {
    development: {
      protocol: 'http',
      host: 'localhost',
      port: 8545,
      gas: 5000000,
      gasPrice: 5e9,
      networkId: '*',
    },
    'forked-mainnet': {
      provider: function() {
        return new HDWalletProvider([process.env.SECRET_KEY], 'http://localhost:7545');
      },
      skipDryRun: true,
      gas: 4000000,
      gasPrice: 5e9,
      networkId: 5353,
    },
    // mainnet: {
    //   provider: function() {
    //     return new HDWalletProvider([process.env.SECRET_KEY], process.env.INFURA_MAIN_URL);
    //   },
    //   network_id: 1,
    //   gas: 4000000,
    //   gasPrice: 40e9 // 40 [GWei]
    // },
  },
};
