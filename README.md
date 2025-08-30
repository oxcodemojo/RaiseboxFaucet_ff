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
