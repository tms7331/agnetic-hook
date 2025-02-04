// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AgneticToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply * (10 ** decimals()));
    }
}

contract AgneticTokenFactory {
    address public hookAddress;

    event TokenCreated(address tokenAddress, string name, string symbol, address owner);

    function createToken(string memory name, string memory symbol) external returns (address) {
        uint256 initialSupply = 1_000_000_000;
        AgneticToken newToken = new AgneticToken(name, symbol, initialSupply);

        // TODO - create a pool on the hook
        // TODO - deposit all liquidity into the pool

        emit TokenCreated(address(newToken), name, symbol, msg.sender);
        return address(newToken);
    }
}
