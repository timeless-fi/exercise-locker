// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "forge-std/Test.sol";

import {ExerciseLocker} from "../src/ExerciseLocker.sol";
import {IVotingEscrow} from "../src/external/IVotingEscrow.sol";
import {IOptionsToken} from "../src/external/IOptionsToken.sol";
import {SimpleDiscountConfig} from "../src/SimpleDiscountConfig.sol";
import {ISmartWalletChecker} from "../src/external/ISmartWalletChecker.sol";

contract ExerciseLockerTest is Test {
    ExerciseLocker public locker;
    SimpleDiscountConfig public discountConfig;

    address internal user;

    function setUp() public {
        user = makeAccount("user").addr;

        discountConfig = new SimpleDiscountConfig();
        locker = new ExerciseLocker(discountConfig, address(this));

        // set token approvals
        vm.startPrank(user);
        locker.optionsToken().approve(address(locker), type(uint256).max);
        locker.paymentToken().approve(address(locker), type(uint256).max);
        locker.LIT_WETH_BPT().approve(address(locker.votingEscrow()), type(uint256).max);
        vm.stopPrank();

        // deal some oLIT, WETH, BPT to user
        deal(address(locker.optionsToken()), user, 1000 ether);
        deal(address(locker.paymentToken()), user, 1000 ether);
        deal(address(locker.LIT_WETH_BPT()), user, 1000 ether);

        // whitelist user for voting escrow
        address owner = ISmartWalletChecker(locker.votingEscrow().smart_wallet_checker()).owner();
        vm.startPrank(owner);
        ISmartWalletChecker(locker.votingEscrow().smart_wallet_checker()).allowlistAddress(user);
        vm.stopPrank();

        // transfer ownership of balancer oracle to locker
        vm.startPrank(address(locker.oracle().owner()));
        locker.oracle().transferOwnership(address(locker));
        vm.stopPrank();
    }

    function test_exerciseAndLock() public {
        vm.startPrank(user);

        // lock some BPT
        uint256 initialLockAmount = 1000 ether;
        locker.votingEscrow().create_lock(initialLockAmount, block.timestamp + 4 * 365 days);

        // exercise 100 oLIT
        (uint256 paymentAmount, uint256 bptPairWethAmount, uint256 bptLocked) = locker.exerciseAndLock({
            amount: 100 ether,
            maxPaymentAmount: 1000 ether,
            maxBptPairWethAmount: 1000 ether,
            minBptAmountOut: 0,
            recipient: user,
            deadline: block.timestamp + 1 days
        });

        vm.stopPrank();

        // check payment amount
        assertGt(paymentAmount, 0, "didn't pay anything");
        assertLe(paymentAmount, 1000 ether, "paid too much");

        // check bpt locked
        IVotingEscrow.LockedBalance memory lockedBalance = locker.votingEscrow().locked(user);
        assertGt(bptLocked, 0, "BPT locked was zero");
        assertEq(uint128(lockedBalance.amount), bptLocked + initialLockAmount, "didn't get locked balance");
    }
}
