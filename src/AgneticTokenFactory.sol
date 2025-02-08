// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/src/interfaces/IAllowanceTransfer.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {IPoolInitializer_v4} from "@uniswap/v4-periphery/src/interfaces/IPoolInitializer_v4.sol";

contract AgneticToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply * (10 ** decimals()));
    }
}

contract AgneticTokenFactory {
    address immutable posm;
    address immutable permit2;
    address private hook;

    event TokenCreated(address tokenAddress, string name, string symbol, address owner);

    constructor(address _posm, address _permit2) {
        posm = _posm;
        permit2 = _permit2;
    }

    function setHook(address _hook) external {
        require(hook == address(0), "Hook already set");
        hook = _hook;
    }

    function deployAndApprove(string memory name, string memory symbol) internal returns (address) {
        uint256 initialSupply = 1_000_000_000;
        AgneticToken newToken = new AgneticToken(name, symbol, initialSupply);

        // approve permit2 as a spender
        newToken.approve(address(permit2), type(uint256).max);
        // approve `PositionManager` as a spender
        IAllowanceTransfer(address(permit2)).approve(address(newToken), posm, type(uint160).max, type(uint48).max);

        emit TokenCreated(address(newToken), name, symbol, msg.sender);
        return address(newToken);
    }

    function createToken(string memory name, string memory symbol) external returns (address) {
        address newToken = deployAndApprove(name, symbol);
        // https://docs.uniswap.org/contracts/v4/quickstart/create-pool
        // https://docs.uniswap.org/contracts/v4/deployments#base-sepolia-84532

        bytes[] memory params = new bytes[](2);
        // https://docs.uniswap.org/contracts/v4/quickstart/create-pool
        // the startingPrice is expressed as sqrtPriceX96: floor(sqrt(token1 / token0) * 2^96)
        // i.e. 79228162514264337593543950336 is the starting price for a 1:1 pool
        uint256 sqrtPriceX96 = 79228162514264337593543950336;
        PoolKey memory pool = PoolKey({
            // native token
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(address(newToken)),
            fee: 10000,
            tickSpacing: 200,
            hooks: IHooks(hook)
        });

        params[0] = abi.encodeWithSelector(IPoolInitializer_v4.initializePool.selector, pool, sqrtPriceX96);
        bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
        bytes[] memory mintParams = new bytes[](2);

        // Half range stake
        int24 tickLower = -887200;
        int24 tickUpper = 0;
        // Had to calculate this manually, uses approximately the full supply of the token
        int256 liquidity = 1000000000000000000000000000;
        uint256 amount0Max = 0;
        uint256 amount1Max = type(uint256).max;
        address recipient = address(this);
        bytes memory hookData = abi.encode(hook);

        mintParams[0] = abi.encode(pool, tickLower, tickUpper, liquidity, amount0Max, amount1Max, recipient, hookData);
        mintParams[1] = abi.encode(pool.currency0, pool.currency1);
        uint256 deadline = block.timestamp + 60;
        params[1] = abi.encodeWithSelector(
            IPositionManager.modifyLiquidities.selector, abi.encode(actions, mintParams), deadline
        );
        IPositionManager(posm).multicall(params);

        return address(newToken);
    }
}
