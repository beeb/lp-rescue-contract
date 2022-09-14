import { expect } from 'chai'
import hre from 'hardhat'
import type { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import { constants } from 'ethers'
import {
  Token,
  Token__factory,
  LPRescue,
  UniswapV2Factory,
  UniswapV2Router02,
  UniswapV2Pair,
  WETH9,
} from '../typechain-types'

function eth(n: number) {
  return hre.ethers.utils.parseEther(n.toString())
}

describe('LPRescue', function () {
  let signer: SignerWithAddress
  let tokenFactory: Token__factory
  let factory: UniswapV2Factory
  let weth: WETH9
  let router: UniswapV2Router02
  let token0: Token
  let token1: Token
  let pair: UniswapV2Pair
  let rescue: LPRescue

  this.beforeAll(async () => {
    ;[signer] = await hre.ethers.getSigners()

    const Weth = await hre.ethers.getContractFactory('WETH9', signer)
    weth = (await Weth.deploy()) as WETH9

    const Factory = await hre.ethers.getContractFactory('UniswapV2Factory', signer)
    factory = (await Factory.deploy(constants.AddressZero)) as UniswapV2Factory

    const Router = await hre.ethers.getContractFactory('UniswapV2Router02', signer)
    router = (await Router.deploy(factory.address, weth.address)) as UniswapV2Router02

    const Rescue = await hre.ethers.getContractFactory('LPRescue')
    rescue = await Rescue.deploy(router.address)

    tokenFactory = await hre.ethers.getContractFactory('Token', signer)
  })

  this.beforeEach(async () => {
    const tokenA = await tokenFactory.deploy(eth(1_000))
    const tokenB = await tokenFactory.deploy(eth(1_000))
    await tokenA.deployed()
    await tokenB.deployed()
    await factory.createPair(tokenA.address, tokenB.address)
    const pairAddress = await factory.getPair(tokenA.address, tokenB.address)
    const Pair = await hre.ethers.getContractFactory('UniswapV2Pair', signer)
    pair = (await Pair.attach(pairAddress)) as UniswapV2Pair
    const token0Address = await pair.token0()
    token0 = token0Address == tokenA.address ? tokenA : tokenB
    token1 = token0Address == tokenA.address ? tokenB : tokenA
    await token0.approve(router.address, constants.MaxUint256)
    await token1.approve(router.address, constants.MaxUint256)
  })

  it('token0 should make pair stuck', async function () {
    await token0.transfer(pair.address, 666)
    await expect(pair.sync()).to.emit(pair, 'Sync')
    expect(await token0.balanceOf(pair.address)).to.equal(666)
    const reserves = await pair.getReserves()
    expect(reserves[0]).to.equal(666)
    expect(reserves[1]).to.equal(0)
    expect(await pair.totalSupply()).to.equal(0)
    await expect(
      router.addLiquidity(
        token0.address,
        token1.address,
        123,
        456,
        0,
        0,
        constants.AddressZero,
        (await time.latest()) + 3600
      )
    ).to.be.reverted
  })

  it('token1 should make pair stuck', async function () {
    await token1.transfer(pair.address, 420)
    await expect(pair.sync()).to.emit(pair, 'Sync')
    expect(await token1.balanceOf(pair.address)).to.equal(420)
    const reserves = await pair.getReserves()
    expect(reserves[0]).to.equal(0)
    expect(reserves[1]).to.equal(420)
    expect(await pair.totalSupply()).to.equal(0)
    await expect(
      router.addLiquidity(
        token0.address,
        token1.address,
        123,
        456,
        0,
        0,
        constants.AddressZero,
        (await time.latest()) + 3600
      )
    ).to.be.reverted
  })
})
