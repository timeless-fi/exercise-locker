// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {IVotingEscrow} from "./external/IVotingEscrow.sol";
import {IOptionsToken} from "./external/IOptionsToken.sol";
import {IBalancerOracle} from "./external/IBalancerOracle.sol";
import {ILockDiscountConfig} from "./interfaces/ILockDiscountConfig.sol";

contract ExerciseLocker is Owned {
    error ExerciseLocker__ZeroAmount();
    error ExerciseLocker__NoExistingLock();
    error ExerciseLocker__NotEnoughOptionsAllowance();

    IVotingEscrow internal immutable votingEscrow;
    IOptionsToken internal immutable optionsToken;
    IBalancerOracle internal immutable oracle;
    ERC20 internal immutable paymentToken;

    ILockDiscountConfig public lockDiscountConfig;

    constructor(
        IVotingEscrow votingEscrow_,
        IOptionsToken optionsToken_,
        IBalancerOracle oracle_,
        ILockDiscountConfig lockDiscountConfig_,
        address owner_
    ) Owned(owner_) {
        votingEscrow = votingEscrow_;
        optionsToken = optionsToken_;
        oracle = oracle_;
        ERC20 paymentToken_ = optionsToken_.paymentToken();
        paymentToken = paymentToken_;

        lockDiscountConfig = lockDiscountConfig_;

        // set approval to optionsToken
        paymentToken_.approve(address(optionsToken_), type(uint256).max);
    }

    function exerciseAndLock(uint256 amount, uint256 maxPaymentAmount, address recipient, uint256 deadline) external {
        /// -----------------------------------------------------------------------
        /// Validation
        /// -----------------------------------------------------------------------

        // validate amount
        if (amount == 0) {
            revert ExerciseLocker__ZeroAmount();
        }

        // query user lock
        IVotingEscrow.LockedBalance memory lockedBalance = votingEscrow.locked(recipient);
        if (lockedBalance.amount <= 0 || lockedBalance.end <= block.timestamp) {
            revert ExerciseLocker__NoExistingLock();
        }

        // query recipient's oLIT approval to votingEscrow
        // necessary for votingEscrow.deposit_for()
        uint256 optionsTokenAllowance = optionsToken.allowance(recipient, address(votingEscrow));
        if (optionsTokenAllowance < amount) {
            revert ExerciseLocker__NotEnoughOptionsAllowance();
        }

        // cache oracle parameters
        uint16 oracleMultiplier = oracle.multiplier();
        uint56 oracleSecs = oracle.secs();
        uint56 oracleAgo = oracle.ago();
        uint128 oracleMinPrice = oracle.minPrice();

        /// -----------------------------------------------------------------------
        /// External calls
        /// -----------------------------------------------------------------------

        // transfer oLIT from user
        optionsToken.transferFrom(msg.sender, address(this), amount);

        // adjust multiplier based on user lock time
        uint16 adjustedMultiplier = lockDiscountConfig.getAdjustedMultiplier(oracleMultiplier, lockedBalance.end);

        // call oracle to update multiplier based on user lock time
        oracle.setParams(adjustedMultiplier, oracleSecs, oracleAgo, oracleMinPrice);

        // exercise oLIT to get LIT
        optionsToken.exercise(amount, maxPaymentAmount, recipient, deadline);

        // revert to previous oracle multiplier
        oracle.setParams(oracleMultiplier, oracleSecs, oracleAgo, oracleMinPrice);

        // lock LIT in votingEscrow
        votingEscrow.deposit_for(recipient, amount);
    }

    function setOracleOwner(address newOwner) external onlyOwner {
        oracle.setOwner(newOwner);
    }

    function setLockDiscountConfig(ILockDiscountConfig newLockDiscountConfig) external onlyOwner {
        lockDiscountConfig = newLockDiscountConfig;
    }
}
