import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config";
require('@typechain/hardhat');

const PRIVATE_KEY = process.env.PRIVATE_KEY


module.exports = {
    solidity: "0.8.9",
    networks: {
        hyperspace: {
        // url: "https://filecoin-hyperspace.chainstacklabs.com/rpc/v1",
        url: "https://rpc.ankr.com/filecoin_testnet",
        accounts: [PRIVATE_KEY],
      },
      fuji : {
        url: "https://api.avax-test.network/ext/bc/C/rpc",
        accounts: [PRIVATE_KEY],
      }
    },
    typechain: {
      outDir: 'types',
      target: 'ethers-v5',
    },
  };