// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/interfaces/IWETH.sol";
import "src/interfaces/IDexFactory.sol";
import "src/interfaces/IDexRouter.sol";
import "src/interfaces/IDexPair.sol";
import "src/test/Token.sol";
import "src/LPRescue.sol";

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

    function setUp() public {
        weth = IWETH(deployCode("WETH9.sol"));
        factory = IDexFactory(
            deployCode("UniswapV2Factory.sol", abi.encode(address(0)))
        );
        router = IDexRouter(
            deployCode(
                "UniswapV2Router02.sol",
                abi.encode(address(factory), address(weth))
            )
        );
        rescue = new LPRescue(address(router));
        tokenA = new Token(1000 ether);
        tokenB = new Token(1000 ether);
        pair = IDexPair(factory.createPair(address(tokenA), address(tokenB)));
        pairWeth = IDexPair(factory.createPair(address(weth), address(tokenA)));
        tokenA.approve(address(router), type(uint).max);
        tokenB.approve(address(router), type(uint).max);
        weth.approve(address(router), type(uint).max);
        tokenA.approve(address(pair), type(uint).max);
        tokenB.approve(address(pair), type(uint).max);
        weth.approve(address(pairWeth), type(uint).max);
        tokenA.approve(address(pairWeth), type(uint).max);
        tokenA.approve(address(rescue), type(uint).max);
        tokenB.approve(address(rescue), type(uint).max);
        weth.approve(address(rescue), type(uint).max);
    }

    function makeTokenPairStuck(Token token, uint amount) private {
        token.transfer(address(pair), amount);
        vm.expectEmit(true, true, false, false);
        if (address(token) == pair.token0()) {
            emit Sync(uint112(amount), 0);
        } else {
            emit Sync(0, uint112(amount));
        }
        pair.sync();
        assertEq(tokenA.balanceOf(address(pair)), amount);
        assertEq(pair.totalSupply(), 0);
    }

    function test_SyncMakesPairStuck() public {
        makeTokenPairStuck(tokenA, 666);
    }

    function testFail_TokenAMakesPairStuck() public {
        makeTokenPairStuck(tokenA, 666);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            123,
            456,
            0,
            0,
            address(0),
            block.timestamp
        );
    }

    function testFail_TokenBMakesPairStuck() public {
        makeTokenPairStuck(tokenB, 420);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            123,
            456,
            0,
            0,
            address(0),
            block.timestamp
        );
    }
}
