# RAISEBOX_FAUCET

## Token Information
- **Token Name:** RAISEBOX TOKEN  
- **Token Symbol:** RB  

## Faucet Overview
The RaiseBox Faucet allows testers of the RaiseBox contract to obtain **test tokens** for testing purposes.

### Sepolia ETH Drip
- First-time interactors with this faucet contract also receive a **Sepolia ETH drip of 0.01 ETH** alongside faucet tokens.  
- The Sepolia ETH drip is intended to enable future users of the contract to test the functionalities of the token and the contract.

### Faucet Rules
- Testers can only request tokens from this faucet **once every 3 days (72 hours)**.  
- There is a **minimum withdrawal amount of 1000 tokens**,for each request.  
- Only the **faucet owner** can mint or burn tokens. The contract ensures that there is always enough token balance to satisfy requested withdrawals.

### Donations
- Users can **donate Sepolia ETH** to this contract. These donations are used to fund the Sepolia ETH drip function.  
- Donations are appreciated and can be sent either **directly** or via **external contracts** to this contract.

## Faucet Contract Functions

| Function | Visibility | Description |
|----------|------------|-------------|
| `constructor(uint256 _faucetDrip, uint256 _dailyClaimLimit, uint256 _sepEthAmountToDrip, uint256 _dailyEthCap)` | public | Initializes faucet parameters with configurable values instead of hardcoded constants. |
| `requestTokens()` | public | Allows a user to claim faucet tokens and Sepolia ETH drip, enforcing claim limits and cooldowns. |
| `donateEth()` | public payable | Lets users donate Sepolia ETH to fund the ETH drip pool. |
| `mint(address to, uint256 amount)` | onlyOwner | Mints new tokens, restricted to the contract owner. |
| `burn(address from, uint256 amount)` | onlyOwner | Burns tokens from a specified address, restricted to the owner. |
| `withdrawEth(address payable to, uint256 amount)` | onlyOwner | Withdraws Sepolia ETH from the contract to a given address. |
| `setFaucetDrip(uint256 _faucetDrip)` | onlyOwner | Updates the faucet token drip amount. |
| `setDailyClaimLimit(uint256 _dailyClaimLimit)` | onlyOwner | Updates the daily token claim limit. |
| `setSepEthAmountToDrip(uint256 _sepEthAmountToDrip)` | onlyOwner | Updates the Sepolia ETH drip amount per claim. |
| `setDailyEthCap(uint256 _dailyEthCap)` | onlyOwner | Updates the daily Sepolia ETH drip cap. |
