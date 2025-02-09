// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {AgneticTokenFactory} from "../src/AgneticTokenFactory.sol";
import {Constants} from "./base/Constants.sol";
import {AgneticHook} from "../src/AgneticHook.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";

/// @notice Mines the address and deploys the Hook contract and the TokenFactory
contract DeployAll is Script {
    // base sepolia addresses!
    // https://docs.uniswap.org/contracts/v4/deployments#base-sepolia-84532
    // https://docs.uniswap.org/contracts/v3/reference/deployments/base-deployments
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant POSM = 0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80;
    address constant POOLMANAGER = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
    address constant UNIVERSALROUTER = 0x492E6456D9528771018DeB9E87ef7750EF184104;
    // AgentKit Agent address
    address constant AGENT = 0xa6D6A5bf256a18dF12471e536F7d729c7672C181;

    function setUp() public {}

    function run() public {
        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG);

        vm.startBroadcast();

        AgneticTokenFactory factory = new AgneticTokenFactory(POSM, PERMIT2);
        console2.log("AgneticTokenFactory deployed to:", address(factory));

        vm.stopBroadcast();

        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs = abi.encode(IPoolManager(POOLMANAGER), AGENT, address(factory), UNIVERSALROUTER);

        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(AgneticHook).creationCode, constructorArgs);

        console2.log("Hook deployed to:", hookAddress);
        // Deploy the hook using CREATE2
        vm.startBroadcast();

        AgneticHook hook =
            new AgneticHook{salt: salt}(IPoolManager(POOLMANAGER), AGENT, address(factory), UNIVERSALROUTER);
        require(address(hook) == hookAddress, "DeployAll: hook address mismatch");

        factory.setHook(hookAddress);
        address token = factory.createToken("AgneticGOD", "AGOD");
        console2.log("AgneticGOD token deployed to:", token);
        vm.stopBroadcast();
    }
}
