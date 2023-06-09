import {
	LPRescue,
	Token,
	Token__factory,
	UniswapV2Factory,
	UniswapV2Pair,
	UniswapV2Router02,
	WETH9,
} from '../typechain-types'
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { type BigNumberish } from 'ethers'
import { ethers } from 'hardhat'

function eth(n: number) {
	return ethers.parseEther(n.toString())
}

async function makePairStuck(pair: UniswapV2Pair, token: Token | WETH9, amount: BigNumberish, weth: WETH9) {
	if (token.target === weth.target) {
		await weth.deposit({ value: amount })
		await weth.transfer(pair.getAddress(), amount)
		await expect(pair.sync()).to.emit(pair, 'Sync')
		expect(await weth.balanceOf(pair.getAddress())).to.equal(amount)
		return
	}
	await token.transfer(pair.getAddress(), amount)
	await expect(pair.sync()).to.emit(pair, 'Sync')
	expect(await token.balanceOf(pair.getAddress())).to.equal(amount)
}

describe('LPRescue', function () {
	let signer: HardhatEthersSigner
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
		const [s] = await ethers.getSigners()
		signer = s

		weth = await ethers.deployContract('WETH9', signer)

		factory = await ethers.deployContract('UniswapV2Factory', [ethers.ZeroAddress], signer)

		router = await ethers.deployContract('UniswapV2Router02', [factory.getAddress(), weth.getAddress()], signer)

		rescue = await ethers.deployContract('LPRescue', [router.getAddress()], signer)

		tokenFactory = await ethers.getContractFactory('Token', signer)
	})

	this.beforeEach(async () => {
		tokenA = await tokenFactory.deploy(eth(1_000))
		const tokenB = await tokenFactory.deploy(eth(1_000))
		await tokenA.waitForDeployment()
		await tokenB.waitForDeployment()

		await factory.createPair(tokenA.getAddress(), tokenB.getAddress())
		let pairAddress = await factory.getPair(tokenA.getAddress(), tokenB.getAddress())
		pair = await ethers.getContractAt('UniswapV2Pair', pairAddress)

		await factory.createPair(weth.getAddress(), tokenA.getAddress())
		pairAddress = await factory.getPair(weth.getAddress(), tokenA.getAddress())
		pairWeth = await ethers.getContractAt('UniswapV2Pair', pairAddress)

		const token0Address = await pair.token0()
		token0 = token0Address == (await tokenA.getAddress()) ? tokenA : tokenB
		token1 = token0Address == (await tokenA.getAddress()) ? tokenB : tokenA
		await token0.approve(router.getAddress(), ethers.MaxUint256)
		await token1.approve(router.getAddress(), ethers.MaxUint256)
		await weth.approve(router.getAddress(), ethers.MaxUint256)
		await token0.approve(rescue.getAddress(), ethers.MaxUint256)
		await token1.approve(rescue.getAddress(), ethers.MaxUint256)
		await weth.approve(rescue.getAddress(), ethers.MaxUint256)
		await token0.approve(pair.getAddress(), ethers.MaxUint256)
		await token1.approve(pair.getAddress(), ethers.MaxUint256)
		await tokenA.approve(pairWeth.getAddress(), ethers.MaxUint256)
		await weth.approve(pairWeth.getAddress(), ethers.MaxUint256)
	})

	it('token0 should make pair stuck', async function () {
		await makePairStuck(pair, token0, 666, weth)
		const reserves = await pair.getReserves()
		expect(reserves[0]).to.equal(666)
		expect(reserves[1]).to.equal(0)
		expect(await pair.totalSupply()).to.equal(0)
		await expect(
			router.addLiquidity(
				token0.getAddress(),
				token1.getAddress(),
				123,
				456,
				0,
				0,
				ethers.ZeroAddress,
				(await time.latest()) + 3600,
			),
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
				token0.getAddress(),
				token1.getAddress(),
				123,
				456,
				0,
				0,
				ethers.ZeroAddress,
				(await time.latest()) + 3600,
			),
		).to.be.reverted
	})

	it('weth should make pair stuck', async function () {
		await makePairStuck(pairWeth, weth, 666, weth)
		expect(await tokenA.allowance(signer.getAddress(), router.getAddress())).to.be.greaterThan(123)
		await expect(
			router.addLiquidityETH(tokenA.getAddress(), 123, 0, 0, ethers.ZeroAddress, (await time.latest()) + 3600, {
				value: 456,
			}),
		).to.be.reverted
	})

	it('rescue pair stuck with weth', async function () {
		await makePairStuck(pairWeth, weth, eth(3), weth)
		expect(await tokenA.balanceOf(pairWeth.getAddress())).to.equal(0)
		await expect(
			rescue.addLiquidity(tokenA.getAddress(), weth.getAddress(), eth(5), eth(10), signer.getAddress(), {
				value: eth(10),
			}),
		)
			.to.emit(weth, 'Deposit')
			.withArgs(rescue.getAddress(), eth(7))
			.to.emit(rescue, 'LPRescued')
			.withArgs(tokenA.getAddress(), weth.getAddress(), pairWeth.getAddress())
			.to.changeEtherBalances([signer, rescue, pairWeth], [eth(-7), 0, 0])

		expect(await pairWeth.totalSupply()).to.be.greaterThan(0)
		expect(await pairWeth.balanceOf(signer.getAddress())).to.be.greaterThan(0)
	})

	it('rescue pair stuck with token', async function () {
		await makePairStuck(pair, token1, 666, weth)
		expect(await token0.balanceOf(pair.getAddress())).to.equal(0)
		await expect(rescue.addLiquidity(token1.getAddress(), token0.getAddress(), eth(5), eth(3), ethers.ZeroAddress))
			.to.emit(rescue, 'LPRescued')
			.withArgs(token1.getAddress(), token0.getAddress(), pair.getAddress())
			.to.changeTokenBalances(token1, [signer, rescue, pair], [eth(-5) + 666n, 0, eth(5) - 666n])
			.to.changeTokenBalances(token0, [signer, rescue, pair], [eth(-3), 0, eth(3)])

		expect(await pair.totalSupply()).to.be.greaterThan(0)
		expect(await pair.balanceOf(signer.getAddress())).to.equal(0) // lp tokens sent to zero address
	})

	it('pair has already too much', async function () {
		await makePairStuck(pair, token0, eth(1), weth)
		expect(await token1.balanceOf(pair.getAddress())).to.equal(0)
		await expect(rescue.addLiquidity(token1.getAddress(), token0.getAddress(), eth(0.5), eth(0.1), ethers.ZeroAddress))
			.to.be.revertedWithCustomError(rescue, 'InsufficientDesiredAmount')
			.withArgs(await token0.getAddress(), eth(0.1), eth(1))
	})

	it('pair has exactly the desired amount', async function () {
		await makePairStuck(pair, token0, eth(0.5), weth)
		expect(await token1.balanceOf(pair.getAddress())).to.equal(0)
		await expect(rescue.addLiquidity(token0.getAddress(), token1.getAddress(), eth(0.5), eth(0.5), signer.getAddress()))
			.to.be.revertedWithCustomError(rescue, 'InsufficientDesiredAmount')
			.withArgs(await token0.getAddress(), eth(0.5), eth(0.5))
	})

	it('undesired eth was sent too', async function () {
		await makePairStuck(pair, token0, 666, weth)
		expect(await token1.balanceOf(pair.getAddress())).to.equal(0)
		await expect(
			rescue.addLiquidity(token0.getAddress(), token1.getAddress(), eth(2), eth(2), signer.getAddress(), {
				value: eth(1),
			}),
		)
			.to.emit(rescue, 'LPRescued')
			.withArgs(await token0.getAddress(), await token1.getAddress(), await pair.getAddress())
			.to.changeTokenBalances(token0, [signer, rescue, pair], [eth(-2) + 666n, 0, eth(2)])
			.to.changeTokenBalances(token1, [signer, rescue, pair], [eth(-2), 0, eth(2)])
			.to.changeEtherBalance(signer, 0)

		expect(await pair.totalSupply()).to.be.greaterThan(0)
		expect(await pair.balanceOf(signer.getAddress())).to.be.greaterThan(0)
	})
})
