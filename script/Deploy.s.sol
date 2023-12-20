// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {ExerciseLocker} from "../src/ExerciseLocker.sol";
import {SimpleDiscountConfig} from "../src/SimpleDiscountConfig.sol";

contract DeployScript is CREATE3Script {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (ExerciseLocker locker, SimpleDiscountConfig discountConfig) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address owner = vm.envAddress("OWNER");

        vm.startBroadcast(deployerPrivateKey);

        discountConfig = new SimpleDiscountConfig();

        locker = ExerciseLocker(
            create3.deploy(
                getCreate3ContractSalt("ExerciseLocker"),
                bytes.concat(type(ExerciseLocker).creationCode, abi.encode(discountConfig, owner))
            )
        );

        vm.stopBroadcast();
    }
}
