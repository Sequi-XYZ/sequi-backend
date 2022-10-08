// SPDX-License-Identifier: Apache-2.0
// Copyright 2022 Aztec.
pragma solidity >=0.8.4;

import {BridgeTestBase} from "./../../aztec/base/BridgeTestBase.sol";
import {AztecTypes} from "../../../aztec/libraries/AztecTypes.sol";

// Example-specific imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SequiBridge} from "../../../bridges/sequi/SequiBridge.sol";
import {ErrorLib} from "../../../bridges/base/ErrorLib.sol";
import {console} from "forge-std/console.sol";

contract SequiE2ETest is BridgeTestBase {
    address private constant CREATOR = address(0xb0b);
    uint256 private constant MIN_DONATION = .001 ether;
    uint64 private creatorId;

    // The reference to the example bridge
    SequiBridge private bridge;
    // To store the id of the example bridge after being added
    uint256 private bridgeAddressId;

    AztecTypes.AztecAsset private ethAsset;
    // The receipt token
    AztecTypes.AztecAsset private receiptAsset;

    receive() external payable {
        console.log("received eth");
    }

    function setUp() public {
        bridge = new SequiBridge(address(ROLLUP_PROCESSOR));

        vm.prank(CREATOR);
        vm.label(CREATOR, "Creator");
        creatorId = bridge.createAccount(MIN_DONATION);

        vm.deal(address(bridge), 0);
        vm.label(address(bridge), "Example Bridge");

        ethAsset = getRealAztecAsset(address(0));
        receiptAsset = AztecTypes.AztecAsset({
            id: 1,
            erc20Address: address(0),
            assetType: AztecTypes.AztecAssetType.VIRTUAL
        });

        vm.prank(MULTI_SIG);
        ROLLUP_PROCESSOR.setSupportedBridge(address(bridge), 1_000_000);
        bridgeAddressId = ROLLUP_PROCESSOR.getSupportedBridgesLength();
    }

    function testDonateEth() public {
        vm.warp(block.timestamp + 1 days);

        vm.deal(address(ROLLUP_PROCESSOR), 1000 ether);

        uint256 creatorBalanceBefore = CREATOR.balance;

        uint256 bridgeCallData = encodeBridgeCallData({
            _bridgeAddressId: bridgeAddressId,
            _inputAssetA: ethAsset, // eth in
            _inputAssetB: emptyAsset, //empty
            _outputAssetA: receiptAsset, // receipt out
            _outputAssetB: emptyAsset, //empty
            _auxData: creatorId
        });

        // vm.expectEmit(true, true, false, true);
        // emit DefiBridgeProcessed(bridgeCallData, getNextNonce(), MIN_DONATION, 0, 0, true, "");

        sendDefiRollup(bridgeCallData, MIN_DONATION);
        assertEq(CREATOR.balance, creatorBalanceBefore + MIN_DONATION, "did not receive");
    }
}
