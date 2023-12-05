// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {ExerciseLocker} from "../src/ExerciseLocker.sol";

contract DeployScript is CREATE3Script {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (ExerciseLocker locker) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address votingEscrow = vm.envAddress("VOTING_ESCROW");
        address optionsToken = vm.envAddress("OPTIONS_TOKEN");
        address oracle = vm.envAddress("ORACLE");
        address owner = vm.envAddress("OWNER");

        vm.startBroadcast(deployerPrivateKey);

        locker = ExerciseLocker(
            create3.deploy(
                getCreate3ContractSalt("ExerciseLocker"),
                bytes.concat(type(ExerciseLocker).creationCode, abi.encode(votingEscrow, optionsToken, oracle, owner))
            )
        );

        vm.stopBroadcast();
    }
}
