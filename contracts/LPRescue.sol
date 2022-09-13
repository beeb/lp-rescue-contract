// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./interfaces/IDexRouter.sol";
import "./interfaces/IDexFactory.sol";

contract LPRescue {
    uint16 public constant VERSION = 1;
    IDexRouter public immutable router;
    IDexFactory public immutable factory;

    constructor(address _router) {
        router = IDexRouter(_router);
        factory = IDexFactory(router.factory());
    }
}
