// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.11;
pragma abicoder v2;

interface ISmartWalletChecker {
    function allowlistAddress(address contractAddress) external;
    function owner() external view returns (address);
}
