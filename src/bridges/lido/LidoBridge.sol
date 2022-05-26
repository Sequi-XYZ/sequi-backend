// SPDX-License-Identifier: GPLv2

pragma solidity >=0.6.10 <=0.8.10;
pragma experimental ABIEncoderV2;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDefiBridge} from "../../interfaces/IDefiBridge.sol";
import {AztecTypes} from "../../aztec/AztecTypes.sol";

interface ICurvePool {
    function coins(uint256) external view returns(address);

    function get_dy(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external payable returns (uint256);
}

interface ILido is IERC20 {
    function submit(address _referral) external payable returns (uint256);
}

interface ILidoOracle {
    function getLastCompletedReportDelta() external view returns (uint256 postTotalPooledEther, uint256 preTotalPooledEther, uint256 timeElapsed);
}

interface IWstETH is IERC20{
    function wrap(uint256 _stETHAmount) external returns (uint256);
    function unwrap(uint256 _wstETHAmount) external returns (uint256);
    function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256);
    function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256);
}

interface IRollupProcessor {
    function receiveEthFromBridge(uint256 interactionNonce) external payable;
}

contract LidoBridge is IDefiBridge {
    using SafeERC20 for IERC20;
    using SafeERC20 for ILido;
    using SafeERC20 for IWstETH;

    address public immutable rollupProcessor;
    address public immutable referral;

    ILido public constant lido = ILido(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IWstETH public constant wrappedStETH = IWstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    ICurvePool public constant curvePool = ICurvePool(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);

    int128 private constant curveETHIndex = 0;
    int128 private constant curveStETHIndex = 1;

    constructor(address _rollupProcessor, address _referral) {
        require(curvePool.coins(uint256(uint128(curveStETHIndex))) == address(lido), 'LidoBridge: Invalid configuration');

        rollupProcessor = _rollupProcessor;
        referral = _referral;

        // As the contract is not supposed to hold any funds, we can pre-approve 
        lido.safeIncreaseAllowance(address(wrappedStETH), type(uint256).max);
        lido.safeIncreaseAllowance(address(curvePool), type(uint256).max);
        wrappedStETH.safeIncreaseAllowance(rollupProcessor, type(uint256).max);
    }

    receive() external payable {}

    function convert(
        AztecTypes.AztecAsset calldata inputAssetA,
        AztecTypes.AztecAsset calldata,
        AztecTypes.AztecAsset calldata outputAssetA,
        AztecTypes.AztecAsset calldata,
        uint256 inputValue,
        uint256 interactionNonce,
        uint64,
        address
    )
        external
        payable
        returns (
            uint256 outputValueA,
            uint256,
            bool isAsync
        )
    {
        require(msg.sender == rollupProcessor, "LidoBridge: Invalid Caller");

        bool isETHInput = inputAssetA.assetType == AztecTypes.AztecAssetType.ETH;
        bool isWstETHInput = inputAssetA.assetType == AztecTypes.AztecAssetType.ERC20 && inputAssetA.erc20Address == address(wrappedStETH);

        require(isETHInput || isWstETHInput, "LidoBridge: Invalid Input");

        isAsync = false;
        outputValueA = isETHInput ? wrapETH(inputValue, outputAssetA) : unwrapETH(inputValue, outputAssetA, interactionNonce);
    }

    /**
        Convert ETH -> wstETH
     */
    function wrapETH(uint256 inputValue, AztecTypes.AztecAsset calldata outputAsset) private returns (uint256 outputValue) {
        require(
            outputAsset.assetType == AztecTypes.AztecAssetType.ERC20 && outputAsset.erc20Address == address(wrappedStETH),
            "LidoBridge: Invalid Output Token"
        );

        // deposit into lido (return value is shares NOT stETH)
        lido.submit{value: inputValue}(referral);

        // since stETH is a rebase token, lets wrap it to wstETH before sending it back to the rollupProcessor
        uint256 outputStETHBalance = lido.balanceOf(address(this));

        // Lido balance can be <=2 wei off, 1 from the submit where our shares is computed rounding down, 
        // and then again when the balance is computed from the shares, rounding down again. 
        require(outputStETHBalance + 2 >= inputValue, 'LidoBridge: Invalid wrap return value');

        outputValue = wrappedStETH.wrap(outputStETHBalance);
    }

    /**
        Convert wstETH to ETH
     */
    function unwrapETH(uint256 inputValue, AztecTypes.AztecAsset calldata outputAsset, uint256 interactionNonce) private returns (uint256 outputValue) {
        require(outputAsset.assetType == AztecTypes.AztecAssetType.ETH, "LidoBridge: Invalid Output Token");

        // Convert wstETH to stETH so we can exchange it on curve
        uint256 stETH = wrappedStETH.unwrap(inputValue);

        // Exchange stETH to ETH via curve
        uint256 dy = curvePool.exchange(curveStETHIndex, curveETHIndex, stETH, 0);

        outputValue = address(this).balance;
        require(outputValue >= dy, 'LidoBridge: Invalid unwrap return value');

        // Send ETH to rollup processor
        IRollupProcessor(rollupProcessor).receiveEthFromBridge{value: outputValue}(interactionNonce);
    }

  function finalise(
    AztecTypes.AztecAsset calldata,
    AztecTypes.AztecAsset calldata,
    AztecTypes.AztecAsset calldata,
    AztecTypes.AztecAsset calldata,
    uint256,
    uint64
  ) external payable returns (uint256, uint256, bool) {
    require(false);
  }
}
