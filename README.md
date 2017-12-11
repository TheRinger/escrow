## escrow

This contract facilitates an escrow contract between two counterparties. Uses an oracle contract in order to finalize
the result.

### Features
- Multiple escrow instances can occur at once
- People can participate in multiple at once
- Customizable contracts (amount contributed, time range, etc.)
- Ability to end the contract at any point

## Assumptions
- The resolution of the bet is of type `uint256` and can be called via a simple URL

### Future Features
- ERC20 compatibility
- Multiple type oracle returns
