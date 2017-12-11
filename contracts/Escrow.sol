pragma solidity ^0.4.15;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";


// TODO:
// What happens if endTime occurs prior to the counterparty finalizing the escrow? It should simply cancel.
contract Escrow {
    using SafeMath for uint;

    uint256 public bet;     // Value of the bet
    address public winner;  // Winner of the bet
    address public loser;   // Loser of the bet

    // Party address, the escrow name, and status of escrow
    mapping(address => mapping(bytes32 => bool))    public escrowInitializing;
    mapping(address => mapping(bytes32 => bool))    public escrowOngoing;
    mapping(address => mapping(bytes32 => bool))    public escrowOver;
    mapping(address => mapping(bytes32 => bool))    public desiredCancelDuring;  // Signal a parties desire to cancel the escrow while it is ongoing
    mapping(address => mapping(bytes32 => bool))    public desiredCancelAfter;   // Signal a parties desire to cancel the escrow after it is over
    // Party address, the escrow name, and timestamp of the escrow
    mapping(address => mapping(bytes32 => uint256)) public endTime;
    // Party address, the escrow name, and the value of the bet
    mapping(address => mapping(bytes32 => uint256)) public betVal;
    // Party address, the escrow name, and the expected value of the result
    mapping(address => mapping(bytes32 => uint256)) public predictedResult;           // Predicted result of the bet
    mapping(address => mapping(bytes32 => bool))    public predictedResultCondition;  // Condition of the result. >= (true) or < (false)

    // TODO: Index events
    event StartEscrow(address party, address counterparty, bytes32 escrowName, uint256 endTimestamp, uint256 multiplier, uint256 amountBet, uint256 predictedResult, bool predictedResultCondition);  // Log the start of an escrow
    event CancelEscrow(address party, address counterparty, bytes32 escrowName, uint256 endTimestamp, string state);  // Log cancel
    event LogWinner(address winner, uint256 value, bytes32 escrowName, uint256 predictedResult, bool predictedResultCondition, uint256 result);  // Log winner
    event LogLoser(address winner, bytes32 escrowName, uint256 predictedResult, bool predictedResultCondition, uint256 result);  // Log winner

    /// @dev Start an escrow. The creator must define the counterparty
    /// @param escrowName Name of the escrow
    /// @param counterparty The address of the person who is completing the escrow
    /// @param endTimestamp Unix timestamp of the desired end of the contract
    /// @param multiplier Multiplier for the bet. Can be positive or negative
    /// @param resultVal Predicted value of the result
    /// @param resultCondition Party expects the result to be greater than or equal to (true) or less than (false) his prediction
    function startEscrow(
        bytes32 escrowName,
        address counterparty,
        uint256 endTimestamp,
        uint256 multiplier,
        uint256 resultVal,
        bool resultCondition
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

        if (multiplier >= 1 ether) {
            bet = msg.value.mul(multiplier.div(10**18));  // TODO: Make sure this works as planned. PEMDAS.
        } else {
            bet = msg.value.mul(multiplier.div(10**17));  // TODO: Make sure this works as planned. PEMDAS.
        }
        escrowInitializing[msg.sender][escrowName] = true;      // Set the beginning of the escrow for the initiator
        betVal[msg.sender][escrowName] = msg.value;             // Set the value of the bet (done for each party)
        betVal[counterparty][escrowName] = bet;                 // Set the value of the bet (done for each party)
        endTime[msg.sender][escrowName] = endTimestamp;         // Set the end time of the escrow contract
        endTime[counterparty][escrowName] = endTimestamp;       // Set the end time of the escrow contract
        predictedResult[msg.sender][escrowName] = resultVal;    // Set the predicted result
        predictedResult[counterparty][escrowName] = resultVal;  // Set the predicted result
        predictedResultCondition[msg.sender][escrowName] = resultCondition;    // Set the predicted result
        predictedResultCondition[counterparty][escrowName] = resultCondition;  // Set the predicted result

        StartEscrow(msg.sender, counterparty, escrowName, endTimestamp, multiplier, msg.value, resultVal, resultCondition);
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

    /// @dev End the escrow and retrieve funds. Can be called by either.
    /// @param escrowName Name of the escrow
    /// @param counterparty The address of the person who is partaking in the escrow
    /// @param oracleURL URL to get the oracle result from
    function endEscrow(bytes32 escrowName, address counterparty, string oracleURL) public {
        require(block.timestamp > endTime[msg.sender][escrowName]);     // Escrow must be over
        require(escrowInitializing[msg.sender][escrowName] == true);    // Escrow must have been initiated
        require(escrowInitializing[counterparty][escrowName] == true);  // Escrow must have been initiated
        require(escrowOngoing[msg.sender][escrowName] == true);         // Escrow must have been ongoing
        require(escrowOngoing[counterparty][escrowName] == true);       // Escrow must have been ongoing
        require(escrowOver[counterparty][escrowName] == true);          // Escrow must have been ongoing
        require(escrowOver[counterparty][escrowName] == true);          // Escrow must have been ongoing

        // Calculate the winner and loser
        uint256 oracleResult = getOracleResult(oracleURL);
        if (predictedResultCondition[msg.sender][escrowName] == true) {
            if (predictedResult[msg.sender][escrowName] > oracleResult) {
                winner = msg.sender;
                loser = counterparty;
            } else {
                winner = counterparty;
                loser = msg.sender;
            }
        } else {
            if (predictedResult[msg.sender][escrowName] > oracleResult) {
                winner = counterparty;
                loser = msg.sender;
            } else {
                winner = msg.sender;
                loser = counterparty;
            }
        }
        uint256 winnings = betVal[msg.sender][escrowName].add(betVal[counterparty][escrowName]).sub(oraclize_getPrice("URL")); // Subtract the Oraclize cost
                                                                                                                               // TODO: test this
        uninitialize(escrowName, counterparty, "over");  // Uninitialize variables

        winner.transfer(winnings);
        LogWinner(winner, winnings, escrowName, predictedResult[winner][escrowName], predictedResultCondition[winner][escrowName], oracleResult);
        LogLoser(loser, escrowName, predictedResult[loser][escrowName], predictedResultCondition[loser][escrowName], oracleResult);
    }

    /// @dev Cancel the escrow before it has begun. Requires just one party. Returns funds.
    /// @param escrowName Name of the escrow
    /// @param counterparty The address of the person who is partaking in the escrow
    function cancelPreEscrow(bytes32 escrowName, address counterparty) public {
        require(betVal[msg.sender][escrowName] != 0);                 // Party must have funds in the contract for thisbet
        require(escrowInitializing[msg.sender][escrowName] == true);  // Escrow of this name with this party has to be in the initializing state
        require(escrowOngoing[msg.sender][escrowName] == false);      // Escrow of this name with this party has to not be ongoing
        require(escrowOver[msg.sender][escrowName] == false);         // Escrow of this name with this party has to not be over

        uint256 ethToReturn = betVal[msg.sender][escrowName];         // Calculate value to return
        uninitialize(escrowName, counterparty, "before");             // Uninitialize variables


        msg.sender.transfer(ethToReturn);  // Return ETH to the appropriate party
        CancelEscrow(msg.sender, counterparty, escrowName, endTime[msg.sender][escrowName], "before");
    }

    /// @dev Cancel the escrow while it is ongoing. Requires both parties. Returns funds.
    /// @param escrowName Name of the escrow
    /// @param counterparty The address of the person who is partaking in the escrow
    function cancelDuringEscrow(bytes32 escrowName, address counterparty) public {
        require(block.timestamp < endTime[msg.sender][escrowName]);     // Escrow must be ongoing
        require(escrowInitializing[msg.sender][escrowName] == true);    // Escrow must have been initiated
        require(escrowInitializing[counterparty][escrowName] == true);  // Escrow must have been initiated
        require(escrowOngoing[msg.sender][escrowName] == true);         // Escrow must be ongoing
        require(escrowOngoing[counterparty][escrowName] == true);       // Escrow must be ongoing

        desiredCancelDuring[msg.sender][escrowName] == true;  // Signal the cancellation

        if (desiredCancelDuring[msg.sender][escrowName] == true && desiredCancelDuring[counterparty][escrowName] == true) {
            uint256 ethToReturnParty = betVal[msg.sender][escrowName];
            uint256 ethToReturnCounterparty = betVal[counterparty][escrowName];
            uninitialize(escrowName, counterparty, "during");  // Uninitialize variables

            msg.sender.transfer(ethToReturnParty);             // Return ETH to the respective counterparty
            counterparty.transfer(ethToReturnCounterparty);    // Return ETH to the respective counterparty
            CancelEscrow(msg.sender, counterparty, escrowName, endTime[msg.sender][escrowName], "during");
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
            uninitialize(escrowName, counterparty, "over");  // Uninitialize variables

            msg.sender.transfer(ethToReturnParty);           // Return ETH to the respective counterparty
            counterparty.transfer(ethToReturnCounterparty);  // Return ETH to the respective counterparty
            CancelEscrow(msg.sender, counterparty, escrowName, endTime[msg.sender][escrowName], "after");
        }
    }

    function uninitialize(bytes32 escrowName, address counterparty, string state) internal {
        escrowInitializing[msg.sender][escrowName] = false;          // Return escrowInitializing to uninitialized state
        betVal[msg.sender][escrowName] = 0;                          // Return betVal to uninitialized state
        betVal[counterparty][escrowName] = 0;                        // Return betVal to uninitialized state
        endTime[msg.sender][escrowName] = 0;                         // Return endTimestamp to uninitialized state
        endTime[counterparty][escrowName] = 0;                       // Return endTimestamp to uninitialized state
        predictedResult[msg.sender][escrowName] = 0;                 // Return predictedResult to uninitialized state
        predictedResult[counterparty][escrowName] = 0;               // Return predictedResult to uninitialized state
        predictedResultCondition[msg.sender][escrowName] = false;    // Return predictedResultCondition to uninitialized state
        predictedResultCondition[counterparty][escrowName] = false;  // Return predictedResultCondition to uninitialized state
        // TODO: Use stringutils lib
        if (keccak256(state) == keccak256("during")) {
            escrowInitializing[counterparty][escrowName] = false;    // Return escrowInitializing to uninitialized state
            escrowOngoing[msg.sender][escrowName] = false;           // Return escrowInitializing to uninitialized state
            escrowOngoing[counterparty][escrowName] = false;         // Return escrowInitializing to uninitialized state
            desiredCancelDuring[msg.sender][escrowName] == false;    // Return desiredCancelDuring to uninitialized state
            desiredCancelDuring[counterparty][escrowName] == false;  // Return desiredCancelDuring to uninitialized state
        }
        if (keccak256(state) == keccak256("over")) {
            escrowInitializing[counterparty][escrowName] = false;    // Return escrowInitializing to uninitialized state
            escrowOngoing[msg.sender][escrowName] = false;           // Return escrowInitializing to uninitialized state
            escrowOngoing[counterparty][escrowName] = false;         // Return escrowInitializing to uninitialized state
            escrowOver[msg.sender][escrowName] = false;              // Return escrowOver to uninitialized state
            escrowOver[counterparty][escrowName] = false;            // Return escrowOver to uninitialized state
            desiredCancelDuring[msg.sender][escrowName] == false;    // Return desiredCancelDuring to uninitialized state
            desiredCancelDuring[counterparty][escrowName] == false;  // Return desiredCancelDuring to uninitialized state
        }
    }

    /// @dev Retrieves the oracle result for the specified escrow
    /// @notice This is a public function and is meant to be used to test the URL before actually creating an escrow
    /// @param oracleURL URL to get the oracle result from
    function getOracleResult(string oracleURL) internal returns(uint256) {
        if (oraclize_getPrice("URL") > this.balance) {
            newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            oraclize_query("URL", oraclizeURL);
        }
    }
}
