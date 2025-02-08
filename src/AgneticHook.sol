// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {BaseHook} from "@uniswap/v4-periphery/src/base/hooks/BaseHook.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {IUniversalRouter} from "./IUniversalRouter.sol";

contract AgneticHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    // NOTE: ---------------------------------------------------------
    // state variables should typically be unique to a pool
    // a single hook contract should be able to service multiple pools
    // ---------------------------------------------------------------
    address immutable agent;
    address immutable tokenFactory;
    address immutable router;

    mapping(address => uint128) public depositBalances;

    modifier onlyAgent() {
        require(msg.sender == agent, "Must be agent");
        _;
    }

    event Deposit(address indexed sender, uint256 amount);
    event Swap(address indexed sender, uint256 amount);
    event Confiscate(address indexed sender, uint256 amount);

    constructor(IPoolManager _poolManager, address _agent, address _tokenFactory, address _router)
        BaseHook(_poolManager)
    {
        agent = _agent;
        tokenFactory = _tokenFactory;
        router = _router;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function deposit() external payable {
        require(msg.value > 0, "Must send some ETH");
        // No chance they ever send more than 2^128 - 1, so this should be safe
        depositBalances[msg.sender] += uint128(msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function check_deposit(address swapper) external view returns (bool) {
        return depositBalances[swapper] > 0;
    }

    function swapExactInputSingle(address token, uint128 amountIn) internal returns (uint256 amountOut) {
        PoolKey memory key = PoolKey({
            // native token
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(token),
            fee: 10000,
            tickSpacing: 200,
            hooks: IHooks(address(this))
        });
        uint128 minAmountOut = 0;

        // Following https://docs.uniswap.org/contracts/v4/quickstart/swap#32-encoding-the-swap-command

        // V4_SWAP = 0x10, from: https://github.com/Uniswap/universal-router/blob/main/contracts/libraries/Commands.sol
        bytes memory commands = abi.encodePacked(uint8(0x10));
        bytes[] memory inputs = new bytes[](1);

        // Encode V4Router actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));
        // bytes memory actions = abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE));

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        bytes memory hookData = abi.encode(address(this));
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                // zero will always be ETH so we can hardcode this?
                zeroForOne: true,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: hookData
            })
        );
        params[1] = abi.encode(key.currency0, amountIn);
        params[2] = abi.encode(key.currency1, minAmountOut);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        // Execute the swap
        IUniversalRouter(router).execute{value: amountIn}(commands, inputs, block.timestamp);

        // Verify and return the output amount
        amountOut = key.currency1.balanceOf(address(this));
        return amountOut;
    }

    function swap(address swapper, address token) external onlyAgent {
        uint128 amountIn = depositBalances[swapper];
        depositBalances[swapper] = 0;

        uint256 amountOut = swapExactInputSingle(token, amountIn);
        // We swapped on behalf of the user - send them their tokens
        IERC20(token).transfer(swapper, amountOut);
        emit Swap(swapper, amountOut);
    }

    function confiscate(address swapper, address token) external onlyAgent {
        uint128 amountIn = depositBalances[swapper];
        depositBalances[swapper] = 0;

        uint256 amountOut = swapExactInputSingle(token, amountIn);
        // Do an explicit burn
        IERC20(token).transfer(0x000000000000000000000000000000000000dEaD, amountOut);
        emit Confiscate(swapper, amountOut);
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------

    /// @notice The hook called before the state of a pool is initialized
    /// @param key The key for the pool being initialized
    /// @return bytes4 The function selector for the hook
    function beforeInitialize(address, PoolKey calldata key, uint160) external pure override returns (bytes4) {
        // Sender will actually be POSM - is it an issue?
        // require(sender == tokenFactory, "Only token factory can initialize");

        // Token0 will always be ETH?
        require(key.currency0 == CurrencyLibrary.ADDRESS_ZERO, "Token0 must be ETH");

        return BaseHook.beforeInitialize.selector;
    }

    /// @notice The hook called before a swap
    /// @param sender The initial msg.sender for the swap call
    /// @param params The parameters for the swap
    /// @param hookData Arbitrary data handed into the PoolManager by the swapper to be be passed on to the hook
    /// @return bytes4 The function selector for the hook
    /// @return BeforeSwapDelta The hook's delta in specified and unspecified currencies. Positive: the hook is owed/took currency, negative: the hook owes/sent currency
    /// @return uint24 Optionally override the lp fee, only used if three conditions are met: 1. the Pool has a dynamic fee, 2. the value's 2nd highest bit is set (23rd bit, 0x400000), and 3. the value is less than or equal to the maximum fee (1 million)
    function beforeSwap(
        address sender,
        PoolKey calldata,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external view override returns (bytes4, BeforeSwapDelta, uint24) {
        // Gate it if we're swapping ETH for the token
        if (params.zeroForOne) {
            // Ensure it's from the router, and the sender is the hook
            require(sender == router, "Can only process swaps through router!");
            // TODO - switch to running our own router, this could be faked
            address msgSender = abi.decode(hookData, (address));
            require(msgSender == address(this), "Swapper must be hook");
        }

        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }
}
