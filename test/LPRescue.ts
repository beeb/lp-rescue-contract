import { expect } from 'chai'
import hre from 'hardhat'
import { UniswapV2Deployer, type IUniswapV2Factory, type IUniswapV2Router02 } from 'uniswap-v2-deploy-plugin'
import type { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'

function eth(n: number) {
  return hre.ethers.utils.parseEther(n.toString())
}

describe('LPRescue', function () {
  let signer: SignerWithAddress
  let token0
  let token1
  let factory: IUniswapV2Factory
  let router: IUniswapV2Router02

  this.beforeAll(async () => {
    ;[signer] = await hre.ethers.getSigners()
    const deployed = await UniswapV2Deployer.deploy(signer)
    factory = deployed.factory
    router = deployed.router

    const tokenFactory = await hre.ethers.getContractFactory('Token', signer)
    token0 = await tokenFactory.deploy(eth(1_000))
    token1 = await tokenFactory.deploy(eth(1_000))
    await token0.deployed()
    await token1.deployed()
  })

  it('Should deploy without errors', async function () {
    const Lpr = await hre.ethers.getContractFactory('LPRescue')
    const lpr = await Lpr.deploy(router.address)
    expect(lpr.address).to.exist
  })
})
