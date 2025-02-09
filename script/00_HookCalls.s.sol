// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {AgneticTokenFactory} from "../src/AgneticTokenFactory.sol";
import {AgneticHook} from "../src/AgneticHook.sol";
import {console2} from "forge-std/console2.sol";

/// TEMP
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";

contract HookCalls is Script {
    // Need to run 00_DeployAll.s.sol first, and get these addresses
    address constant token = 0x59646e90E5A703f23f73312207b416A038E2C176;
    address payable constant hook = payable(0x32Ad6efd93D32dcDf0Ffd2Fc09a271C234642080);

    function run() external {
        vm.startBroadcast();

        AgneticHook agneticHook = AgneticHook(hook);
        agneticHook.deposit{value: 0.01 ether}();
        // These calls will NOT work unless 'agent' address passed into hook constructor is set to be the calling address
        // This gets the address of the broadcaster
        // address caller = tx.origin;
        // agneticHook.swap(caller, token);
        // agneticHook.confiscate(caller, token);

        vm.stopBroadcast();
    }
}
