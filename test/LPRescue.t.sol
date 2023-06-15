// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {Test} from "forge-std/Test.sol";
import {IWETH} from "src/interfaces/IWETH.sol";
import {IDexFactory} from "src/interfaces/IDexFactory.sol";
import {IDexRouter} from "src/interfaces/IDexRouter.sol";
import {IDexPair} from "src/interfaces/IDexPair.sol";
import {Token} from "src/fixtures/Token.sol";
import {LPRescue} from "src/LPRescue.sol";

contract LPRescueTest is Test {
    IWETH weth;
    IDexFactory factory;
    IDexRouter router;
    LPRescue rescue;
    Token tokenA;
    Token tokenB;
    IDexPair pair;
    IDexPair pairWeth;

    event Sync(uint112 reserve0, uint112 reserve1);
    event Deposit(address indexed dst, uint256 wad);
    event LPRescued(address tokenA, address tokenB, address pair);

    receive() external payable {}

    function setUp() public {
        vm.deal(address(this), 100 ether);
        weth = IWETH(deployCode("WETH9.sol"));
        factory = IDexFactory(deployCode("UniswapV2Factory.sol", abi.encode(address(0))));
        router = IDexRouter(deployCode("UniswapV2Router02.sol", abi.encode(address(factory), address(weth))));
        rescue = new LPRescue(address(router));
        tokenA = new Token(1000 ether);
        tokenB = new Token(1000 ether);
        pair = IDexPair(factory.createPair(address(tokenA), address(tokenB)));
        pairWeth = IDexPair(factory.createPair(address(weth), address(tokenA)));

        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        weth.approve(address(router), type(uint256).max);

        tokenA.approve(address(pair), type(uint256).max);
        tokenB.approve(address(pair), type(uint256).max);

        weth.approve(address(pairWeth), type(uint256).max);
        tokenA.approve(address(pairWeth), type(uint256).max);

        tokenA.approve(address(rescue), type(uint256).max);
        tokenB.approve(address(rescue), type(uint256).max);
        weth.approve(address(rescue), type(uint256).max);
    }

    function _makeTokenPairStuck(Token token, uint256 amount) private {
        token.transfer(address(pair), amount);
        vm.expectEmit(true, true, false, false);
        if (address(token) == pair.token0()) {
            emit Sync(uint112(amount), 0);
        } else {
            emit Sync(0, uint112(amount));
        }
        pair.sync();
        assertEq(token.balanceOf(address(pair)), amount);
        assertEq(pair.totalSupply(), 0);
    }

    function _makeWethPairStuck(uint256 amount) private {
        weth.deposit{value: amount}();
        weth.transfer(address(pairWeth), amount);
        vm.expectEmit(true, true, false, false);
        if (address(weth) == pairWeth.token0()) {
            emit Sync(uint112(amount), 0);
        } else {
            emit Sync(0, uint112(amount));
        }
        pairWeth.sync();
        assertEq(weth.balanceOf(address(pairWeth)), amount);
        assertEq(pairWeth.totalSupply(), 0);
    }

    function test_UniswapWorks() public {
        router.addLiquidity(address(tokenA), address(tokenB), 0.1 ether, 0.1 ether, 0, 0, address(0), block.timestamp);
    }

    function test_SyncMakesPairStuck() public {
        _makeTokenPairStuck(tokenA, 666);
    }

    function test_SyncMakesWethPairStuck() public {
        _makeWethPairStuck(420);
    }

    function testFail_TokenAMakesPairStuck() public {
        _makeTokenPairStuck(tokenA, 666);
        router.addLiquidity(address(tokenA), address(tokenB), 0.1 ether, 0.1 ether, 0, 0, address(0), block.timestamp);
    }

    function testFail_TokenBMakesPairStuck() public {
        _makeTokenPairStuck(tokenB, 420);
        router.addLiquidity(address(tokenA), address(tokenB), 0.1 ether, 0.1 ether, 0, 0, address(0), block.timestamp);
    }

    function testFail_WethMakesPairStuck() public {
        _makeWethPairStuck(666);
        router.addLiquidityETH{value: 0.1 ether}(address(tokenA), 0.1 ether, 0, 0, address(0), block.timestamp);
    }

    function test_RescuePairStuckWithWeth() public {
        _makeWethPairStuck(3 ether);
        uint256 balanceBefore = address(this).balance;
        assertEq(tokenA.balanceOf(address(pairWeth)), 0);
        vm.expectEmit(true, true, false, false);
        emit Deposit(address(rescue), 7 ether); // 3 ether + 7 ether = 10 ether
        vm.expectEmit(true, true, true, false);
        emit LPRescued(address(tokenA), address(weth), address(pairWeth));
        (uint256 amountAActual, uint256 amountBActual, uint256 liquidity) =
            rescue.addLiquidity{value: 10 ether}(address(tokenA), address(weth), 5 ether, 10 ether, address(this));
        assertEq(address(this).balance, balanceBefore - 7 ether);
        assertGt(pairWeth.totalSupply(), 0);
        assertGt(pairWeth.balanceOf(address(this)), 0);
        assertEq(amountAActual, 5 ether);
        assertEq(amountBActual, 7 ether); // 10 ether - 3 ether stuck in the pair
        assertEq(pairWeth.balanceOf(address(this)), liquidity);
    }

    function test_RescuePairStuckWithToken() public {
        _makeTokenPairStuck(tokenB, 666);
        uint256 balanceBeforeB = tokenB.balanceOf(address(this));
        uint256 balanceBeforeA = tokenA.balanceOf(address(this));
        assertEq(tokenA.balanceOf(address(pair)), 0);
        vm.expectEmit(true, true, true, false);
        emit LPRescued(address(tokenB), address(tokenA), address(pair));
        (uint256 amountBActual, uint256 amountAActual, uint256 liquidity) =
            rescue.addLiquidity(address(tokenB), address(tokenA), 5 ether, 3 ether, address(1));
        assertEq(tokenB.balanceOf(address(this)), balanceBeforeB - 5 ether + 666);
        assertEq(tokenA.balanceOf(address(this)), balanceBeforeA - 3 ether);
        assertGt(pair.totalSupply(), 0);
        assertGt(pair.balanceOf(address(1)), 0);
        assertEq(pair.balanceOf(address(this)), 0);
        assertEq(amountBActual, 5 ether - 666);
        assertEq(amountAActual, 3 ether);
        assertEq(pair.balanceOf(address(1)), liquidity);
    }

    function test_PairHasAlreadyTooMuch() public {
        _makeTokenPairStuck(tokenA, 1 ether);
        assertEq(tokenB.balanceOf(address(pair)), 0);
        vm.expectRevert(
            abi.encodeWithSelector(LPRescue.InsufficientDesiredAmount.selector, address(tokenA), 0.1 ether, 1 ether)
        );
        rescue.addLiquidity(address(tokenB), address(tokenA), 0.5 ether, 0.1 ether, address(0));
    }

    function test_PairHasExactlyDesiredAmount() public {
        _makeTokenPairStuck(tokenA, 0.5 ether);
        assertEq(tokenB.balanceOf(address(pair)), 0);
        vm.expectRevert(
            abi.encodeWithSelector(LPRescue.InsufficientDesiredAmount.selector, address(tokenA), 0.5 ether, 0.5 ether)
        );
        rescue.addLiquidity(address(tokenA), address(tokenB), 0.5 ether, 0.5 ether, address(0));
    }

    function test_SuperfluousEthIsRefunded() public {
        _makeTokenPairStuck(tokenA, 666);
        assertEq(tokenB.balanceOf(address(pair)), 0);
        uint256 balanceBefore = address(this).balance;
        uint256 balanceBeforeA = tokenA.balanceOf(address(this));
        uint256 balanceBeforeB = tokenB.balanceOf(address(this));
        uint256 pairBalanceBefore = address(pair).balance;
        uint256 pairBalanceBeforeA = tokenA.balanceOf(address(pair));
        uint256 pairBalanceBeforeB = tokenB.balanceOf(address(pair));
        uint256 rescueBalanceBefore = address(rescue).balance;
        uint256 rescueBalanceBeforeA = tokenA.balanceOf(address(rescue));
        uint256 rescueBalanceBeforeB = tokenB.balanceOf(address(rescue));
        vm.expectEmit(true, true, true, false);
        emit LPRescued(address(tokenA), address(tokenB), address(pair));
        (uint256 amountAActual, uint256 amountBActual, uint256 liquidity) =
            rescue.addLiquidity{value: 1 ether}(address(tokenA), address(tokenB), 2 ether, 2 ether, address(this));
        assertEq(amountAActual, 2 ether - 666);
        assertEq(amountBActual, 2 ether);
        assertEq(pair.balanceOf(address(this)), liquidity);

        assertEq(tokenA.balanceOf(address(this)), balanceBeforeA - 2 ether + 666);
        assertEq(tokenB.balanceOf(address(this)), balanceBeforeB - 2 ether);
        assertEq(address(this).balance, balanceBefore);

        assertEq(address(pair).balance, pairBalanceBefore);
        assertEq(tokenA.balanceOf(address(pair)), pairBalanceBeforeA + 2 ether - 666);
        assertEq(tokenB.balanceOf(address(pair)), pairBalanceBeforeB + 2 ether);

        assertEq(address(rescue).balance, rescueBalanceBefore);
        assertEq(tokenA.balanceOf(address(rescue)), rescueBalanceBeforeA);
        assertEq(tokenB.balanceOf(address(rescue)), rescueBalanceBeforeB);

        assertGt(pair.totalSupply(), 0);
        assertGt(pair.balanceOf(address(this)), 0);
    }

    function test_PairIsNotStuck() public {
        vm.expectRevert(LPRescue.PairNotStuck.selector);
        rescue.addLiquidity(address(tokenA), address(tokenB), 0.1 ether, 1 ether, address(0));
    }

    function test_PairIsTrading() public {
        router.addLiquidity(address(tokenA), address(tokenB), 0.1 ether, 0.1 ether, 0, 0, address(0), block.timestamp);
        vm.expectRevert(LPRescue.PairNotStuck.selector);
        rescue.addLiquidity(address(tokenA), address(tokenB), 0.1 ether, 1 ether, address(0));
    }
}
