pragma solidity 0.4.4;
import "Tokens/AbstractToken.sol";


/// @title DAO Dutch auction contract - Sale of Gnosis tokens.
/// @author Stefan George - <stefan.george@consensys.net>
contract DAODutchAuction {

    /*
     *  Events
     */
    event BidSubmission(address indexed investor, uint256 amount);

    /*
     *  External contracts
     */
    Token public daoToken;

    /*
     *  Constants
     */
    uint constant public WAITING_PERIOD = 7 days;

    /*
     *  Storage
     */
    address public wallet;
    address public owner;
    uint public startBlock;
    uint public endTime;
    uint public totalRaised;
    uint public finalPrice;
    // user => amount
    mapping (address => uint) public bids;
    Stages public stage = Stages.AuctionStarted;

    enum Stages {
        AuctionStarted,
        AuctionEnded
    }

    /*
     *  Modifiers
     */
    modifier atStage(Stages _stage) {
        if (stage != _stage) {
            // Contract not in expected state
            throw;
        }
        _;
    }

    modifier isOwner() {
        if (msg.sender != owner) {
            // Only owner is allowed to proceed
            throw;
        }
        _;
    }

    modifier timedTransitions() {
        if (stage == Stages.AuctionStarted && calcTokenPrice() <= calcStopPrice()) {
            finalizeAuction();
        }
        _;
    }

    /*
     *  Constants
     */
    uint constant public FUNDING_GOAL = 1250000 ether;
    uint constant public TOTAL_TOKENS = 10000000; // 10M
    uint constant public MAX_TOKENS_SOLD = 9000000; // 9M

    /// @dev Contract constructor function sets start date.
    function DAODutchAuction() {
        startBlock = block.number;
        owner = msg.sender;
    }

    /// @dev Setup function sets external contracts' addresses.
    /// @param _daoToken DAO token address.
    /// @param _wallet DAO founders address.
    function setup(address _daoToken, address _wallet)
        external
        isOwner
    {
        if (wallet != 0 || address(daoToken) != 0) {
            // Setup was executed already
            throw;
        }
        wallet = _wallet;
        daoToken = Token(_daoToken);
    }

    /*
     * External functions
     */
    /// @dev Returns if one week after auction passed.
    /// @return Returns if one week after auction passed.
    function tokenLaunched()
        external
        timedTransitions
        returns (bool)
    {
        return endTime + WAITING_PERIOD < block.timestamp;
    }

    /// @dev Returns correct stage, even if a function with timedTransitions modifier has not yet been called successfully.
    /// @return Returns current auction stage.
    function updateStage()
        external
        timedTransitions
        returns (Stages)
    {
        return stage;
    }

    /// @dev Calculates current token price.
    /// @return Returns token price.
    function calcCurrentTokenPrice()
        external
        timedTransitions
        returns (uint)
    {
        if (stage == Stages.AuctionEnded) {
            return finalPrice;
        }
        return calcTokenPrice();
    }

    /*
     *  Public functions
     */
    /// @dev Allows to send a bid to the auction.
    function bid()
        public
        payable
        timedTransitions
        atStage(Stages.AuctionStarted)
    {
        uint investment = msg.value;
        if (totalRaised + investment > FUNDING_GOAL) {
            investment = FUNDING_GOAL - totalRaised;
            // Send change back
            if (!msg.sender.send(msg.value - investment)) {
                // Sending failed
                throw;
            }
        }
        // Forward funding to ether wallet
        if (investment == 0 || !wallet.send(investment)) {
            // No investment done or sending failed
            throw;
        }
        bids[msg.sender] += investment;
        totalRaised += investment;
        if (totalRaised == FUNDING_GOAL) {
            finalizeAuction();
        }
        BidSubmission(msg.sender, investment);
    }

    /// @dev Claims tokens for bidder after auction.
    function claimTokens()
        public
        timedTransitions
        atStage(Stages.AuctionEnded)
    {
        uint tokenCount = bids[msg.sender] * 10**18 / finalPrice;
        bids[msg.sender] = 0;
        daoToken.transfer(msg.sender, tokenCount);
    }

    /*
     *  Read functions
     */
    /// @dev Calculates stop price.
    /// @return Returns stop price.
    function calcStopPrice()
        constant
        public
        returns (uint)
    {
        return totalRaised / MAX_TOKENS_SOLD;
    }

    /// @dev Calculates token price.
    /// @return Returns token price.
    function calcTokenPrice()
        constant
        public
        returns (uint)
    {
        return 20000 * 1 ether / (block.number - startBlock + 1);
    }

    function finalizeAuction()
        private
    {
        stage = Stages.AuctionEnded;
        if (totalRaised == FUNDING_GOAL) {
            finalPrice = calcTokenPrice();
        }
        else {
            finalPrice = calcStopPrice();
        }
        uint soldTokens = totalRaised * 10**18 / finalPrice;
        // Auction contract transfers all unsold tokens to founders' multisig-wallet
        daoToken.transfer(wallet, TOTAL_TOKENS * 10**18 - soldTokens);
        endTime = block.timestamp;
    }
}
