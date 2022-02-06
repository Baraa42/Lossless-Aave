from brownie import accounts, network, config, AaveLossless

FORKED_LOCAL_ENVIRONMENTS = ["mainnet-fork", "mainnet-fork-dev", "avax-main-fork"]
LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["development", "ganache-local", "mainnet-fork"]


def get_account(index=None, id=None):
    if index:
        return accounts[index]
    if id:
        return accounts.load(id)
    if (
        network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS
        or network.show_active() in FORKED_LOCAL_ENVIRONMENTS
    ):
        return accounts[0]
    return accounts.add(config["wallets"]["from_key"])


def deploy_contract(start_time, finish_time):
    account = get_account()
    qiavax_address = config["networks"][network.show_active()]["qi_avax"]
    print("Deploying Contract ")
    benqi_lossless = AaveLossless.deploy(
        qiavax_address, start_time, finish_time, {"from": account}
    )
    return benqi_lossless


def sponsor_contract(benqi_lossless, AMOUNT):
    account = get_account()
    print("Sponsoring Contract ")
    tx_sponsor = benqi_lossless.sponsor({"from": account, "value": AMOUNT})
    tx_sponsor.wait(1)
