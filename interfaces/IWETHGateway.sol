// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

interface IWETHGateway {
    function authorizeLendingPool(address) external;

    /**
     * @dev deposits WETH into the reserve, using native ETH. A corresponding amount of the overlying asset (aTokens)
     * is minted.
     **/
    function depositETH(
        address,
        address,
        uint16
    ) external payable;

    /**
     * @dev withdraws the WETH _reserves of msg.sender.
     */
    function withdrawETH(
        address,
        uint256,
        address
    ) external;

    /**
     * @dev Get WETH address used by WETHGateway
     */
    function getWETHAddress() external view returns (address);

    /**
     * @dev Only WETH contract is allowed to transfer ETH here. Prevent other addresses to send Ether to this contract.
     */
    receive() external payable;

    /**
     * @dev Revert fallback calls
     */
    fallback() external payable;
}
