// SPDX-License-Identifier: Apache-2.0
// Copyright 2022 Aztec.
pragma solidity >=0.8.4;

import {BaseDeployment} from "../base/BaseDeployment.s.sol";
import {SequiBridge} from "../../bridges/sequi/SequiBridge.sol";

contract SequiDeployment is BaseDeployment {
    function deploy() public returns (address) {
        uint256 DEFAULT_AMOUNT = 0.01 ether;
        emit log("Deploying...");

        vm.startBroadcast();
        SequiBridge bridge = new SequiBridge(ROLLUP_PROCESSOR);
        uint256 id = bridge.createAccount(DEFAULT_AMOUNT);
        vm.stopBroadcast();

        emit log_named_address("Example bridge deployed to", address(bridge));
        emit log_named_uint("Account id is", id);
        (address addr, ) = bridge.creators(uint64(id));
        emit log_named_address("with an address of", addr);

        return address(bridge);
    }

    function deployAndList() public {
        address bridge = deploy();
        uint256 addressId = listBridge(bridge, 1_000_000);
        emit log_named_uint("Example bridge address id", addressId);
    }
}
