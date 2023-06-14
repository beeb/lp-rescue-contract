// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {Script} from "forge-std/Script.sol";

import {LPRescue} from "src/LPRescue.sol";

/// @notice Simple deployment script for PancakeSwap on BSC
contract DeployPcs is Script {
    /// @notice The main script entrypoint
    /// @return rescue The deployed contract
    function run() external returns (LPRescue rescue) {
        uint256 deployerPrivateKey = vm.envUint("PK_MAINNET");
        vm.startBroadcast(deployerPrivateKey);

        rescue = new LPRescue(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        vm.stopBroadcast();
    }
}
