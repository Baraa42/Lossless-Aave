// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/IERC20.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract Random is VRFConsumerBase {
    bytes32 internal keyHash =
        0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
    uint256 internal fee = 0.1 * 10**18;
    uint256 public randomResult;
    address[] public players;
    address public winner;

    /**
     * @dev Initialize the contract settings : matchStartTime, matchFinishTime, QiAvax address .
     */
    constructor()
        VRFConsumerBase(
            0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF
            0xa36085F69e2889c224210F603D836748e7dC0088 // Link
        )
    {}

    function play(address _player) public {
        players.push(_player);
    }

    function decide() public {
        getRandomNumber();
    }

    /**
     * @dev Internal function to find the winnner of the lottery.
     */
    function findWinner(uint256 _random) internal {
        _random = _random % players.length;
        winner = players[_random];
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
    }
}
