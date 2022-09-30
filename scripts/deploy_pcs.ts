import { ethers } from 'hardhat'
import hre from 'hardhat'
import assert from 'assert'

const router: Record<number, string> = {
  97: '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3',
  56: '0x10ED43C718714eb63d5aA57B78B54704E256024E',
}

async function main() {
  console.log('Deploying on network: ', hre.network.name)

  assert(hre.network.config.chainId && router[hre.network.config.chainId])

  const Contract = await ethers.getContractFactory('LPRescue')
  const contract = await Contract.deploy(router[hre.network.config.chainId])
  await contract.deployed()

  console.log('Contract deployed to:', contract.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
