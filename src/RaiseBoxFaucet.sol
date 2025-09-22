// SPDX-Lincense-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RaiseBoxFaucet is ERC20, Ownable {
    // state variables....

    mapping(address => uint256) private lastClaimTime;
    mapping(address => bool) private hasClaimedEth;

    address public faucetClaimer;

    uint256 public constant CLAIM_COOLDOWN = 3 days;

    uint256 public dailyClaimLimit = 100;

    // minted on deploy via constructor
    uint256 public constant INITIAL_SUPPLY = 1000000000 * 10 ** 18;

    uint256 public constant TOKEN_BALANCE_THRESHOLD = 1000 * 10 ** 18;

    //= 1000 * 10 ** 18;
    // assuming 18 decimals
    uint256 public faucetDrip;

    uint256 public lastDripDay;

    uint256 public lastFaucetDripDay;

    uint256 public dailyDrips;

    string public tokenName;

    string public tokenSymbol;

    // Sep Eth drip for first timer claimers = 0.01 ether;
    uint256 public sepEthAmountToDrip;

    bool public sepEthDripsPaused;

    uint256 public dailyClaimCount;

    uint256 public dailySepEthCap;

    uint256 public blockTime = block.timestamp;

    // -----------------------------------------------------------------------
    // CONSTRUCTOR
    // -----------------------------------------------------------------------

    /// @param name_ Name of the ERC20 token
    /// @param symbol_ Symbol of the ERC20 token
    /// @param faucetDrip_ Number of tokens dispensed per claim
    /// @param sepEthDrip_ Amount of Sepolia ETH dripped per first-time claim
    /// @param dailySepEthCap_ Maximum Sepolia ETH distributed per day

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 faucetDrip_,
        uint256 sepEthDrip_,
        uint256 dailySepEthCap_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        tokenName = name_;
        tokenSymbol = symbol_;
        faucetDrip = faucetDrip_;
        sepEthAmountToDrip = sepEthDrip_;
        dailySepEthCap = dailySepEthCap_;

        _mint(address(this), INITIAL_SUPPLY); // mint initial supply to contract on deployment
    }

    // -----------------------------------------------------------------------
    // EVENTS
    // -----------------------------------------------------------------------

    event SepEthDripped(address indexed claimant, uint256 amount);
    event SepEthDripsSkipped(address indexed claimant, string reason);
    event SepEthDripsRefilled(address indexed refiller, uint256 amount);
    event SepEthDonated(address indexed donor, uint256 amount);
    event SepEthDripsPaused(bool paused);
    event SepEthDripsStateToggled(bool toggle);

    event ClaimedTokens(address indexed user, uint256 amountClaimed);
    event MintedNewFaucetTokens(address indexed user, uint256 amount);
    event BurntFaucetTokens(uint256 amountBurnt);
    event DailyClaimLimitAdjusted(uint256 amountAdjusted);

    // -----------------------------------------------------------------------
    // ERRORS:
    // ERRORS ANATOMY: CONTRACT_FUNCTION_ERRORNAME
    // -----------------------------------------------------------------------

    error RaiseBoxFaucet_ClaimFaucetTokens_EthTransferFailed();
    error RaiseBoxFaucet_CannotClaimAnymoreFaucetToday();
    error RaiseBoxFaucet_MintFaucetToken_FaucetNotOutOfToken();
    error RaiseBoxFaucet_MintFaucetToken_MiningToNonContractAddressFailed();

    error RaiseBoxFaucet_AdjustDailyClaimLimit_CurrentClaimLimitIsLessThanBy();

    // CLAIM ERRORS

    error RaiseBoxFaucet_ClaimFaucetTokens_ClaimCooldownOn();
    error RaiseBoxFaucet_ClaimFaucetTokens_OwnerOrZeroOrContractAddressCannotCallClaim();
    error RaiseBoxFaucet_ClaimFaucetTokens_DailyClaimLimitReached();
    error RaiseBoxFaucet_ClaimFaucetTokens_InsufficientContractBalance();

    // -----------------------------------------------------------------------
    // OWNER FUNCTIONS
    // -----------------------------------------------------------------------

    /// @notice Mints new faucet tokens to the contract
    /// @dev Can only mint to the contract itself
    /// @param to Address that will receive minted tokens (must be the contract itself)
    /// @param amount Number of tokens to mint
    /// @notice TOKEN_BALANCE_THRESHOLD Minimum faucet balance before minting new tokens can happen

    function mintFaucetTokens(address to, uint256 amount) public onlyOwner {
        if (to != address(this)) {
            revert RaiseBoxFaucet_MintFaucetToken_MiningToNonContractAddressFailed();
            // RaiseBoxFaucet_MintFaucetToken_MiningToNonContractAddressFailed();
        }

        if (balanceOf(address(to)) > TOKEN_BALANCE_THRESHOLD) {
            revert RaiseBoxFaucet_MintFaucetToken_FaucetNotOutOfToken();
        }

        _mint(to, amount);

        emit MintedNewFaucetTokens(to, amount);
    }

    /// @notice Burns faucet tokens held by the contract
    /// @dev Transfers tokens to owner first, then burns from owner
    /// @param amountToBurn Amount of tokens to burn

    function burnFaucetTokens(uint256 amountToBurn) public onlyOwner {
        require(amountToBurn <= balanceOf(address(this)), "Cannot burn more than contract balance");

        _burn(address(this), amountToBurn);

        emit BurntFaucetTokens(amountToBurn);

        // try something bugy with the burn function
    }

    /// @notice Adjust the daily claim limit for the contract
    /// @dev Increases or decreases the `dailyClaimLimit` by the given amount
    /// @param by The amount to adjust the `dailyClaimLimit` by
    /// @param increaseClaimLimit Set to true to increase, false to decrease

    function adjustDailyClaimLimit(uint256 by, bool increaseClaimLimit) public onlyOwner {
        if (increaseClaimLimit) {
            dailyClaimLimit += by;
        } else {
            if (by > dailyClaimLimit) {
                revert RaiseBoxFaucet_AdjustDailyClaimLimit_CurrentClaimLimitIsLessThanBy();
            }
            dailyClaimLimit -= by;
        }

        emit DailyClaimLimitAdjusted(by);
    }

    // claim tokens
    /// @notice Claims faucet tokens and optionally Sepolia ETH (for first-time claimers)
    /// @notice Allows users to claim tokens with a cooldown period
    /// @notice Drips 0.01 sepolia ether to first time claimers
    /// @notice sepolia drip is to serve as gas when using faucet tokens to interact with crowdfund contract
    /// @dev Enforces cooldown, claim limits, daily ETH caps. Uses Checks-Effects-Interactions.
    /// @dev Transfers tokens directly from contract, checks balance and caller, follows Checks-Effects-Interactions

    function claimFaucetTokens() public {
        // Checks
        faucetClaimer = msg.sender;

        // (lastClaimTime[faucetClaimer] == 0);

        if (block.timestamp < (lastClaimTime[faucetClaimer] + CLAIM_COOLDOWN)) {
            revert RaiseBoxFaucet_ClaimFaucetTokens_ClaimCooldownOn();
        }

        if (faucetClaimer == address(0) || faucetClaimer == address(this) || faucetClaimer == Ownable.owner()) {
            revert RaiseBoxFaucet_ClaimFaucetTokens_OwnerOrZeroOrContractAddressCannotCallClaim();
        }

        if (balanceOf(address(this)) <= faucetDrip) {
            revert RaiseBoxFaucet_ClaimFaucetTokens_InsufficientContractBalance();
        }

        if (dailyClaimCount >= dailyClaimLimit) {
            revert RaiseBoxFaucet_ClaimFaucetTokens_DailyClaimLimitReached();
        }

        // drip sepolia eth to first time claimers if supply hasn't ran out or sepolia drip not paused**
        // still checks
        if (!hasClaimedEth[faucetClaimer] && !sepEthDripsPaused) {
            uint256 currentDay = block.timestamp / 24 hours;

            if (currentDay > lastDripDay) {
                lastDripDay = currentDay;
                dailyDrips = 0;
            }

            if (dailyDrips + sepEthAmountToDrip <= dailySepEthCap && address(this).balance >= sepEthAmountToDrip) {
                hasClaimedEth[faucetClaimer] = true;
                dailyDrips += sepEthAmountToDrip;

                (bool success,) = faucetClaimer.call{value: sepEthAmountToDrip}("");

                if (success) {
                    emit SepEthDripped(faucetClaimer, sepEthAmountToDrip);
                } else {
                    revert RaiseBoxFaucet_ClaimFaucetTokens_EthTransferFailed();
                }
            } else {
                emit SepEthDripsSkipped(
                    faucetClaimer,
                    address(this).balance < sepEthAmountToDrip ? "Faucet out of ETH" : "Daily ETH cap reached"
                );
            }
        } else {
            dailyDrips = 0;
        }

        /**
         * @param lastFaucetDripDay tracks the last day a claim was made
         * @notice resets the @param dailyClaimCount every 24 hours
         */
        if (block.timestamp > lastFaucetDripDay + 1 days) {
            lastFaucetDripDay = block.timestamp;
            dailyClaimCount = 0;
        }

        // Effects

        lastClaimTime[faucetClaimer] = block.timestamp;
        dailyClaimCount++;

        // Interactions
        _transfer(address(this), faucetClaimer, faucetDrip);

        emit ClaimedTokens(msg.sender, faucetDrip);
    }

    /// @notice Refill Sepolia ETH into the faucet contract
    /// @param amountToRefill Amount of ETH being refilled (must equal msg.value)
    function refillSepEth(uint256 amountToRefill) external payable onlyOwner {
        require(amountToRefill > 0, "invalid eth amount");

        require(msg.value == amountToRefill, "Refill amount must be same as value sent.");

        emit SepEthDripsRefilled(msg.sender, amountToRefill);
    }

    /// @notice Pauses or unpauses Sepolia ETH drips
    /// @param _paused True to pause, false to resume
    function toggleEthDripPause(bool _paused) external onlyOwner {
        sepEthDripsPaused = _paused;

        emit SepEthDripsStateToggled(_paused);
    }

    // -----------------------------------------------------------------------
    // DONATION HANDLERS
    // -----------------------------------------------------------------------

    /// @notice Accept ETH donations via `receive`
    receive() external payable {
        emit SepEthDonated(msg.sender, msg.value);
    }

    /// @notice Accept ETH donations via `fallback`
    fallback() external payable {
        emit SepEthDonated(msg.sender, msg.value);
    }

    // -----------------------------------------------------------------------
    // GETTER FUNCTIONS
    // -----------------------------------------------------------------------

    /// @param user Address to query token balance for
    /// @return ERC20 balance of the user
    function getBalance(address user) public view returns (uint256) {
        return balanceOf(user);
    }

    function getClaimer() public view returns (address) {
        return faucetClaimer;
    }

    /// @param user Address to query ETH claim status for
    /// @return True if user has already claimed ETH
    function getHasClaimedEth(address user) public view returns (bool) {
        return hasClaimedEth[user];
    }

    /// @param user Address to query last claim time for
    /// @return Timestamp of user’s last claim
    function getUserLastClaimTime(address user) public view returns (uint256) {
        return lastClaimTime[user];
    }

    /// @return Current token balance of the faucet contract
    function getFaucetTotalSupply() public view returns (uint256) {
        return balanceOf(address(this));
    }

    /// @return Current Sepolia ETH balance of the faucet contract
    function getContractSepEthBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /// @return The raisebox faucet owner address
    function getOwner() public view returns (address) {
        return Ownable.owner();
    }
}
