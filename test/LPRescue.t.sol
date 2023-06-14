// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
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

    function setUp() public {
        weth = IWETH(deployCode("WETH9.sol"));
        factory = IDexFactory(
            deployCode(
                "DexFactory.sol:UniswapV2Factory",
                abi.encode(address(0))
            )
        );
        router = IDexRouter(
            deployCode(
                "DexRouter.sol:UniswapV2Router02",
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
}
