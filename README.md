## escrow

This contract facilitates an escrow contract between two counterparties. Uses an oracle contract in order to finalize
the result.

### Features
- Multiple escrow instances can occur at once
- People can participate in multiple at once
- Customizable contracts (amount contributed, time range, etc.)
- Ability to end the contract at any point
- One-way bet (set `multipler` to 0)

## Assumptions
- The resolution of the bet is of type `uint256` and can be called via a simple URL
- One addresses cannot be in multiple escrows of the same name at one time
- The entire balance for each counterparty must be included in one transaction from each party
- The multiplier must be >0.1
- If you want to change the parameters of an escrow contract, cancel the existing one first, then recreate another one

### Future Features
- ERC20 compatibility
- Multiple type oracle returns and bets
- Terms Of Use
