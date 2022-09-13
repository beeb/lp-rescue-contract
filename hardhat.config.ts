import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import * as dotenv from 'dotenv'

dotenv.config()

const pk_testnet = process.env.PK_TESTNET || ''
const pk_mainnet = process.env.PK_MAINNET || ''

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {},
    testnet: {
      url: 'https://data-seed-prebsc-2-s3.binance.org:8545',
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
  solidity: {
    version: '0.8.16',
    settings: {
      optimizer: {
        enabled: true,
      },
    },
  },
}

export default config
