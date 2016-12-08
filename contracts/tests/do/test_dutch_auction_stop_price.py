from ..abstract_test import AbstractTestContract, accounts, keys, TransactionFailed


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.do.test_dutch_auction_stop_price
    """

    BACKER_1 = 1
    BACKER_2 = 2
    BLOCKS_PER_DAY = 5760
    TOTAL_TOKENS = 10000000 * 10**18

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.gnosis_token_name, self.dutch_auction_name]

    def test(self):
        # Create mist wallet
        required_accounts = 1
        wa_1 = 1
        # Create wallet
        constructor_parameters = (
            [accounts[wa_1]],
            required_accounts
        )
        self.multisig_wallet = self.s.abi_contract(
            self.pp.process('Wallets/MultiSigWalletWithDailyLimit.sol', add_dev_code=True, contract_dir=self.contract_dir),
            language='solidity',
            constructor_parameters=constructor_parameters
        )
        self.dutch_auction.setup(self.gnosis_token.address, self.multisig_wallet.address)
        # Bidder 1 places a bid in the first block after auction starts
        self.assertEqual(self.dutch_auction.calcTokenPrice(), 20000 * 10 ** 18)
        bidder_1 = 0
        value_1 = 500000 * 10**18  # 500k Ether
        self.s.block.set_balance(accounts[bidder_1], value_1*2)
        self.dutch_auction.bid(sender=keys[bidder_1], value=value_1)
        self.assertEqual(self.dutch_auction.calcStopPrice(), value_1 / 9000000)
        # A few blocks later
        self.s.block.number += self.BLOCKS_PER_DAY*2
        self.assertEqual(self.dutch_auction.calcTokenPrice(), 20000 * 10 ** 18 / (self.BLOCKS_PER_DAY * 2 + 1))
        # Bidder 2 places a bid
        bidder_2 = 1
        value_2 = 500000 * 10**18  # 1M Ether
        self.s.block.set_balance(accounts[bidder_2], value_2*2)
        self.dutch_auction.bid(sender=keys[bidder_2], value=value_2)
        # Stop price changed
        self.assertEqual(self.dutch_auction.calcStopPrice(), (value_1 + value_2) / 9000000)
        # Stop price is reached
        self.s.block.number += self.BLOCKS_PER_DAY*40
        # Auction is over, no more bids are accepted
        self.s.block.set_balance(accounts[bidder_2], value_2 * 2)
        self.assertRaises(TransactionFailed, self.dutch_auction.bid, sender=keys[bidder_2], value=value_2)
        self.assertLess(self.dutch_auction.calcTokenPrice(), self.dutch_auction.calcStopPrice())
        # There is no money left in the contract
        self.assertEqual(self.s.block.get_balance(self.dutch_auction.address), 0)
        # Everyone gets their tokens
        self.dutch_auction.claimTokens(sender=keys[bidder_1])
        self.dutch_auction.claimTokens(sender=keys[bidder_2])
        # Confirm token balances
        self.assertEqual(self.gnosis_token.balanceOf(accounts[bidder_1]),
                         value_1 * 10 ** 18 / self.dutch_auction.finalPrice())
        self.assertEqual(self.gnosis_token.balanceOf(accounts[bidder_2]),
                         value_2 * 10 ** 18 / self.dutch_auction.finalPrice())
        self.assertEqual(
            self.gnosis_token.balanceOf(self.multisig_wallet.address),
            self.TOTAL_TOKENS - self.dutch_auction.totalReceived() * 10 ** 18 / self.dutch_auction.finalPrice())
        self.assertEqual(self.gnosis_token.totalSupply(), self.TOTAL_TOKENS)
        # All funds went to the multisig wallet
        self.assertEqual(self.s.block.get_balance(self.multisig_wallet.address), 1000000 * 10**18)
