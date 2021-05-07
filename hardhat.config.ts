import { config as dotEnvConfig } from "dotenv";
dotEnvConfig();

import { HardhatUserConfig } from "hardhat/types";

require("./tasks/faucet");
require("./tasks/deploy");

import "@nomiclabs/hardhat-etherscan";

import "@nomiclabs/hardhat-waffle";
import "hardhat-typechain";
require('@openzeppelin/hardhat-upgrades');
import "hardhat-contract-sizer"
import "hardhat-gas-reporter";

const INFURA_API_KEY = process.env.INFURA_API_KEY || "";
const RINKEBY_PRIVATE_KEY =
  process.env.RINKEBY_PRIVATE_KEY! ||
  "0xc87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3"; // well known private key

const MATIC_PRIVATE_KEY =
  process.env.MATIC_PRIVATE_KEY! || "0xc87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3"
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [{
      version: "0.8.4", settings: {
        optimizer: {
          enabled: false,
          runs: 200
        }
      }
    }],
  },
  networks: {
    hardhat: {
      chainId: 1337
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
      accounts: { mnemonic: process.env.MAINNET_MNEMONIC || "" },
      gasPrice: 90000000000
    },
    localhost: {},
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [RINKEBY_PRIVATE_KEY],
    },
    matic: {
      url: "https://rpc-mainnet.matic.network",
      chainId: 137,
      accounts: [MATIC_PRIVATE_KEY],
      gasPrice: 1000000000
    },
    coverage: {
      url: "http://127.0.0.1:8555", // Coverage launches its own ganache-cli client
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: ETHERSCAN_API_KEY,
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  }
};

export default config;
