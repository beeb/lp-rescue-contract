// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {Script} from "forge-std/Script.sol";

import {LPRescue} from "src/LPRescue.sol";

/// @notice Simple deployment script for PancakeSwap on BSC Testnet
contract DeployPcs is Script {
    /// @notice The main script entrypoint
    /// @return rescue The deployed contract
    function run() external returns (LPRescue rescue) {
        uint256 deployerPrivateKey = vm.envUint("PK_TESTNET");
        vm.startBroadcast(deployerPrivateKey);

        rescue = new LPRescue(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);

        vm.stopBroadcast();
    }
}
