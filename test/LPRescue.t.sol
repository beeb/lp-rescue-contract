// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/test/WETH9.sol";
import "src/test/DexFactory.sol";
import "src/test/DexRouter.sol";
import "src/test/DexPair.sol";
import "src/test/Token.sol";
import "src/LPRescue.sol";

contract LPRescueTest is Test {
    WETH9 weth;
    UniswapV2Factory factory;
    UniswapV2Router02 router;
    LPRescue rescue;
    Token tokenA;
    Token tokenB;
    UniswapV2Pair pair;
    UniswapV2Pair pairWeth;

    function setUp() public {
        weth = new WETH9();
        factory = new UniswapV2Factory(address(0));
        router = new UniswapV2Router02(address(factory), address(weth));
        rescue = new LPRescue(address(router));
        tokenA = new Token(1000 ether);
        tokenB = new Token(1000 ether);
        pair = factory.createPair(address(tokenA), address(tokenB));
        pairWeth = factory.createPair(address(weth), address(tokenA));
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
}
