// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAaveLossless {
    function sponsor(uint256, address) external;

    function winner() external returns (address);

    function randomResult() external returns (uint256);

    function playerBalance(address) external returns (uint256);

    function totalDeposits() external returns (uint256);

    function placeBet(
        address,
        uint256,
        uint256
    ) external;

    function setMatchWinner(uint256) external;
}
