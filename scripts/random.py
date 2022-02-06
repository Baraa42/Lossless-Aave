from brownie import (
    network,
    config,
    interface,
    AaveLossless,
    Manager,
    Contract,
    chain,
    accounts,
    Random,
)
from web3 import Web3
from scripts.helpful_scripts import (
    get_account,
    LOCAL_BLOCKCHAIN_ENVIRONMENTS,
    FORKED_LOCAL_ENVIRONMENTS,
)
import time

# 0.1
AMOUNT = Web3.toWei(0.1, "ether")


def main():
    # First getting the accounts
    account = get_account()
    # Deploy the random
    random = Random[-1]
    # random = Random.deploy({"from": account})
    # # get link token
    # link = interface.IERC20(config["networks"][network.show_active()]["link_token"])
    # # Send link to random
    # tx_approve = link.approve(random.address, AMOUNT, {"from": account})
    # tx_approve.wait(1)
    # tx_transfer = link.transfer(random.address, AMOUNT, {"from": account})
    # tx_transfer.wait(1)
    # # play a some rounds
    # tx_play = random.play(account, {"from": account})
    # tx_play.wait(1)
    # tx_play = random.play(
    #     "0x0D4f1ff895D12c34994D6B65FaBBeEFDc1a9fb39", {"from": account}
    # )
    # tx_play.wait(1)
    # tx_play = random.play(random.address, {"from": account})
    # tx_play.wait(1)
    # tx_play = random.play(link.address, {"from": account})
    # tx_play.wait(1)
    # # decide
    # tx_decide = random.decide({"from": account})
    # tx_decide.wait(1)
    # print winner and random result
    winner = random.winner({"from": account})
    random_result = random.randomResult({"from": account})
    print(f"The winner is {winner}")
    print(f"Random number : {random_result}")
