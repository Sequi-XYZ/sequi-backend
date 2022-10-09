// SPDX-License-Identifier: Apache-2.0
// Copyright 2022 Aztec.
pragma solidity >=0.8.4;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AztecTypes} from "../../aztec/libraries/AztecTypes.sol";
import {BridgeBase} from "../base/BridgeBase.sol";
import {ErrorLib} from "../base/ErrorLib.sol";
import {console} from "forge-std/console.sol";

/**
 * @author @Carla1nf
 */
contract SequiBridge is BridgeBase {
    using SafeERC20 for IERC20;

    error InvalidDoneeAddress();
    error EthTransferFailed();

    // event ListedDonee(address donee, uint64 index);
    event CreatorCreated(address newCreator, uint256 amount);

    // Starts at 1 to revert if users forget to provide auxdata.
    uint64 public creatorID;

    /* STRUCT */

    struct CreatorInfo {
        address addr;
        uint256 paymentAmount;
    }

    /* MAPPING */
    mapping(uint64 => CreatorInfo) public creators;

    constructor(address _rollupProcessor) BridgeBase(_rollupProcessor) {}

    /* Create Struct */
    function createAccount(uint256 amount) public returns (uint64) {
        uint64 creator = ++creatorID;
        creators[creator] = CreatorInfo({addr: msg.sender, paymentAmount: amount});

        emit CreatorCreated(msg.sender, amount);
        return creator;
    }

    /**
     * @notice Transfers `_inputAssetA` to `donees[_auxData]`
     * @param _inputAssetA The asset to donate
     * @param _totalInputValue The amount to donate
     * @param _auxData The id of the donee
     */
    function convert(
        AztecTypes.AztecAsset calldata _inputAssetA,
        AztecTypes.AztecAsset calldata,
        AztecTypes.AztecAsset calldata _outputAssetA,
        AztecTypes.AztecAsset calldata,
        uint256 _totalInputValue,
        uint256,
        uint64 _auxData,
        address
    )
        external
        payable
        override(BridgeBase)
        onlyRollup
        returns (
            uint256,
            uint256,
            bool
        )
    {
        CreatorInfo memory receiver = creators[_auxData];

        // // Invalid Amount
        // if (_totalInputValue < receiver.paymentAmount) {
        //     revert ErrorLib.InvalidAuxData();
        // }

        // make sure eth was donated
        if (_inputAssetA.assetType != AztecTypes.AztecAssetType.ETH) revert ErrorLib.InvalidInputA();

        // make sure the output is the virtual token
        if (_outputAssetA.assetType != AztecTypes.AztecAssetType.VIRTUAL) revert ErrorLib.InvalidOutputA();

        uint256 amountOut = _totalInputValue / receiver.paymentAmount;

        if (_inputAssetA.assetType == AztecTypes.AztecAssetType.ETH) {
            //solhint-disable-next-line
            (bool success, ) = payable(receiver.addr).call{gas: 30000, value: _totalInputValue}("");
            if (!success) revert EthTransferFailed();
        } else {
            revert ErrorLib.InvalidInputA();
        }

        return (amountOut, 0, false);
    }
}
