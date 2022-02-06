// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Lossless.sol";
import "./AaveLossless.sol";
import "../interfaces/IAaveLossless.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IWETHGateway.sol";
import "../interfaces/ILendingPoolAddressesProvider.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/** @title Manager
 *  @dev This contract implement is a lossless betting contracts for football 1X2 that uses Aave to generate yield
 * Contract has an owner to settle the bet, to be replaced by Chainlink.
 * This contract support multiple games
 * Process : - Owner creates contract.
 *           - Contract can also be sponsored : someone deposit without participating in betting.
 * Weth-Mainnet : 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
 * aWeth-Mainnet : 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e
 * WMatic-Mumbai : 0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889
 * aMatic-Mumbai : 0xF45444171435d0aCB08a8af493837eF18e86EE27
 * Contracts adresses : See  addresses here 'https://docs.aave.com/developers/v/2.0/deployed-contracts'
 */

contract Manager is Ownable {
    IWETH WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 AWETH = IERC20(0x030bA81f1c18d280636F32af80b9AAd02Cf0854e);
    IERC20 LINK = IERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
    uint256 internal fee = 2 * 10**18;
    //IWETH WETH  = IWETH(0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889); MUMBAI
    //IERC20 AWETH = IERC20(0xF45444171435d0aCB08a8af493837eF18e86EE27); Mumbai
    // IERC20 LINK = IERC20(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
    // tracks games count
    uint256 public gamesCount;
    // array of games
    AaveLossless[] public games;
    // interface to interact with qiToken
    ILendingPool public lendingPool;

    // mapping gameId => game contract address
    mapping(uint256 => address) public gameIdToAddress;
    // mapping address => gameId
    mapping(address => uint256) public addressToGameId;
    // gameId to Total prize
    mapping(uint256 => uint256) public gameIdToPrize;
    // mapping address => player balance available to withdraw
    mapping(address => uint256) public playerToBalance;
    // mapping gameId => address => bool if player bet or not
    mapping(uint256 => mapping(address => bool)) public gameIdToPlayerIn;
    // mapping gameId => array containing players that placed a bet
    mapping(uint256 => address[]) public gameIdToPlayers;

    event GameCreated(uint256 gameId, address gameAddress);
    event GameSponsored(uint256 gameId, uint256 amount);
    event BetPlaced(
        uint256 gameId,
        AaveLossless.BetSide betside,
        uint256 amount
    );
    event Winner(uint256 gameId, address winner, uint256 amount);

    /**
     * @dev Initialize the contract settings .
     * Approves  :
     * Lending Pool : to spend WETH
     */
    constructor(address _lendingPool) {
        gamesCount = 0;
        lendingPool = ILendingPool(_lendingPool);
        WETH.approve(_lendingPool, type(uint256).max);
    }

    /**
     * @dev Creates a game, only owner can : Feed in timestamp of start and finish
     */
    function create(
        address _lendingPool,
        uint256 _matchStartTime,
        uint256 _matchFinishTime
    ) external onlyOwner {
        AaveLossless _game = new AaveLossless(
            _lendingPool,
            _matchStartTime,
            _matchFinishTime
        );
        address _gameAddress = address(_game);
        gameIdToAddress[gamesCount] = _gameAddress;
        addressToGameId[_gameAddress] = gamesCount;
        games.push(_game);
        emit GameCreated(gamesCount, _gameAddress);
        // fund with link
        LINK.approve(_gameAddress, fee);
        LINK.transfer(_gameAddress, fee);
        gamesCount++;
    }

    function sponsor(uint256 _gameId) external payable {
        // get Amount and game address
        address gameAddress = gameIdToAddress[_gameId];
        uint256 amount = msg.value;
        // Mint WETH
        WETH.deposit{value: amount}();
        // Minet aETH and send it to game address
        lendingPool.deposit(address(WETH), amount, gameAddress, 0);
        // Sponsor bet
        IAaveLossless Igame = IAaveLossless(gameAddress);
        Igame.sponsor(amount, msg.sender);
        // take into account msg.sender
        if (!gameIdToPlayerIn[_gameId][msg.sender]) {
            gameIdToPlayerIn[_gameId][msg.sender] = true;
            gameIdToPlayers[_gameId].push(msg.sender);
        }
        // emit event
        emit GameSponsored(_gameId, amount);
    }

    /**
     * @dev Places the bet.
     */

    function placeBet(uint256 _gameId, uint256 _betSide) external payable {
        // Get amount and gameAddress
        address gameAddress = gameIdToAddress[_gameId];
        uint256 amount = msg.value;
        // Mint WETH
        WETH.deposit{value: amount}();
        // Mint aETH to game address
        lendingPool.deposit(address(WETH), amount, gameAddress, 0);
        // Place bet
        IAaveLossless Igame = IAaveLossless(gameAddress);
        Igame.placeBet(msg.sender, amount, _betSide);
        // take into account msg.sender
        if (!gameIdToPlayerIn[_gameId][msg.sender]) {
            gameIdToPlayerIn[_gameId][msg.sender] = true;
            gameIdToPlayers[_gameId].push(msg.sender);
        }
        // emit event
        AaveLossless.BetSide bettingSide = _betSide == 1
            ? AaveLossless.BetSide.HOME
            : _betSide == 2
            ? AaveLossless.BetSide.DRAW
            : AaveLossless.BetSide.AWAY;
        emit BetPlaced(_gameId, bettingSide, amount);
    }

    /**
     * @dev Withdraw avaialble balance.
     */
    function withdraw() external {
        require(playerToBalance[msg.sender] > 0, "balance is zero");
        uint256 amount = playerToBalance[msg.sender];
        playerToBalance[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    /**
     * @dev Settles match, winner and withdraw from pool from game with _gameId .
     * Only Owner can call, replace with chainlink
     */
    function setMatchWinnerAndWithdrawFromPool(
        uint256 _gameId,
        uint256 _winningSide
    ) external onlyOwner {
        // Get gameAddress and contract
        address payable gameAddress = payable(gameIdToAddress[_gameId]);
        AaveLossless aaveLossless = AaveLossless(gameAddress);

        /* Set Game Winner and withdraw
         * Withdrawal happens inside setMatchWinner function
         * game will send back WETH to contract
         */

        IAaveLossless Igame = IAaveLossless(gameAddress);
        uint256 balanceBefore = WETH.balanceOf(address(this));
        Igame.setMatchWinner(_winningSide);
        uint256 balanceAfter = WETH.balanceOf(address(this));
        uint256 redeemAmount = balanceAfter - balanceBefore;
        // redeem money
        WETH.withdraw(redeemAmount);

        // Update balances
        for (uint256 i = 0; i < gameIdToPlayers[_gameId].length; i++) {
            address player = gameIdToPlayers[_gameId][i];
            playerToBalance[player] += aaveLossless.playerBalance(player);
        }

        // update winner balance
        gameIdToPrize[_gameId] =
            balanceAfter -
            balanceBefore -
            aaveLossless.totalDeposits();
        // address winner = aaveLossless.winner();
        // playerToBalance[winner] +=
        //     balanceAfter -
        //     balanceBefore -
        //     aaveLossless.totalDeposits();
        // emit Winner(_gameId, winner, balanceAfter - balanceBefore);
    }

    function payWinner() external {
        uint256 gameId = addressToGameId[msg.sender];
        address gameAddress = gameIdToAddress[gameId];
        require(msg.sender == gameAddress, "Not allowed");
        address winner = AaveLossless(gameAddress).winner();
        playerToBalance[winner] += gameIdToPrize[gameId];
        emit Winner(gameId, winner, gameIdToPrize[gameId]);
    }

    /**
     * @dev to receive ETH/MATIC
     */
    receive() external payable {}
}
