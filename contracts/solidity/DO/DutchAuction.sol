pragma solidity 0.4.4;
import "Tokens/AbstractToken.sol";


/// @title Dutch auction contract - creation of Gnosis tokens.
/// @author Stefan George - <stefan.george@consensys.net>
contract DutchAuction {

    /*
     *  Events
     */
    event BidSubmission(address indexed investor, uint256 amount);

    /*
     *  Constants
     */
    uint constant public FUNDING_GOAL = 1250000 ether;
    uint constant public TOTAL_TOKENS = 10000000; // 10M
    uint constant public MAX_TOKENS_SOLD = 9000000; // 9M
    uint constant public WAITING_PERIOD = 7 days;

    /*
     *  Storage
     */
    Token public gnosisToken;
    address public wallet;
    address public owner;
    uint public startBlock;
    uint public endTime;
    uint public totalRaised;
    uint public finalPrice;
    mapping (address => uint) public bids;
    Stages public stage = Stages.AuctionStarted;

    /*
     *  Enums
     */
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
     *  Public functions
     */
    /// @dev Contract constructor function sets start date.
    function DutchAuction()
        public
    {
        startBlock = block.number;
        owner = msg.sender;
    }

    /// @dev Setup function sets external contracts' addresses.
    /// @param _gnosisToken Gnosis token address.
    /// @param _wallet Gnosis founders address.
    function setup(address _gnosisToken, address _wallet)
        public
        isOwner
    {
        if (wallet != 0 || address(gnosisToken) != 0) {
            // Setup was executed already
            throw;
        }
        wallet = _wallet;
        gnosisToken = Token(_gnosisToken);
    }

    /// @dev Returns if one week after auction passed.
    /// @return Returns if one week after auction passed.
    function tokenLaunched()
        public
        timedTransitions
        returns (bool)
    {
        return endTime + WAITING_PERIOD < block.timestamp;
    }

    /// @dev Returns correct stage, even if a function with timedTransitions modifier has not yet been called yet.
    /// @return Returns current auction stage.
    function updateStage()
        public
        timedTransitions
        returns (Stages)
    {
        return stage;
    }

    /// @dev Calculates current token price.
    /// @return Returns token price.
    function calcCurrentTokenPrice()
        public
        timedTransitions
        returns (uint)
    {
        if (stage == Stages.AuctionEnded) {
            return finalPrice;
        }
        return calcTokenPrice();
    }

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
        gnosisToken.transfer(msg.sender, tokenCount);
    }

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

    /*
     *  Private functions
     */
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
        gnosisToken.transfer(wallet, TOTAL_TOKENS * 10**18 - soldTokens);
        endTime = block.timestamp;
    }
}
