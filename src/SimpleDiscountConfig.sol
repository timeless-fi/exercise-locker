// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ILockDiscountConfig} from "./interfaces/ILockDiscountConfig.sol";

contract SimpleDiscountConfig is ILockDiscountConfig {
    uint256 internal constant TIME_LEFT_THRESHOLD = 3 * 365 days;
    uint256 internal constant ADJUSTMENT_MULTIPLIER = 5000;
    uint256 internal constant ADJUSTMENT_DIVISOR = 10000;

    function getAdjustedMultiplier(uint16 multiplier, uint256 lockEnd)
        external
        view
        override
        returns (uint16 adjustedMultiplier)
    {
        uint256 timeLeft = lockEnd - block.timestamp;
        if (timeLeft <= TIME_LEFT_THRESHOLD) {
            adjustedMultiplier = multiplier;
        } else {
            adjustedMultiplier = uint16(uint256(multiplier) * ADJUSTMENT_MULTIPLIER / ADJUSTMENT_DIVISOR);
        }
    }
}
