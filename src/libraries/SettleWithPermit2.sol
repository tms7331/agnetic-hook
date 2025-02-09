// Copy/paste from https://github.com/z0r0z/v4-router/blob/main/src/libraries/SettleWithPermit2.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {ISignatureTransfer} from "@uniswap/permit2/src/interfaces/ISignatureTransfer.sol";

/// @title SettleWithPermit2 Library
/// @notice Helper library for settling Uniswap V4 trades using Permit2 signatures
library SettleWithPermit2 {
    /// @notice Settles a trade using Permit2 for ERC20 tokens or direct transfer for ETH
    /// @param currency The currency being settled
    /// @param manager The Uniswap V4 pool manager contract
    /// @param permit2 The Permit2 contract instance
    /// @param payer The address paying for the trade
    /// @param amount The amount of currency to settle
    /// @param permit The Permit2 permission data for the transfer
    /// @param signature The signature authorizing the Permit2 transfer
    function settleWithPermit2(
        Currency currency,
        IPoolManager manager,
        ISignatureTransfer permit2,
        address payer,
        uint256 amount,
        ISignatureTransfer.PermitTransferFrom memory permit,
        bytes memory signature
    ) internal {
        manager.sync(currency);
        permit2.permitTransferFrom(
            permit,
            ISignatureTransfer.SignatureTransferDetails({to: address(manager), requestedAmount: amount}),
            payer,
            signature
        );
        manager.settle();
    }
}
