// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IBalancerOracle} from "./IBalancerOracle.sol";

interface IOptionsToken is IERC20 {
    /// @notice Exercises options tokens to purchase the underlying tokens.
    /// @dev The options tokens are not burnt but sent to address(0) to avoid messing up the
    /// inflation schedule.
    /// The oracle may revert if it cannot give a secure result.
    /// @param amount The amount of options tokens to exercise
    /// @param maxPaymentAmount The maximum acceptable amount to pay. Used for slippage protection.
    /// @param recipient The recipient of the purchased underlying tokens
    /// @return paymentAmount The amount paid to the treasury to purchase the underlying tokens
    function exercise(uint256 amount, uint256 maxPaymentAmount, address recipient)
        external
        returns (uint256 paymentAmount);

    /// @notice Exercises options tokens to purchase the underlying tokens.
    /// @dev The options tokens are not burnt but sent to address(0) to avoid messing up the
    /// inflation schedule.
    /// The oracle may revert if it cannot give a secure result.
    /// @param amount The amount of options tokens to exercise
    /// @param maxPaymentAmount The maximum acceptable amount to pay. Used for slippage protection.
    /// @param recipient The recipient of the purchased underlying tokens
    /// @param deadline The Unix timestamp (in seconds) after which the call will revert
    /// @return paymentAmount The amount paid to the treasury to purchase the underlying tokens
    function exercise(uint256 amount, uint256 maxPaymentAmount, address recipient, uint256 deadline)
        external
        returns (uint256 paymentAmount);

    function paymentToken() external view returns (ERC20);
    function oracle() external view returns (IBalancerOracle);
    function underlyingToken() external view returns (ERC20);
}
