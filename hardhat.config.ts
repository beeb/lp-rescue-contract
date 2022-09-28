import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import '@nomiclabs/hardhat-etherscan'
import 'hardhat-abi-exporter'
import 'hardhat-gas-reporter'
import * as dotenv from 'dotenv'

dotenv.config()

const pk_testnet = process.env.PK_TESTNET || '0000000000000000000000000000000000000000000000000000000000000001'
const pk_mainnet = process.env.PK_MAINNET || '0000000000000000000000000000000000000000000000000000000000000001'
const etherscan_api_key = process.env.ETHERSCAN_API_KEY || ''

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {},
    testnet: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      chainId: 97,
      gasPrice: 20000000000,
      accounts: [pk_testnet],
    },
    mainnet: {
      url: 'https://bsc-dataseed.binance.org',
      chainId: 56,
      gasPrice: 5000000001,
      accounts: [pk_mainnet],
    },
  },
  etherscan: {
    apiKey: etherscan_api_key,
  },
  abiExporter: {
    runOnCompile: true,
    clear: true,
    flat: true,
    only: [':LPRescue$'],
  },
  gasReporter: {
    enabled: true,
  },
  solidity: {
    compilers: [
      {
        version: '0.8.16',
        settings: {
          optimizer: {
            enabled: true,
          },
        },
      },
      {
        version: '0.6.6',
        settings: {
          optimizer: {
            enabled: true,
          },
        },
      },
      {
        version: '0.5.16',
        settings: {
          optimizer: {
            enabled: true,
          },
        },
      },
    ],
  },
}

export default config
