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
import {BaseHookRouter, BaseData} from "./BaseHookRouter.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {ISignatureTransfer} from "./libraries/SettleWithPermit2.sol";

contract AgneticHook is BaseHookRouter {
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

    constructor(
        IPoolManager _poolManager,
        ISignatureTransfer _permit2,
        address _agent,
        address _tokenFactory,
        address _router
    ) BaseHookRouter(_poolManager, _permit2) {
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

    function swap(address swapper, address token) external onlyAgent {
        uint128 amountIn = depositBalances[swapper];
        depositBalances[swapper] = 0;
        _handle_swap(token, amountIn, swapper);
    }

    function confiscate(address swapper, address token) external onlyAgent {
        uint128 amountIn = depositBalances[swapper];
        depositBalances[swapper] = 0;
        address burnAddr = 0x000000000000000000000000000000000000dEaD;
        // Will swap and burn tokens!
        _handle_swap(token, amountIn, burnAddr);
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

        return BaseHookRouter.beforeInitialize.selector;
    }

    /// @notice The hook called before a swap
    /// @param sender The initial msg.sender for the swap call
    /// @param params The parameters for the swap
    /// @return bytes4 The function selector for the hook
    /// @return BeforeSwapDelta The hook's delta in specified and unspecified currencies. Positive: the hook is owed/took currency, negative: the hook owes/sent currency
    /// @return uint24 Optionally override the lp fee, only used if three conditions are met: 1. the Pool has a dynamic fee, 2. the value's 2nd highest bit is set (23rd bit, 0x400000), and 3. the value is less than or equal to the maximum fee (1 million)
    function beforeSwap(address sender, PoolKey calldata, IPoolManager.SwapParams calldata params, bytes calldata)
        external
        view
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        // Gate it if we're swapping ETH for the token
        if (params.zeroForOne) {
            require(sender == address(this), "Can only process buys initiated through hook");
        }

        return (BaseHookRouter.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function _handle_swap(address token, uint128 amountIn, address recipient) internal {
        uint256 amountOutMin = 0;
        bool zeroForOne = true;
        PoolKey memory key = PoolKey({
            // native token
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(token),
            fee: 10000,
            tickSpacing: 200,
            hooks: IHooks(address(this))
        });

        bytes memory hookData;
        _unlockAndDecode(
            abi.encode(
                BaseData({
                    amount: uint256(amountIn),
                    amountLimit: amountOutMin,
                    payer: address(this),
                    receiver: recipient,
                    singleSwap: true,
                    exactOutput: false,
                    input6909: false,
                    output6909: false,
                    permit2: false
                }),
                zeroForOne,
                key,
                hookData
            )
        );
    }
}
