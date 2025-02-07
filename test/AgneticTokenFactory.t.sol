// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {AgneticTokenFactory, AgneticToken} from "../src/AgneticTokenFactory.sol";

contract MockPositionManager {
    function multicall(bytes[] memory calls) external returns (bytes[] memory results) {
        return new bytes[](calls.length);
    }
}

contract MockPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external {}
}

contract AgneticTokenFactoryTest is Test {
    AgneticTokenFactory public factory;
    MockPositionManager public positionManager;
    MockPermit2 public permit2;

    event TokenCreated(address tokenAddress, string name, string symbol, address owner);

    function setUp() public {
        positionManager = new MockPositionManager();
        permit2 = new MockPermit2();

        // Deploy the factory
        factory = new AgneticTokenFactory(address(positionManager), address(permit2));
        // Deploy and set mock hooks
        factory.setHook(address(0x1234));
    }

    function test_SetHook() public {
        // Try to set hook again (should fail)
        vm.expectRevert("Hook already set");
        factory.setHook(address(1));
    }

    function test_CreateToken() public {
        string memory name = "Test Token";
        string memory symbol = "TEST";

        // Expect TokenCreated event
        vm.expectEmit(false, true, true, false);
        emit TokenCreated(address(0), name, symbol, address(this)); // address(0) as we don't know the exact address

        // Create token
        address tokenAddress = factory.createToken(name, symbol);

        // Verify token details
        AgneticToken token = AgneticToken(tokenAddress);
        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.decimals(), 18);

        // Verify initial supply (1 billion tokens)
        assertEq(token.totalSupply(), 1_000_000_000 * 10 ** 18);
    }
}
