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

contract Temp {
    //address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant aweth = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e;
    address lendingPool;
    IWETH WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    mapping(address => uint256) public aWETHBalance;

    constructor(address _lendingPool) {
        lendingPool = _lendingPool;
        IERC20(aweth).approve(lendingPool, type(uint256).max);
        WETH.approve(lendingPool, type(uint256).max);
    }

    function approve() public {
        // IERC20(aweth).approve(lendingPool, type(uint256).max);
        // WETH.approve(lendingPool, type(uint256).max);
    }

    function deposit() public payable {
        uint256 amount = msg.value;
        uint256 balanceBefore = IERC20(aweth).balanceOf(address(this));
        getWeth(amount);
        //WETH.approve(lendingPool, amount);
        ILendingPool(lendingPool).deposit(
            address(WETH),
            amount,
            address(this),
            0
        );
        uint256 balanceAfter = IERC20(aweth).balanceOf(address(this));
        aWETHBalance[msg.sender] += balanceAfter - balanceBefore;
    }

    function getWeth(uint256 amount) public payable {
        WETH.deposit{value: amount}();
    }

    function withdraw() public payable {
        uint256 balanceBefore = WETH.balanceOf(address(this));
        ILendingPool(lendingPool).withdraw(
            address(WETH),
            aWETHBalance[msg.sender],
            address(this)
        );
        uint256 balanceAfter = WETH.balanceOf(address(this));
        WETH.withdraw(balanceAfter - balanceBefore);
        aWETHBalance[msg.sender] = 0;
        payable(msg.sender).transfer(balanceAfter - balanceBefore);
    }

    function aWeth() public view returns (uint256) {
        return IERC20(aweth).balanceOf(address(this));
    }

    function Weth() public view returns (uint256) {
        return WETH.balanceOf(address(this));
    }

    receive() external payable {}
}
