pragma solidity 0.4.4;
import "Tokens/StandardToken.sol";
import "DO/AbstractDutchAuction.sol";


/// @title Gnosis token contract - Holds tokens of Gnosis.
/// @author Stefan George - <stefan.george@consensys.net>
contract GnosisToken is StandardToken {

    /*
     *  Token meta data
     */
    string constant public name = "Gnosis Token";
    string constant public symbol = "GNO";
    uint8 constant public decimals = 18;

    /*
     *  External contracts
     */
    DutchAuction public dutchAuction;

    /*
     *  Modifiers
     */
    modifier tokenLaunched() {
        if (!dutchAuction.tokenLaunched() && msg.sender != address(dutchAuction)) {
            // Token was not launched yet and sender is not auction contract
            throw;
        }
        _;
    }

    /*
     *  Public functions
     */
    /// @dev Contract constructor function sets owner.
    function GnosisToken(address _dutchAuction)
        public
    {
        dutchAuction = DutchAuction(_dutchAuction);
        uint _totalSupply = 10000000 * 10**18;
        balances[_dutchAuction] = _totalSupply;
        totalSupply = _totalSupply;
    }

    /// @dev Transfers sender's tokens to a given address. Returns success.
    /// @param to Address of token receiver.
    /// @param value Number of tokens to transfer.
    /// @return Returns success of function call.
    function transfer(address to, uint256 value)
        public
        tokenLaunched
        returns (bool)
    {
        return super.transfer(to, value);
    }

    /// @dev Allows allowed third party to transfer tokens from one address to another. Returns success.
    /// @param from Address from where tokens are withdrawn.
    /// @param to Address to where tokens are sent.
    /// @param value Number of tokens to transfer.
    /// @return Returns success of function call.
    function transferFrom(address from, address to, uint256 value)
        public
        tokenLaunched
        returns (bool)
    {
        return super.transferFrom(from, to, value);
    }
}
