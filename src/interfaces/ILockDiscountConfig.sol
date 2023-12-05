// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

interface ILockDiscountConfig {
    /// @notice Adjusts the strike price multiplier based on the lock end time.
    /// @param multiplier The strike price multiplier to adjust.
    /// @param lockEnd The lock end time of the user.
    /// @return adjustedMultiplier The adjusted strike price multiplier.
    function getAdjustedMultiplier(uint16 multiplier, uint256 lockEnd)
        external
        view
        returns (uint16 adjustedMultiplier);
}
