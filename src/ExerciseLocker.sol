// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import "./external/IBalancerCore.sol";
import {IVotingEscrow} from "./external/IVotingEscrow.sol";
import {IOptionsToken} from "./external/IOptionsToken.sol";
import {IBalancerOracle} from "./external/IBalancerOracle.sol";
import {ILockDiscountConfig} from "./interfaces/ILockDiscountConfig.sol";

contract ExerciseLocker is Owned {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using FixedPointMathLib for uint256;

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error ExerciseLocker__ZeroAmount();
    error ExerciseLocker__NoExistingLock();
    error ExerciseLocker__BptPairWethAmountTooHigh();
    error ExerciseLocker__NotEnoughOptionsAllowance();

    /// -----------------------------------------------------------------------
    /// Constants and immutables
    /// -----------------------------------------------------------------------

    IVotingEscrow public constant votingEscrow = IVotingEscrow(0xf17d23136B4FeAd139f54fB766c8795faae09660);
    IOptionsToken public constant optionsToken = IOptionsToken(0x627fee87d0D9D2c55098A06ac805Db8F98B158Aa);
    IBalancerVault public constant BALANCER_VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    bytes32 public constant LIT_WETH_POOL_ID = 0x9232a548dd9e81bac65500b5e0d918f8ba93675c000200000000000000000423;
    ERC20 public immutable LIT_WETH_BPT;
    IBalancerOracle public immutable oracle;
    ERC20 public immutable paymentToken; // WETH
    ERC20 public immutable underlyingToken; // LIT

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    ILockDiscountConfig public lockDiscountConfig;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(ILockDiscountConfig lockDiscountConfig_, address owner_) Owned(owner_) {
        oracle = optionsToken.oracle();
        paymentToken = optionsToken.paymentToken();
        underlyingToken = optionsToken.underlyingToken();
        LIT_WETH_BPT = ERC20(oracle.balancerTwapOracle());

        lockDiscountConfig = lockDiscountConfig_;

        // set approvals
        paymentToken.approve(address(optionsToken), type(uint256).max);
        paymentToken.approve(address(BALANCER_VAULT), type(uint256).max);
        underlyingToken.approve(address(BALANCER_VAULT), type(uint256).max);
    }

    /// -----------------------------------------------------------------------
    /// External functions
    /// -----------------------------------------------------------------------

    function exerciseAndLock(
        uint256 amount,
        uint256 maxPaymentAmount,
        uint256 maxBptPairWethAmount,
        uint256 minBptAmountOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 paymentAmount, uint256 bptPairWethAmount, uint256 bptLocked) {
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

        // query recipient's BPT approval to votingEscrow
        // necessary for votingEscrow.deposit_for()
        uint256 lockTokenAllowance = LIT_WETH_BPT.allowance(recipient, address(votingEscrow));
        if (lockTokenAllowance < amount) {
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

        // transfer payment tokens (WETH) from user
        uint256 oraclePrice = oracle.getPrice();
        paymentAmount = amount.mulWadUp(oraclePrice);
        uint256 wethPerLit = oraclePrice.mulDivDown(1e4, adjustedMultiplier);
        bptPairWethAmount = amount.mulDivDown(wethPerLit, 4e18); // 80-20 pool so div by 4
        if (bptPairWethAmount > maxBptPairWethAmount) {
            revert ExerciseLocker__BptPairWethAmountTooHigh();
        }
        paymentToken.transferFrom(msg.sender, address(this), paymentAmount + bptPairWethAmount);

        // exercise oLIT to get LIT
        optionsToken.exercise(amount, maxPaymentAmount, address(this), deadline);

        // revert to previous oracle multiplier
        oracle.setParams(oracleMultiplier, oracleSecs, oracleAgo, oracleMinPrice);

        // combine LIT and WETH into Balancer LP token
        uint256 beforeBptBalance = LIT_WETH_BPT.balanceOf(recipient);
        _joinBalancerPool(amount, bptPairWethAmount, minBptAmountOut, recipient);

        // lock LIT BLP in votingEscrow
        bptLocked = LIT_WETH_BPT.balanceOf(recipient) - beforeBptBalance;
        votingEscrow.deposit_for(recipient, bptLocked);
    }

    /// -----------------------------------------------------------------------
    /// Owner functions
    /// -----------------------------------------------------------------------

    function setOracleOwner(address newOwner) external onlyOwner {
        oracle.transferOwnership(newOwner);
    }

    function setOracleParams(uint16 multiplier, uint56 secs, uint56 ago, uint128 minPrice) external onlyOwner {
        oracle.setParams(multiplier, secs, ago, minPrice);
    }

    function setLockDiscountConfig(ILockDiscountConfig newLockDiscountConfig) external onlyOwner {
        lockDiscountConfig = newLockDiscountConfig;
    }

    /// -----------------------------------------------------------------------
    /// Internal helpers
    /// -----------------------------------------------------------------------

    function _joinBalancerPool(
        uint256 underlyingTokenAmount,
        uint256 paymentTokenAmount,
        uint256 _minAmountOut,
        address recipient
    ) internal {
        IAsset[] memory assets = new IAsset[](2);
        assets[0] = IAsset(address(paymentToken));
        assets[1] = IAsset(address(underlyingToken));
        uint256[] memory maxAmountsIn = new uint256[](2);
        maxAmountsIn[0] = paymentTokenAmount;
        maxAmountsIn[1] = underlyingTokenAmount;

        BALANCER_VAULT.joinPool(
            LIT_WETH_POOL_ID,
            address(this),
            recipient,
            IBalancerVault.JoinPoolRequest(
                assets,
                maxAmountsIn,
                abi.encode(IBalancerVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, _minAmountOut),
                false // Don't use internal balances
            )
        );
    }
}
