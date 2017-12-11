pragma solidity ^0.4.15;

import "zeppelin-solidity/contracts/math/SafeMath.sol";


// TODO:
// What happens if endTime occurs prior to the counterparty finalizing the escrow? It should simply cancel.
// Make sure that all states are reset where appropriate.
contract Escrow {
    using SafeMath for uint;

    uint256 bet;  // Value of the bet

    // Party address, the escrow name, and status of escrow
    mapping(address => mapping(bytes32 => bool))    public escrowInitializing;
    mapping(address => mapping(bytes32 => bool))    public escrowOngoing;
    mapping(address => mapping(bytes32 => bool))    public escrowOver;
    mapping(address => mapping(bytes32 => bool))    public desiredCancelDuring;  // Signal a parties desire to cancel the escrow while it is ongoing
    mapping(address => mapping(bytes32 => bool))    public desiredCancelAfter;   // Signal a parties desire to cancel the escrow after it is over
    // Party address, the escrow name, and timestamp of the escrow
    mapping(address => mapping(bytes32 => uint256)) public endTime;
    // Counterparty address, the escrow name, and the value of the bet
    mapping(address => mapping(bytes32 => uint256)) public betVal;

    // TODO: Add events

    /// @dev Start an escrow. The creator must define the counterparty
    /// @param escrowName Name of the escrow
    /// @param counterparty The address of the person who is completing the escrow
    /// @param endTimestamp Unix timestamp of the desired end of the contract
    /// @param multiplier Multiplier for the bet. Can be positive or negative
    // TODO: Bet amount
    function startEscrow(
        bytes32 escrowName,
        address counterparty,
        uint256 endTimestamp,
        uint256 multiplier
    )
    public
    payable
    {
        require(counterparty != address(0));  // The counterparty must be defined
        require(endTimestamp > block.timestamp);   // The end of the escrow must be after the current time
        require(multiplier >= 1 * 10**17);    // The multiplier must be greater than 0.1 for simplicity
        require(escrowInitializing[msg.sender][escrowName] == false);    // Counterparty must not have started escrow of the same name
        require(escrowInitializing[counterparty][escrowName] == false);  // Counterparty must not be in an escrow of the same name
        require(escrowOngoing[msg.sender][escrowName] == false);         // Counterparty must not already be in an escrow of the same name
        require(escrowOngoing[counterparty][escrowName] == false);       // Counterparty must not already be in an escrow of the same name

        if (multiplier >= 1 * 10 ** 18) {
            bet = msg.value.mul(multiplier.div(10**18));  // TODO: Make sure this works as planned. PEMDAS.
        } else {
            bet = msg.value.mul(multiplier.div(10**17));  // TODO: Make sure this works as planned. PEMDAS.
        }
        escrowInitializing[msg.sender][escrowName] = true;  // Set the beginning of the escrow for the initiator
        betVal[msg.sender][escrowName] = msg.value;         // Set the value of the bet (done for each party)
        betVal[counterparty][escrowName] = bet;             // Set the value of the bet (done for each party)
        endTime[msg.sender][escrowName] = endTimestamp;     // Set the end time of the escrow contract
        endTime[counterparty][escrowName] = endTimestamp;   // Set the end time of the escrow contract
    }

    /// @dev Counterparty calls this function to complete their side of the escrow contract
    /// @param escrowName Name of the escrow
    /// @param counterparty The address of the person who is partaking in the escrow
    function finalizeEscrow(bytes32 escrowName, address counterparty) public payable {
        require(escrowInitializing[msg.sender][escrowName] == false);   // Escrow must have been initiated
        require(escrowInitializing[counterparty][escrowName] == true);  // Escrow must have been initiated
        require(escrowOngoing[msg.sender][escrowName] == false);        // Counterparty must not already be in an escrow of the same name
        require(escrowOngoing[counterparty][escrowName] == false);      // Counterparty must not already be in an escrow of the same name
        require(msg.value == betVal[msg.sender][escrowName]);           // The sender must send the correct amount of ETH

        escrowInitializing[msg.sender][escrowName] = true;  // Set the beginning of the escrow for the counterparty
        escrowOngoing[msg.sender][escrowName] = true;       // Begin the bet
        escrowOngoing[counterparty][escrowName] = true;     // Begin the bet
    }

    /// @dev End the escrow and retrieve funds. Must be called by both parties
    /// @param escrowName Name of the escrow
    /// @param oracleURL URL to get the oracle result from
    function endEscrow(bytes32 escrowName, string oracleURL) public {
        require()
    }

    /// @dev Cancel the escrow before it has begun. Requires just one party. Returns funds.
    /// @param escrowName Name of the escrow
    /// @param counterparty The address of the person who is partaking in the escrow
    function cancelPreEscrow(bytes32 escrowName, address counterparty) public {
        require(betVal[msg.sender][escrowName] != 0);                 // Party must have funds in the contract for thisbet
        require(escrowInitializing[msg.sender][escrowName] == true);  // Escrow of this name with this party has to be in the initializing state
        require(escrowOngoing[msg.sender][escrowName] == false);      // Escrow of this name with this party has to not be ongoing

        uint256 ethToReturn = betVal[msg.sender][escrowName];  // Calculate value to return
        escrowInitializing[msg.sender][escrowName] = false;    // Return escrowInitializing to uninitialized state
        betVal[msg.sender][escrowName] = 0;                    // Return betVal to uninitialized state
        betVal[counterparty][escrowName] = 0;                  // Return betVal to uninitialized state
        endTime[msg.sender][escrowName] = 0;                   // Return endTimestamp to uninitialized state
        endTime[counterparty][escrowName] = 0;                 // Return endTimestamp to uninitialized state

        msg.sender.transfer(ethToReturn);  // Return ETH to the appropriate party
    }

    /// @dev Cancel the escrow while it is ongoing. Requires both parties. Returns funds.
    /// @param escrowName Name of the escrow
    /// @param counterparty The address of the person who is partaking in the escrow
    function cancelMidEscrow(bytes32 escrowName, address counterparty) public {
        require(block.timestamp < endTime[msg.sender][escrowName]);     // Escrow must be ongoing
        require(escrowInitializing[msg.sender][escrowName] == true);    // Escrow must have been initiated
        require(escrowInitializing[counterparty][escrowName] == true);  // Escrow must have been initiated
        require(escrowOngoing[msg.sender][escrowName] == true);         // Escrow must be ongoing
        require(escrowOngoing[counterparty][escrowName] == true);       // Escrow must be ongoing

        desiredCancelDuring[msg.sender][escrowName] == true;  // Signal the cancellation

        if (desiredCancelDuring[msg.sender][escrowName] == true && desiredCancelDuring[counterparty][escrowName] == true) {
            uint256 ethToReturnParty = betVal[msg.sender][escrowName];
            uint256 ethToReturnCounterparty = betVal[counterparty][escrowName];
            betVal[msg.sender][escrowName] = 0;    // Return betVal to uninitialized state
            betVal[counterparty][escrowName] = 0;  // Return betVal to uninitialized state
            desiredCancelDuring[msg.sender][escrowName] == false;    // Return desiredCancelDuring to uninitialized state
            desiredCancelDuring[counterparty][escrowName] == false;  // Return desiredCancelDuring to uninitialized state
            escrowInitializing[msg.sender][escrowName] = false;      // Return escrowInitializing to uninitialized state
            escrowInitializing[counterparty][escrowName] = false;    // Return escrowInitializing to uninitialized state

            msg.sender.transfer(ethToReturnParty);           // Return ETH to the respective counterparty
            counterparty.transfer(ethToReturnCounterparty);  // Return ETH to the respective counterparty
        }
    }

    /// @dev Cancel the escrow while it is ongoing. Requires both parties. Returns funds.
    /// @param escrowName Name of the escrow
    /// @param counterparty The address of the person who is partaking in the escrow
    function cancelPostEscrow(bytes32 escrowName, address counterparty) public {
        require(block.timestamp > endTime[msg.sender][escrowName]);     // Escrow must be over
        require(escrowInitializing[msg.sender][escrowName] == true);    // Escrow must have been initiated
        require(escrowInitializing[counterparty][escrowName] == true);  // Escrow must have been initiated
        require(escrowOngoing[msg.sender][escrowName] == true);         // Escrow must have been ongoing
        require(escrowOngoing[counterparty][escrowName] == true);       // Escrow must have been ongoing
        require(escrowOver[counterparty][escrowName] == true);          // Escrow must have been ongoing
        require(escrowOver[counterparty][escrowName] == true);          // Escrow must have been ongoing

        desiredCancelAfter[msg.sender][escrowName] == true;  // Signal the cancellation

        if (desiredCancelAfter[msg.sender][escrowName] == true && desiredCancelAfter[counterparty][escrowName] == true) {
            uint256 ethToReturnParty = betVal[msg.sender][escrowName];
            uint256 ethToReturnCounterparty = betVal[counterparty][escrowName];
            betVal[msg.sender][escrowName] = 0;    // Return betVal to uninitialized state
            betVal[counterparty][escrowName] = 0;  // Return betVal to uninitialized state
            desiredCancelAfter[msg.sender][escrowName] == false;    // Return desiredCancelAfter to uninitialized state
            desiredCancelAfter[counterparty][escrowName] == false;  // Return desiredCancelAfter to uninitialized state
            escrowInitializing[msg.sender][escrowName] = false;     // Return escrowInitializing to uninitialized state
            escrowInitializing[counterparty][escrowName] = false;   // Return escrowInitializing to uninitialized state
            escrowOver[msg.sender][escrowName] = false;             // Return escrowOver to uninitialized state
            escrowOver[counterparty][escrowName] = false;           // Return escrowOver to uninitialized state

            msg.sender.transfer(ethToReturnParty);           // Return ETH to the respective counterparty
            counterparty.transfer(ethToReturnCounterparty);  // Return ETH to the respective counterparty
        }
    }
    /// @dev Retrieves the oracle result for the specified escrow
    /// @param escrowName Name of the escrow
    /// @param oracleURL URL to get the oracle result from
    function getOracleResult(bytes32 escrowName, string oracleURL) internal {
        // TODO
    }
}
