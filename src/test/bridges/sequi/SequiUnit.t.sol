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

// @notice The purpose of this test is to directly test convert functionality of the bridge.
contract SequiUnitTest is BridgeTestBase {
    address private constant CREATOR = address(0xb0b);
    uint256 private constant MIN_DONATION = .001 ether;
    uint64 private creatorId;

    address private rollupProcessor;
    // The reference to the example bridge
    SequiBridge private bridge;

    AztecTypes.AztecAsset private ethAsset;
    // The receipt token
    AztecTypes.AztecAsset private receiptAsset;

    // @dev This method exists on RollupProcessor.sol. It's defined here in order to be able to receive ETH like a real
    //      rollup processor would.
    function receiveEthFromBridge(uint256 _interactionNonce) external payable {}

    function setUp() public {
        // Deploy a new example bridge
        bridge = new SequiBridge(rollupProcessor);

        vm.prank(CREATOR);
        vm.label(CREATOR, "Creator");
        creatorId = bridge.createAccount(MIN_DONATION);

        vm.deal(address(bridge), 0);
        vm.label(address(bridge), "Example Bridge");

        // Subsidize the bridge when used with Dai and register a beneficiary
        ethAsset = getRealAztecAsset(address(0));
        receiptAsset = AztecTypes.AztecAsset({
            id: 1,
            erc20Address: address(0),
            assetType: AztecTypes.AztecAssetType.VIRTUAL
        });

        rollupProcessor = address(this);
    }

    function testInvalidCaller(address _callerAddress) public {
        vm.assume(_callerAddress != rollupProcessor);
        // Use HEVM cheatcode to call from a different address than is address(this)
        vm.prank(_callerAddress);
        vm.expectRevert(ErrorLib.InvalidCaller.selector);
        bridge.convert(emptyAsset, emptyAsset, emptyAsset, emptyAsset, 0, 0, creatorId, address(0));
    }

    function testInvalidInputAssetType() public {
        vm.expectRevert(ErrorLib.InvalidInputA.selector);
        bridge.convert(emptyAsset, emptyAsset, receiptAsset, emptyAsset, 0, 0, creatorId, address(0));
    }

    function testInvalidOutputAssetType() public {
        vm.expectRevert(ErrorLib.InvalidOutputA.selector);
        bridge.convert(ethAsset, emptyAsset, emptyAsset, emptyAsset, 0, 0, creatorId, address(0));
    }

    function testDonateEth() public {
        vm.warp(block.timestamp + 1 days);

        deal(address(bridge), MIN_DONATION);

        uint256 creatorBalanceBefore = CREATOR.balance;

        (uint256 outputValueA, uint256 outputValueB, bool isAsync) = bridge.convert(
            ethAsset,
            emptyAsset, // _inputAssetB - not used so can be left empty
            receiptAsset, // _outputAssetA - in this example equal to input asset
            emptyAsset, // _outputAssetB - not used so can be left empty
            MIN_DONATION, // _totalInputValue - an amount of input asset A sent to the bridge
            0, // _interactionNonce
            creatorId, // _auxData - not used in the example bridge
            address(0) // _rollupBeneficiary - address, the subsidy will be sent to
        );

        assertEq(CREATOR.balance, creatorBalanceBefore + MIN_DONATION);
        assertEq(outputValueA, 1); // 1 receipt token

        // Now we transfer the funds back from the bridge to the rollup processor
        // In this case input asset equals output asset so I only work with the input asset definition
        // Basically in all the real world use-cases output assets would differ from input assets
        // IERC20(inputAssetA.erc20Address).transferFrom(address(bridge), rollupProcessor, outputValueA);

        // assertEq(outputValueA, _depositAmount, "Output value A doesn't equal deposit amount");
        // assertEq(outputValueB, 0, "Output value B is not 0");
        // assertTrue(!isAsync, "Bridge is incorrectly in an async mode");

        // uint256 daiBalanceAfter = IERC20(DAI).balanceOf(rollupProcessor);

        // assertEq(daiBalanceAfter - daiBalanceBefore, _depositAmount, "Balances must match");

        // SUBSIDY.withdraw(BENEFICIARY);
        // assertGt(BENEFICIARY.balance, 0, "Subsidy was not claimed");
    }
}
