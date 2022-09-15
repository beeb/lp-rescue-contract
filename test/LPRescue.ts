import { expect } from 'chai'
import hre from 'hardhat'
import type { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import { constants, type BigNumberish } from 'ethers'
import {
  Token,
  Token__factory,
  LPRescue,
  UniswapV2Factory,
  UniswapV2Router02,
  UniswapV2Pair,
  WETH9,
} from '../typechain-types'
import { token } from '../typechain-types/@openzeppelin/contracts'

function eth(n: number) {
  return hre.ethers.utils.parseEther(n.toString())
}

async function makePairStuck(pair: UniswapV2Pair, token: Token | WETH9, amount: BigNumberish, weth: WETH9) {
  if (token.address === weth.address) {
    await weth.deposit({ value: amount })
    await weth.transfer(pair.address, amount)
    await expect(pair.sync()).to.emit(pair, 'Sync')
    expect(await weth.balanceOf(pair.address)).to.equal(amount)
    return
  }
  await token.transfer(pair.address, amount)
  await expect(pair.sync()).to.emit(pair, 'Sync')
  expect(await token.balanceOf(pair.address)).to.equal(amount)
}

describe('LPRescue', function () {
  let signer: SignerWithAddress
  let tokenFactory: Token__factory
  let factory: UniswapV2Factory
  let weth: WETH9
  let router: UniswapV2Router02
  let token0: Token
  let token1: Token
  let tokenA: Token
  let pair: UniswapV2Pair
  let pairWeth: UniswapV2Pair
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
    tokenA = await tokenFactory.deploy(eth(1_000))
    const tokenB = await tokenFactory.deploy(eth(1_000))
    await tokenA.deployed()
    await tokenB.deployed()

    const Pair = await hre.ethers.getContractFactory('UniswapV2Pair', signer)
    await factory.createPair(tokenA.address, tokenB.address)
    let pairAddress = await factory.getPair(tokenA.address, tokenB.address)
    pair = (await Pair.attach(pairAddress)) as UniswapV2Pair

    await factory.createPair(weth.address, tokenA.address)
    pairAddress = await factory.getPair(weth.address, tokenA.address)
    pairWeth = (await Pair.attach(pairAddress)) as UniswapV2Pair

    const token0Address = await pair.token0()
    token0 = token0Address == tokenA.address ? tokenA : tokenB
    token1 = token0Address == tokenA.address ? tokenB : tokenA
    await token0.approve(router.address, constants.MaxUint256)
    await token1.approve(router.address, constants.MaxUint256)
    await weth.approve(router.address, constants.MaxUint256)
    await token0.approve(rescue.address, constants.MaxUint256)
    await token1.approve(rescue.address, constants.MaxUint256)
    await weth.approve(rescue.address, constants.MaxUint256)
    await token0.approve(pair.address, constants.MaxUint256)
    await token1.approve(pair.address, constants.MaxUint256)
    await tokenA.approve(pairWeth.address, constants.MaxUint256)
    await weth.approve(pairWeth.address, constants.MaxUint256)
  })

  it('token0 should make pair stuck', async function () {
    await makePairStuck(pair, token0, 666, weth)
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
    await makePairStuck(pair, token1, 420, weth)
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

  it('weth should make pair stuck', async function () {
    await makePairStuck(pairWeth, weth, 666, weth)
    expect(await tokenA.allowance(signer.address, router.address)).to.be.greaterThan(123)
    await expect(
      router.addLiquidityETH(tokenA.address, 123, 0, 0, constants.AddressZero, (await time.latest()) + 3600, {
        value: 456,
      })
    ).to.be.reverted
  })

  it('rescue pair stuck with weth', async function () {
    await makePairStuck(pairWeth, weth, eth(3), weth)
    expect(await tokenA.balanceOf(pairWeth.address)).to.equal(0)
    await expect(
      rescue.addLiquidity(tokenA.address, weth.address, eth(5), eth(10), signer.address, {
        value: eth(10),
      })
    )
      .to.emit(weth, 'Deposit')
      .withArgs(rescue.address, eth(7))
      .to.emit(rescue, 'LPRescued')
      .withArgs(tokenA.address, weth.address, pairWeth.address)
      .to.changeEtherBalances([signer, rescue, pairWeth], [eth(-7), 0, 0])

    expect(await pairWeth.totalSupply()).to.be.greaterThan(0)
    expect(await pairWeth.balanceOf(signer.address)).to.be.greaterThan(0)
  })

  it('rescue pair stuck with token', async function () {
    await makePairStuck(pair, token1, 666, weth)
    expect(await token0.balanceOf(pair.address)).to.equal(0)
    await expect(rescue.addLiquidity(token1.address, token0.address, eth(5), eth(3), constants.AddressZero))
      .to.emit(rescue, 'LPRescued')
      .withArgs(token1.address, token0.address, pair.address)
      .to.changeTokenBalances(token1, [signer, rescue, pair], [eth(-5).add(666), 0, eth(5).sub(666)])
      .to.changeTokenBalances(token0, [signer, rescue, pair], [eth(-3), 0, eth(3)])

    expect(await pair.totalSupply()).to.be.greaterThan(0)
    expect(await pair.balanceOf(signer.address)).to.equal(0) // lp tokens sent to zero address
  })

  it('pair has already too much', async function () {
    await makePairStuck(pair, token0, eth(1), weth)
    expect(await token1.balanceOf(pair.address)).to.equal(0)
    await expect(rescue.addLiquidity(token1.address, token0.address, eth(0.5), eth(0.1), constants.AddressZero))
      .to.be.revertedWithCustomError(rescue, 'InsufficientDesiredAmount')
      .withArgs(token0.address, eth(0.1), eth(1))
  })

  it('pair has exactly the desired amount', async function () {
    await makePairStuck(pair, token0, eth(0.5), weth)
    expect(await token1.balanceOf(pair.address)).to.equal(0)
    await expect(rescue.addLiquidity(token0.address, token1.address, eth(0.5), eth(0.5), signer.address))
      .to.be.revertedWithCustomError(rescue, 'InsufficientDesiredAmount')
      .withArgs(token0.address, eth(0.5), eth(0.5))
  })
})
