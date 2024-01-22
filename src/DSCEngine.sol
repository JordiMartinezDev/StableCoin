// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 * @author Patrick Collins - Jordi Martinez Following Patrick's Youtube course
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 tokken = 1 USD
 *
 * This stablecoin has the properties:
 * -Exogenous Collateral
 * -Dollar pegged
 * -Algorithmically stable
 *
 * Similar to DAI, if DAI had no governance, no fees and was only backed by wETH and wBTC
 *
 * This DSC system should always be "overcollaterized". At no point, should the value of all collateral <= the $ backed value of all the DSC
 *
 * @notice This contract is the core of the DSC system. It handles all the logic for mining and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is VERY loosely based on the MakerDAO DSS (DAI) system.
 */
contract DSCEngine is ReentrancyGuard {
    // ---------- Errors ---------- //

    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();

    // ---------- State variables ---------- //

    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    mapping(address token => address priceFeed) private s_priceFeeds; // TokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCminted;
    address[] private s_collateralTokens;


    DecentralizedStableCoin private immutable i_dsc;


    // ---------- Events ---------- //

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

    // ---------- Modifiers ---------- //

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) revert DSCEngine__NeedsMoreThanZero();

        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    // ---------- Functions ---------- //

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedMustBeSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    // ---------- External Functions ---------- //

    function depositCollateralAndMintDSC() external {}

    /**
     * @notice follows CEI ( checks, effects, interactions )
     * @param tokenCollateralAddress The address of the token to deposit collateral
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;

        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);

        if (!success) revert DSCEngine__TransferFailed();
    }

    function redeemCollateralForDSC() external {}

    function redeemCollateral() external {}

    /**
     * @notice follows CEI
     * @param amountDscToMint The amount of stableCoin to mint
     * @notice They must have more collateral than minimum threshold
     */

    // 1. Check if the collateral value > DSC amount
    function mintDSC(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant{
        s_DSCminted[msg.sender] += amountDscToMint;
        //if they minted too much
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);

        if(!minted) revert DSCEngine__MintFailed();
    }

    function burnDSC() external {}

    function liquidate() external {}

    function getHealthFactor() external {}

    // ---------- Private & Internal View Functions ---------- //

    function _getAccountInformation(address user) private view returns(uint256 totalDscMinted, uint256 collateralValueInUsd){

        totalDscMinted = s_DSCminted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * Returns how close to liquidation a user is
     * If user goes below 1, they can get liquidated
     * @param user TestParam
     *
     */

    function _healthFactor(address user) private view returns(uint256){

            (uint256 totalDscMinted,uint256 collateralValueInUsd) = _getAccountInformation(user);
            uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / 100;
            return collateralAdjustedForThreshold * 1e18 / totalDscMinted;   

    }

    // 1. Check the health factor ( do they have enough collateral ? )
    // 2. Revert if they don't
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if(userHealthFactor < MIN_HEALTH_FACTOR){
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    // ---------- Public & External View Functions ---------- //

    function getAccountCollateralValue(address user) public view returns(uint256 totalCollateralValueInUsd){
        // loop through each collateral token, get the amount they have deposited 
        // map it to the price to get value in USD

        for(uint256 i; i < s_collateralTokens.length; i++){
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];

            // We need the amount to be calculated in USD now

            totalCollateralValueInUsd += getUsdValue(token, amount); 

        }
    }


        function getUsdValue(address token,uint256 amount) public view returns(uint256){

            AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
            (, int256 price,,,) = priceFeed.latestRoundData();
            // Times 1e10 because amount is in 1e18 and priceFeed in 1e8, so we need to convert everything to 1e18
            // This is detailed in chainlink priceFeed docs, in ETH / USD details

            return ((uint256(price) * 1e10) * amount) / 1e18; 
        }
    

}
