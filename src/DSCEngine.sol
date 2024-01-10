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

contract DSCEngine{

    constructor(){

    }
    
}