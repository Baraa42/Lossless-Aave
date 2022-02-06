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
AMOUNT = Web3.toWei(1, "ether")


def main():
    # First getting the accounts
    account = get_account()
    # all_accounts = get_accounts()
    weth = interface.IERC20(config["networks"][network.show_active()]["weth_token"])
    aeth = interface.IERC20(config["networks"][network.show_active()]["aeth_token"])
    # Deploy the manager
    # Get address _lendingPool, address payable _wethGateway
    lending_pool = get_lending_pool()
    lending_pool_address = lending_pool.address

    # Deploy manager
    ## Set start and end blocks
    start_time = 1646078776  ## 28 feb
    finish_time = start_time + 4500
    manager = deploy_contract(lending_pool_address)
    # manager = Manager[-1]
    fund_with_link(manager.address, 1000 * AMOUNT)
    # Initialisation
    # print("Initialize")
    # tx_init = manager.initialise({"from": account})
    # tx_init.wait(1)
    print(f"allowance : { weth.allowance( manager.address, lending_pool_address)}")
    # create games
    print("Creating Game 1 ")
    tx_create_1 = manager.create(
        lending_pool_address, start_time, finish_time, {"from": account}
    )
    tx_create_1.wait(1)
    print("Creating Game 2 ")
    tx_create_2 = manager.create(
        lending_pool_address, start_time + 10, finish_time + 10, {"from": account}
    )
    tx_create_2.wait(1)

    # print("Get weth for account")
    # get_weth(account)
    # print("approve spending")
    # tx_approve = weth.approve(manager.address, AMOUNT, {"from": account})
    # tx_approve.wait(1)
    print("Sponsoring Contract ")
    # tx_sponsor = manager.sponsor(0, AMOUNT, {"from": account, "value": AMOUNT})
    # tx_sponsor.wait(1)
    tx_sponsor = manager.sponsor(0, {"from": account, "value": AMOUNT})
    tx_sponsor.wait(1)
    aeth_balance = aeth.balanceOf(manager.address)
    print(f"Contract ETH balance is {manager.balance()}")
    print(
        f"contract balance of aWETH after sponsor bet is {aeth_balance / 10**18} aWETH"
    )
    chain.mine(10)
    aeth_balance = aeth.balanceOf(manager.address)
    print(
        f"contract balance of aWETH after sponsor bet is {aeth_balance / 10**18} aWETH"
    )

    print("placing bets")
    place_bets(manager, 0)
    tx_bet1 = manager.placeBet(0, 1, {"from": account, "value": AMOUNT / 5})
    tx_bet1.wait(1)
    aeth_balance = aeth.balanceOf(manager.address)
    print(f"Contract ETH balance is {manager.balance()}")
    print(
        f"contract balance of aWETH after sponsor bet is {aeth_balance / 10**18} aWETH"
    )
    chain.mine(20)
    # aweth_balance = weth.balanceOf(manager.address)
    # print(f"Contract ETH balance is {manager.balance()}")
    # print(f"contract balance of aWETH after bet is {aweth_balance / 10**18} aWETH")

    # game = interface.IAaveLossless(manager.games(0))
    # for l in get_accounts():
    #     print(
    #         f"balance of game 0 of  {l} is {game.playerBalance(l, {'from':account}).return_value / 10**18}"
    #     )

    # aweth_balance = aweth.balanceOf(manager.address)
    # print(f"Contract ETH balance is {manager.balance()}")
    # print(f"contract balance of aWETH after bet is {aweth_balance / 10**18} aWETH")
    # print(f"allowance : { aweth.allowance( manager.address,  wethGateway_address)}")

    tx_winner = manager.setMatchWinnerAndWithdrawFromPool(0, 3, {"from": account})
    tx_winner.wait(1)

    for l in get_accounts():
        print(f"balance of {l} is {manager.playerToBalance(l)}")
        tx_withdraw = manager.withdraw({"from": l})
        tx_withdraw.wait(1)
        print(f"balance of {l} is {manager.playerToBalance(l)}")

    winner = (
        interface.IAaveLossless(manager.games(0)).winner({"from": account}).return_value
    )
    print(f"winner is {winner} ")
    chain.mine(20)
    random = (
        interface.IAaveLossless(manager.games(0))
        .randomResult({"from": account})
        .return_value
    )
    print(f"winner is {random} ")
    # qiavax_balance = iqiavax.balanceOf(manager.address)
    # print(f"game 0 balance is {manager.gameIdToTokenBalance(0)}")
    # print(f"Contract Avax balance is {manager.balance()}")
    # print(f"contract balance of qiavax before bet is {qiavax_balance / 10**8} QiAvax")

    # print(benqi_lossless.getQiTokenBalance({"from": account}))
    # print("redeeming")
    # tx_redeem = benqi_lossless.redeem(
    #     qiavax_address, {"from": account, "gas_limit": 250000}
    # )
    # tx_redeem.wait(1)
    # tx_bet = benqi_lossless.placeBet(1, {"from": account, "value": AMOUNT / 5})
    # tx_bet.wait(1)
    # qiavax_balance = iqiavax.balanceOf(benqi_lossless.address)
    # print(f"contract balance of qiavax is {qiavax_balance / 10**8} QiAvax")
    # place_bets(benqi_lossless)
    # print(f"owner is : {benqi_lossless.owner()}")
    # set_winner(benqi_lossless)

    # display_contract_balances(benqi_lossless, all_accounts)
    # withdraw(benqi_lossless, all_accounts)
    # display_contract_balances(benqi_lossless, all_accounts)
    # display_balances(benqi_lossless, all_accounts)


def deploy_contract(lending_pool_address):
    account = get_account()
    print("Deploying Manager Contract ")
    manager = Manager.deploy(lending_pool_address, {"from": account})
    return manager


def fund_with_link(account, amount):
    link = interface.IERC20(config["networks"][network.show_active()]["link_token"])
    whale = accounts.at("0x0D4F1FF895D12C34994D6B65FABBEEFDC1A9FB39", force=True)

    tx_approve = link.approve(account, amount, {"from": whale})
    tx_approve.wait(1)
    tx_transfer = link.transfer(account, amount, {"from": whale})
    tx_transfer.wait(1)
    balance = link.balanceOf(account)
    print(f"{account} Link Balance : {balance / 10**18}")


def place_bets(manager, game_id):
    if (
        network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS
        or network.show_active() in FORKED_LOCAL_ENVIRONMENTS
    ):
        account_1 = get_account(index=1)
        account_2 = get_account(index=2)
        account_3 = get_account(index=3)
        account_4 = get_account(index=4)
        account_5 = get_account(index=5)
        account_6 = get_account(index=6)
    else:
        account_1 = get_account(id=1)
        account_2 = get_account(id=2)
        account_3 = get_account(id=3)
        account_4 = get_account(id=4)
        account_5 = get_account(id=5)
        account_6 = get_account(id=6)

    print("placing a bets")

    tx_bet1 = manager.placeBet(game_id, 1, {"from": account_1, "value": AMOUNT / 5})
    tx_bet1.wait(1)

    tx_bet2 = manager.placeBet(game_id, 2, {"from": account_2, "value": 2 * AMOUNT / 5})
    tx_bet2.wait(1)

    tx_bet3 = manager.placeBet(game_id, 1, {"from": account_3, "value": 3 * AMOUNT / 5})
    tx_bet3.wait(1)

    tx_bet4 = manager.placeBet(game_id, 2, {"from": account_4, "value": 4 * AMOUNT / 5})
    tx_bet4.wait(1)

    tx_bet5 = manager.placeBet(game_id, 3, {"from": account_5, "value": 2 * AMOUNT / 5})
    tx_bet5.wait(1)

    tx_bet6 = manager.placeBet(game_id, 3, {"from": account_6, "value": 2 * AMOUNT / 5})
    tx_bet6.wait(1)

    print("ALL BETS PLACED")


def set_winner(benqi_lossless):
    account = get_account()
    print("selecting winner")
    tx_set_winner = benqi_lossless.setMatchWinnerAndWithdrawFromPool(
        3, {"from": account, "gas_limit": 2000000}
    )
    tx_set_winner.wait(1)
    print(f"the winner is : {benqi_lossless.winner()}")


def display_contract_balances(benqi_lossless, acc):
    for ac in acc:
        print(f"Contract balance of {ac} is {benqi_lossless.playerBalance(ac.address)}")

    print(f"balance of contract in QiAvax is {benqi_lossless.getQiTokenBalance()}")


def display_balances(benqi_lossless, acc):
    for ac in acc:
        print(f" balance of {ac.address} is {ac.balance()}")
    print(f"balance of contract in Avax is {benqi_lossless.balance()}")


def get_accounts():
    l = [get_account()]
    if (
        network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS
        or network.show_active() in FORKED_LOCAL_ENVIRONMENTS
    ):
        for i in range(1, 7):
            l.append(get_account(index=i))
    else:
        for i in range(1, 7):
            l.append(get_account(id=i))

    return l


def withdraw(benqi_lossless, acc):
    for ac in acc:
        tx_withdraw = benqi_lossless.withdraw({"from": ac})
        tx_withdraw.wait(1)


def get_lending_pool():
    lending_pool_addresses_provider = interface.ILendingPoolAddressesProvider(
        config["networks"][network.show_active()]["lending_pool_addresses_provider"]
    )
    lending_pool_address = lending_pool_addresses_provider.getLendingPool()
    lending_pool = interface.ILendingPool(lending_pool_address)
    return lending_pool


def get_weth_gateway():
    weth_gateway = interface.IWETHGateway(
        config["networks"][network.show_active()]["weth_gateway"]
    )
    # weth_gateway = Contract.from_explorer(
    #     config["networks"][network.show_active()]["weth_gateway"]
    # )
    return weth_gateway


def get_weth(account):
    """
    Mints WETH by depositing ETH.
    """
    weth = interface.IWETH(config["networks"][network.show_active()]["weth_token"])
    tx = weth.deposit({"from": account, "value": 1 * 10**18})
    tx.wait(1)
    print("Received 1 WETH")
