// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./interfaces/IDexRouter.sol";
import "./interfaces/IDexFactory.sol";

contract LPRescue {
    uint16 public constant VERSION = 1;
    IDexRouter public immutable router;
    IDexFactory public immutable factory;

    /// Error while sorting the two token addresses from the pair
    /// @param reason the reason code: 1 = identical addresses, 2 = zero address
    error SortError(uint8 reason);

    constructor(address _router) {
        router = IDexRouter(_router);
        factory = IDexFactory(router.factory());
    }

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) {
            revert SortError(1); // identical addresses
        }
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) {
            revert SortError(2); // zero address
        }
    }
}
