pragma solidity ^0.4.15;

import "zeppelin-solidity/contracts/math/SafeMath.sol";


// TODO:
// What happens if endTime occurs prior to the coutnerparty finalizing the escrow? It should simply cancel.
contract Escrow {
    using SafeMath for uint;

    uint256 bet;

    // Counterparty address, the escrow name, and status of escrow
    mapping(address => mapping(bytes32 => bool)) public escrowInitializing;
    mapping(address => mapping(bytes32 => bool)) public escrowOngoing;
    // Counterparty address, the escrow name, and the value of the bet
    mapping(address => mapping(bytes32 => uint256)) public betVal;

    /// @dev Start an escrow. The creator must define the counterparty
    /// @param escrowName Name of the escrow
    /// @param counterparty The address of the person who is completing the escrow
    /// @param endTime Unix timestamp of the desired end of the contract
    /// @param multiplier Multiplier for the bet. Can be positive or negative
    function startEscrow(
        string escrowName,
        address counterparty,
        uint256 endTime,
        uint256 multiplier,
    )
        public
        payable
    {
        require(counterparty != address(0));  // The counterparty must be defined
        require(endTime > block.timestamp);   // The end of the escrow must be after the current time
        require(multiplier >= 0.1);           // The multiplier must be greater than 0.1 for simplicity
        require(escrowInitializing[msg.sender][escrowName] != true);     // Counterparty must not have started escrow of the same name
        require(escrowInitializing[counterparty][escrowName] != true);   // Counterparty must not be in an escrow of the same name
        require(escrowOngoing[msg.sender][escrowName] != true);          // Counterparty must not already be in an escrow of the same name
        require(escrowOngoing[counterparty][escrowName] != true);        // Counterparty must not already be in an escrow of the same name

        if (multiplier >= 1) {
            bet = msg.value.mul(multiplier.div(10**18));  // TODO: Make sure this works as planned. PEMDAS.
        } else {
            bet = msg.value.mul(multiplier.div(10**17));  // TODO: Make sure this works as planned. PEMDAS.
        }
        escrowInitializing[msg.sender][escrowName] = true;  // Set the beginning of the escrow for the initiator
        betVal[msg.sender][escrowName] = bet;               // Set the value of the bet (done for each party)
        betVal[counterparty][escrowName] = bet;             // Set the value of the bet (done for each party)
    }

    /// @dev Counterparty calls this function to complete their side of the escrow contract
    /// @param escrowName Name of the escrow
    /// @param counterparty The address of the person who is partaking in the escrow
    function finalizeEscrow(string escrowName, address counterparty) public payable {
        require(escrowInitializing[msg.sender][escrowName] != true);        // Escrow must have been initiated
        require(escrowInitializing[msg.counterparty][escrowName] != true);  // Escrow must have been initiated
        require(escrowOngoing[msg.sender][escrowName] != true);             // Counterparty must not already be in an escrow of the same name
        require(escrowOngoing[counterparty][escrowName] != true);           // Counterparty must not already be in an escrow of the same name
        require(msg.value == betVal[msg.sender][escrowName]);               // The sender must send the correct amount of ETH

        escrowInitializing[msg.sender][escrowName] = true;  // Set the beginning of the escrow for the counterparty
        escrowOngoing[msg.sender][escrowName] = true;       // Begin the bet
        escrowOngoing[counterparty][escrowName] = true;     // Begin the bet

    }

    /// @dev End the escrow and retrieve funds. Must be called by both parties
    /// @param escrowName Name of the escrow
    /// @param oracleURL URL to get the oracle result from
    function endEscrow() public {

    }

    /// @dev Cancel the escrow before it has begun. Requires just one party. Returns funds.
    /// @param escrowName Name of the escrow
    function cancelPreEscrow() public {

    }

    /// @dev Cancel the escrow while it is ongoing. Requires both parties. Returns funds.
    /// @param escrowName Name of the escrow
    function cancelMidEscrow() public {

    }

    /// @dev Cancel the escrow after it has concluded. This is to be used in the event of a bad oracle or off-chain
    /// @dev cancellation agreement. Requires both parties. Returns funds.
    /// @param escrowName Name of the escrow
    function cancelPostEscrow() public {

    }

    /// @dev Retrieves the oracle result for the specified escrow
    /// @param escrowName Name of the escrow
    /// @param oracleURL URL to get the oracle result from
    function getOracleResult() internal {

    }
}
