from brownie import (
    network,
    config,
    interface,
    AaveLossless,
    Manager,
    Contract,
    chain,
    accounts,
)
from web3 import Web3
from scripts.helpful_scripts import (
    get_account,
    LOCAL_BLOCKCHAIN_ENVIRONMENTS,
    FORKED_LOCAL_ENVIRONMENTS,
)
import time

# 0.1
AMOUNT = Web3.toWei(100, "ether")


def main():
    # link token address
    # link whale
    # impersonnate
    account = get_account()
    link = interface.IERC20(config["networks"][network.show_active()]["link_token"])
    whale = accounts.at("0x0D4F1FF895D12C34994D6B65FABBEEFDC1A9FB39", force=True)

    tx_approve = link.approve(account, AMOUNT, {"from": whale})
    tx_approve.wait(1)
    tx_transfer = link.transfer(account, AMOUNT, {"from": whale})
    tx_transfer.wait(1)
    balance = link.balanceOf(account)
    print(balance / 10**18)
