// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/** @title LosslessV2
 *  @dev This contract  is a boilerplate for lossless betting contracts for football 1X2.
 * Contract has an owner to settle the bet, to be replaced by Chainlink.
 * Process : - Owner creates contract, sets matchStartTime and matchFinishTime : Players can place bets before matchStartTime
 * and owner can settle the game after matchFinishTime.
 *           - Before matchStartTime player can pick a side ( Home, Draw, Away), choose an amount and place a bet.
 *           - After placing a bet the player win points proportional to the 'amount' and 'time remaining before matchStartTime'.
 *           - The chance of winning for the player is proportional to his points.
 *           - The money deposited for bets is then lent to a protocol and earns yield.
 *           - After game is finished and owner sets winning team, contract pick randomly a winner who bet on the right side.
 *           - Winner wins the yield generated, and other players are refunded.
 */

contract Lossless is Ownable {
    MatchStatus public status;
    /// block at which game is supposed to start
    uint256 public matchStartTime;
    /// block after which game should have ended
    uint256 public matchFinishTime;
    /// total amount deposited in the contract
    uint256 public totalDeposits;
    /// total points earned by players betting home
    uint256 public homePointsTrackers;
    /// total points earned by players betting draw
    uint256 public drawPointsTrackers;
    /// total points earned by players betting away
    uint256 public awayPointsTrackers;
    /// number of home bets
    uint256 public homeBets;
    /// number of draw bets
    uint256 public drawBets;
    /// number of away bets
    uint256 public awayBets;
    /// tracks total points earned by player betting home after bet number i, used for computing winner
    uint256[] public homePointsAfterBet;
    /// tracks total points earned by player betting draw after bet number i, used for computing winner
    uint256[] public drawPointsAfterBet;
    /// tracks total points earned by player betting away after bet number i, used for computing winner
    uint256[] public awayPointsAfterBet;
    /// tracks which player placed home bet number i
    mapping(uint256 => address) public homeBetPlacer;
    /// tracks which player placed draw bet number i
    mapping(uint256 => address) public drawBetPlacer;
    /// tracks which player placed away bet number i
    mapping(uint256 => address) public awayBetPlacer;
    /// tracks players deposits
    mapping(address => uint256) public playerBalance;
    /// tracks players home points
    mapping(address => uint256) public playerHomePoints;
    /// tracks players draw points
    mapping(address => uint256) public playerDrawPoints;
    /// tracks players away points
    mapping(address => uint256) public playerAwayPoints;
    enum MatchStatus {
        OPEN,
        PAID
    }

    /**
     * @dev Throws if called after game started
     */
    modifier isOpen() {
        require(status == MatchStatus.OPEN, "Match not open");
        require(block.timestamp < matchStartTime, "Cant place bet now");
        _;
    }

    /**
     * @dev Throws if called before game is Finished
     */

    modifier isFinished() {
        require(block.timestamp > matchFinishTime, "Game is finished");
        _;
    }

    /**
     * @dev Throws if called after game is Paid
     */
    modifier isPaid() {
        require(status == MatchStatus.PAID, "Match not paid");
        _;
    }

    /**
     * @dev Initialize the contract settings : matchStartBlock and matchFinishBlock.
     */
    constructor(uint256 _matchStartTime, uint256 _matchFinishTime) {
        status = MatchStatus.OPEN;
        matchStartTime = _matchStartTime;
        matchFinishTime = _matchFinishTime;
    }

    /**
     * @dev Places home bet.
     */
    function placeHomeBet(address player, uint256 amount) internal {
        uint256 currentTime = block.timestamp;
        uint256 points = amount * (matchStartTime - currentTime);
        playerHomePoints[player] += points;
        homePointsTrackers += points;
        homePointsAfterBet.push(homePointsTrackers);
        homeBetPlacer[homeBets] = player;
        homeBets += 1;
    }

    /**
     * @dev Places draw bet.
     */
    function placeDrawBet(address player, uint256 amount) internal {
        uint256 currentTime = block.timestamp;
        uint256 points = amount * (matchStartTime - currentTime);
        playerDrawPoints[player] += points;
        drawPointsTrackers += points;
        drawPointsAfterBet.push(drawPointsTrackers);
        drawBetPlacer[homeBets] = player;
        drawBets += 1;
    }

    /**
     * @dev Places away bet.
     */
    function placeAwayBet(address player, uint256 amount) internal {
        uint256 currentTime = block.timestamp;
        uint256 points = amount * (matchStartTime - currentTime);
        playerAwayPoints[player] += points;
        awayPointsTrackers += points;
        awayPointsAfterBet.push(awayPointsTrackers);
        awayBetPlacer[awayBets] = player;
        awayBets += 1;
    }

    /**
     * @dev Find home winner.
     */
    function findHomeWinner(uint256 random) internal returns (address) {
        //uint256 random = _random();
        random = random % homePointsTrackers;

        if (random < homePointsAfterBet[0]) {
            return homeBetPlacer[0];
        }

        uint256 hi = homePointsAfterBet.length - 1;
        uint256 lo = 0;

        while (lo <= hi) {
            uint256 mid = lo + (hi - lo) / 2;
            if (random < homePointsAfterBet[mid]) {
                hi = mid - 1;
            } else if (random > homePointsAfterBet[mid]) {
                lo = mid + 1;
            } else {
                return homeBetPlacer[mid + 1];
            }
        }
        return homeBetPlacer[lo];
    }

    /**
     * @dev Find Draw winner.
     */
    function findDrawWinner(uint256 random) internal returns (address) {
        //uint256 random = _random();
        random = random % drawPointsTrackers;

        if (random < drawPointsAfterBet[0]) {
            return drawBetPlacer[0];
        }

        uint256 hi = drawPointsAfterBet.length - 1;
        uint256 lo = 0;

        while (lo <= hi) {
            uint256 mid = lo + (hi - lo) / 2;
            if (random < drawPointsAfterBet[mid]) {
                hi = mid - 1;
            } else if (random > drawPointsAfterBet[mid]) {
                lo = mid + 1;
            } else {
                return drawBetPlacer[mid + 1];
            }
        }
        return drawBetPlacer[lo];
    }

    /**
     * @dev Find away winner.
     */
    function findAwayWinner(uint256 random) internal returns (address) {
        // uint256 random = _random();
        random = random % awayPointsTrackers;

        if (random < awayPointsAfterBet[0]) {
            return awayBetPlacer[0];
        }

        uint256 hi = awayPointsAfterBet.length - 1;
        uint256 lo = 0;

        while (lo <= hi) {
            uint256 mid = lo + (hi - lo) / 2;
            if (random < awayPointsAfterBet[mid]) {
                hi = mid - 1;
            } else if (random > awayPointsAfterBet[mid]) {
                lo = mid + 1;
            } else {
                return awayBetPlacer[mid + 1];
            }
        }
        return awayBetPlacer[lo];
    }

    /**
     * @dev Generate random number to compute the winner, to be replaced with Chainlink VRF.
     */
    function _random() private view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.difficulty,
                        block.timestamp,
                        totalDeposits,
                        matchStartTime,
                        matchFinishTime
                    )
                )
            );
    }
}
