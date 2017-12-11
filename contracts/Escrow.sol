pragma solidity ^0.4.15;


contract Escrow {
    function Escrow() public {}

    /// @dev Start an escrow. The creator must define the counterparty
    /// @param escrowName Name of the escrow
    /// @param counterparty The address of the person who is completing the escrow
    /// @param endTime Unix timestamp of the desired end of the contract
    /// @param multiplier Multiplier for the bet. Can be positive or negative
    /// @param oracleAddress Contract address that provides the result of the bet via an oracle
    function startEscrow() public payable {
    }

    /// @dev Counterparty calls this function to complete their side of the escrow contract
    /// @param escrowName Name of the escrow
    function finalizeEscrow() public payable {

    }

    /// @dev Retrieves the oracle result for the specified escrow
    /// @param escrowName Name of the escrow
    /// @param oracleURL URL to get the oracle result from
    function getOracleResult() internal {

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


}
