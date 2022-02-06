// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Lossless.sol";
import "../interfaces/IManager.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IERC20.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

/** @title AaveLosslessV2
 *  @dev This contract implement is a lossless betting contracts for football 1X2
 * Contract has an owner who is the manager contract that deploys it.
 * Process : - Manager creates contract.
 *           - Contract can also be sponsored : someone deposit without participating in betting.
 * Weth-Mainnet : 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
 * aWeth-Mainnet : 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e
 * WMatic-Mumbai : 0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889
 * aMatic-Mumbai : 0xF45444171435d0aCB08a8af493837eF18e86EE27
 * Contracts adresses : See  addresses here 'https://docs.aave.com/developers/v/2.0/deployed-contracts'
 */
contract AaveLossless is VRFConsumerBase, Lossless {
    bytes32 internal keyHash =
        0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445;
    uint256 internal fee = 2 * 10**18;
    uint256 public randomResult;
    /// token used to bet
    address public winner;
    /// amount of deposit by sponsors
    uint256 public sponsorDeposit;
    /// team winning
    BetSide public winningSide;
    ///  QiAvax interface to interact with QiAvax contract
    ILendingPool public lendingPool;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    //address weth = 0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889; MUMBAI
    IERC20 AWETH = IERC20(0x030bA81f1c18d280636F32af80b9AAd02Cf0854e);
    //IERC20 AWETH = IERC20(0xF45444171435d0aCB08a8af493837eF18e86EE27); Mumbai

    enum BetSide {
        OPEN,
        HOME,
        DRAW,
        AWAY
    }
    /**
     * @dev Throws if betside is not valid
     */
    modifier correctBet(uint256 betSide) {
        require(
            betSide == 1 || betSide == 2 || betSide == 3,
            "invalid argument for bestide"
        );
        _;
    }

    /**
     * @dev Initialize the contract settings : matchStartTime, matchFinishTime, QiAvax address .
     */
    constructor(
        address _lendingPool,
        uint256 _matchStartTime,
        uint256 _matchFinishTime
    )
        VRFConsumerBase(
            0xf0d54349aDdcf704F77AE15b96510dEA15cb7952, // VRF
            0x514910771AF9Ca656af840dff83E8264EcF986CA // Link
        )
        Lossless(_matchStartTime, _matchFinishTime)
    {
        status = MatchStatus.OPEN;
        lendingPool = ILendingPool(_lendingPool);
        winningSide = BetSide.OPEN;
        winner = address(0);
    }

    /**
     * @dev Sponsor the contract, funds received will be used to generate yield.
     */
    function sponsor(uint256 amount, address player)
        external
        /*isOpen*/
        onlyOwner
    {
        require(amount > 0, "amount must be positif");
        totalDeposits += amount;
        sponsorDeposit += amount;
        playerBalance[player] += amount;
    }

    /**
     * @dev Places the bet.
     */
    function placeBet(
        address player,
        uint256 amount,
        uint256 betSide
    )
        external
        onlyOwner /*isOpen correctBet(betSide)*/
    {
        require(amount > 0, "amount must be positif");
        if (betSide == 1) {
            placeHomeBet(player, amount);
        } else if (betSide == 3) {
            placeAwayBet(player, amount);
        } else if (betSide == 2) {
            placeDrawBet(player, amount);
        }
        totalDeposits += amount;
        playerBalance[player] += amount;
    }

    /**
     * @dev can be called by manager to settle game and set winner .
     */
    function setMatchWinner(uint256 _winningSide)
        external
        onlyOwner
    /*correctBet(_winningSide)*/
    {
        require(status == MatchStatus.OPEN, "Cant settle this match");
        status = MatchStatus.PAID;
        winningSide = _winningSide == 1 ? BetSide.HOME : _winningSide == 2
            ? BetSide.DRAW
            : BetSide.AWAY;
        uint256 contractBalance = AWETH.balanceOf(address(this));
        lendingPool.withdraw(weth, type(uint256).max, owner());
        getRandomNumber();
        //findWinner();
        //payoutWinner();
    }

    /**
     * @dev Internal function to find the winnner of the lottery.
     */
    function findWinner(uint256 _random) internal {
        if (winningSide == BetSide.HOME) {
            winner = findHomeWinner(_random);
        } else if (winningSide == BetSide.AWAY) {
            winner = findAwayWinner(_random);
        } else if (winningSide == BetSide.DRAW) {
            winner = findDrawWinner(_random);
        }
    }

    /* Requests randomness
     */
    function getRandomNumber() public returns (bytes32 requestId) {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK - fill contract with faucet"
        );
        return requestRandomness(keyHash, fee);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        randomResult = randomness;
        findWinner(randomResult);
        IManager(owner()).payWinner();
    }
}
