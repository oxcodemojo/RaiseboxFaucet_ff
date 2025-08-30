//SPDX-Lincense-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RaiseBoxFaucet is ERC20, Ownable {
    // state variables....

    mapping(address => uint256) private lastClaimTime;
    mapping(address => bool) private hasClaimedEth;

    uint256 public constant CLAIM_COOLDOWN = 3 days;

    uint256 public constant DAILY_CLAIM_LIMIT = 100;

    uint256 public constant FAUCET_DRIP = 1000 * 10 ** 18; // assuming 18 decimals... 1k tokens

    uint256 public constant INITIAL_SUPPLY = 1000000000 * 10 ** 18;

    uint256 public lastDripDay;

    uint256 public dailyDrips;

    bool public sepEthDripsPaused;

    uint256 public dailyClaimCount;

    address private raiseBoxFaucetOwner;

    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        raiseBoxFaucetOwner = msg.sender;
        _mint(address(this), INITIAL_SUPPLY); // mint initial suppply to contract on deployment
    }

    // EVENTS

    event SepEthDripped(address indexed claimant, uint256 amount);
    event SepEthDripSkipped(address indexed claimant, string reason);
    event SepEthRefilled(address indexed refiller, uint256 amount);
    event SepEthDonated(address indexed donor, uint256 amount);
    event SepEthDripsPaused(bool paused);

    event Claimed(address indexed user, uint256 amount);
    event MintedNewFaucetTokens(address indexed user, uint256 amount);

    //ERRORS

    error RaiseBoxFaucet_EthTransferFailed();
    error RaiseBoxFaucet_CannotClaimAnymoreFaucetToday();
    error RaiseBoxFaucet_FaucetNotOutOfTokens();
    error RaiseBoxFaucet_MiningToNonContractAddressFailed();

    // CLAAIM ERRORS

    error RaiseBoxFaucet_ClaimCooldownOn();
    error RaiseBoxFaucet_OwnerOrZeroOrContractAddressCannotCallClaim();
    error RaiseBoxFaucet_DailyClaimLimitReached();
    error RaiseBoxFaucet_InsufficientContractBalance();

    // MODIFIERS

    // mint new tokens
    function mintFaucetTokens(address to, uint256 amount) public onlyOwner {
        if (to != address(this)) {
            revert RaiseBoxFaucet_MiningToNonContractAddressFailed();
        }

        if (balanceOf(address(to)) > 1000 * 10 ** 18) {
            revert RaiseBoxFaucet_FaucetNotOutOfTokens();
        }

        _mint(to, amount);

        emit MintedNewFaucetTokens(to, amount);
    }

    // burn tokens...
    function burnFaucetTokens(uint256 amountToBurn) public onlyOwner {
        require(
            amountToBurn >= balanceOf(address(this)),
            "Faucet Token Balance: Insufficient"
        );

        // transfer faucet balance to owner first before burning
        // ensures owner has a balance before _burn (owner only function) can be called successfully
        _transfer(address(this), msg.sender, balanceOf(address(this)));

        _burn(msg.sender, amountToBurn);
    }

    // claim tokens
    /// @notice SENDS BOTH FAUCET TOKENS AND SEP ETH (TO FIRST TIME USERS) IN ONE TRANSACTION OR CALL
    /// @notice Allows users to claim tokens with a cooldown period
    /// @notice Drips 0.005 sepolia ether to first time claimers
    /// @notice sepolia drip is to serve as gas when using faucet tokens to interact with crowdfund contract
    /// @dev Transfers tokens directly from contract, checks balance and caller, follows Checks-Effects-Interactions

    function claimFaucetTokens() public {
        // Checks
        address faucetClaimer = msg.sender;

        (lastClaimTime[faucetClaimer] == 0);

        if (block.timestamp < (lastClaimTime[faucetClaimer] + CLAIM_COOLDOWN)) {
            revert RaiseBoxFaucet_ClaimCooldownOn();
        }

        if (
            faucetClaimer == address(0) ||
            faucetClaimer == address(this) ||
            faucetClaimer == raiseBoxFaucetOwner
        ) {
            revert RaiseBoxFaucet_OwnerOrZeroOrContractAddressCannotCallClaim();
        }

        if (balanceOf(address(this)) <= FAUCET_DRIP) {
            revert RaiseBoxFaucet_InsufficientContractBalance();
        }

        if (dailyClaimCount > DAILY_CLAIM_LIMIT) {
            revert RaiseBoxFaucet_DailyClaimLimitReached();
        }

        // drip sepolia eth to first time claimers if supply hasn't ran out or sepolia drip not paused**
        // still checks
        if (!hasClaimedEth[faucetClaimer] && !sepEthDripsPaused) {
            uint256 currentDay = block.timestamp / 24 hours;

            if (currentDay > lastDripDay) {
                lastDripDay = currentDay;
                dailyDrips = 0;
                dailyClaimCount = 0;
            }

            uint256 sepEthAmountToDrip = 0.01 ether;

            if (
                dailyDrips + sepEthAmountToDrip <= 1 ether &&
                address(this).balance >= sepEthAmountToDrip
            ) {
                hasClaimedEth[faucetClaimer] = true;
                dailyDrips += sepEthAmountToDrip;

                (bool success, ) = faucetClaimer.call{
                    value: sepEthAmountToDrip
                }("");

                if (success) {
                    emit SepEthDripped(faucetClaimer, sepEthAmountToDrip);
                } else {
                    revert RaiseBoxFaucet_EthTransferFailed();
                }
            } else {
                emit SepEthDripSkipped(
                    faucetClaimer,
                    address(this).balance < sepEthAmountToDrip
                        ? "Faucet out of ETH"
                        : "Daily ETH cap reached"
                );
            }
        }

        // Effects

        lastClaimTime[faucetClaimer] = block.timestamp;
        dailyClaimCount++;

        // Interactions
        _transfer(address(this), faucetClaimer, FAUCET_DRIP);

        emit Claimed(msg.sender, FAUCET_DRIP);
    }

    function refillSepEth(uint256 amountToRefill) external payable onlyOwner {

        require(amountToRefill > 0, "invalid eth amount");

        require(
            msg.sender.balance >= amountToRefill,
            "Sep Eth Balance: Insufficient"
        );

        require(
            msg.value == amountToRefill,
            "Refill amount must be same as value sent."
        );

        emit SepEthRefilled(msg.sender, amountToRefill);
    }

    function toggleEthDripPause(bool _paused) external onlyOwner {
        sepEthDripsPaused = _paused;

        emit SepEthDripsPaused(_paused);
    }

    receive() external payable {
        emit SepEthDonated(msg.sender, msg.value);
    }

    fallback() external payable {
        emit SepEthDonated(msg.sender, msg.value);
    }

    // GETTER FUNCTIONS

    function getBalance(address user) public view returns (uint256) {
        return balanceOf(user);
    }

    function getHasClaimedEth(address user) public view returns (bool) {
        return hasClaimedEth[user];
    }

    function getUserLastClaimTime(address user) public view returns (uint256) {
        return lastClaimTime[user];
    }

    function getFaucetTotalSupply() public view returns (uint256) {
        return balanceOf(address(this));
    }

    function getContractSepEthBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getOwner() public view returns (address) {
        // return  owner();
        return raiseBoxFaucetOwner;
    }
}
