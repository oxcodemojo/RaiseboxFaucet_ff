// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.30;

import {Test, console} from "../lib/lib/forge-std/src/Test.sol";
import {RaiseBoxFaucet} from "../src/RaiseBoxFaucet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DeployRaiseboxContract} from "../script/DeployRaiseBox.s.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestRaiseBoxFaucet is Test {
    RaiseBoxFaucet raiseBoxFaucet;
    DeployRaiseboxContract raiseBoxDeployer;

    // Test: Users
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");
    address user5 = makeAddr("user5");
    address user6 = makeAddr("user6");
    address user7 = makeAddr("user 7");
    address user8 = makeAddr("user 8");
    address user9 = makeAddr("user 9");
    address user10 = makeAddr("user 10");
    address user11 = makeAddr("user 11");
    address user12 = makeAddr("user 12");

    address owner;
    address raiseBoxFaucetContractAddress;

    // test constants
    uint256 public constant INITIAL_SUPPLY_MINTED = 1000000000 * 10 ** 18;

    /**
     * @dev Helper function to simulate time passing since testing environment doesn't work as expected
     * @param duration_ amount of time to advanced, could be in days, hours, minutes or seconds. default is seconds*
     */
    function advanceBlockTime(uint256 duration_) internal {
        vm.warp(duration_);
    }

    function setUp() public {
        owner = address(this);

        raiseBoxFaucet = new RaiseBoxFaucet(
            "raiseboxtoken",
            "RB",
            1000 * 10 ** 18,
            0.005 ether,
            0.5 ether
        );

        raiseBoxFaucetContractAddress = address(raiseBoxFaucet);

        raiseBoxDeployer = new DeployRaiseboxContract();

        vm.deal(raiseBoxFaucetContractAddress, 1 ether);
        vm.deal(owner, 100 ether);

        advanceBlockTime(3 days); // 3 days
    }

    function testFaucetBalanceIsAlwaysChecksum() public {
        address[5] memory claimers = [user1, user2, user3, user4, user5];
        uint256 userClaims;
        uint256 balanceLeft;

        for (uint256 i = 0; i < claimers.length; i++) {
            vm.prank(claimers[i]);
            raiseBoxFaucet.claimFaucetTokens();

            userClaims += raiseBoxFaucet.getBalance(claimers[i]);
            balanceLeft = (INITIAL_SUPPLY_MINTED - userClaims);
            console.log((balanceLeft + userClaims));

            assertTrue(INITIAL_SUPPLY_MINTED == (balanceLeft + userClaims));
        }
    }

    function testOnlyOwnerCanAdjustDailyClaimLimit() public {
        vm.prank(owner);
        raiseBoxFaucet.adjustDailyClaimLimit(1000, true);
        assertTrue(
            raiseBoxFaucet.dailyClaimLimit() == 1100,
            "Daily claim limit should be 1100"
        );

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        raiseBoxFaucet.adjustDailyClaimLimit(500, true);
    }

    function testadjustDailyClaimLimit() public {
        console.log(raiseBoxFaucet.dailyClaimLimit());

        vm.prank(owner);
        raiseBoxFaucet.adjustDailyClaimLimit(500, true);

        assertTrue(
            raiseBoxFaucet.dailyClaimLimit() == 600,
            "Daily claim  should increase by 500"
        );

        console.log(raiseBoxFaucet.dailyClaimLimit());

        vm.prank(owner);
        raiseBoxFaucet.adjustDailyClaimLimit(500, true);
        assertTrue(
            raiseBoxFaucet.dailyClaimLimit() == 1100,
            "Daily claim  should increase by 500"
        );

        console.log(raiseBoxFaucet.dailyClaimLimit());

        vm.prank(owner);
        raiseBoxFaucet.adjustDailyClaimLimit(500, false);
        assertTrue(
            raiseBoxFaucet.dailyClaimLimit() == 600,
            "Daily claim  should decrease by 500"
        );

        console.log(raiseBoxFaucet.dailyClaimLimit());

        vm.prank(owner);
        raiseBoxFaucet.adjustDailyClaimLimit(500, false);
        assertTrue(
            raiseBoxFaucet.dailyClaimLimit() == 100,
            "Daily claim  should decrease by 500"
        );

        console.log(raiseBoxFaucet.dailyClaimLimit());

        vm.prank(owner);
        vm.expectRevert();
        raiseBoxFaucet.adjustDailyClaimLimit(500, false);
        // assertTrue(
        //     raiseBoxFaucet.dailyClaimLimit() == 100,
        //     "Daily claim  should decrease by 500"
        // );

        console.log(raiseBoxFaucet.dailyClaimLimit());
    }

    function testOwnerCanMakeDirectSepEthDeposits() public {
        vm.prank(owner);
        (bool sentSuccess, ) = address(raiseBoxFaucet).call{value: 20 ether}(
            abi.encode("owner donated 20 ether to this contract")
        );

        assertTrue(owner.balance == 80 ether);
        assertTrue(address(raiseBoxFaucet).balance == 21 ether);

        vm.prank(raiseBoxFaucetContractAddress);
        (bool contractSentSuccess, ) = address(raiseBoxFaucet).call{
            value: 0.5 ether
        }(abi.encode("contract donated 0.5 ether to self"));

        assertTrue(owner.balance == 80 ether);
        assertTrue(
            raiseBoxFaucetContractAddress.balance == 21.0 ether,
            "contract cannot send sep eth to self, balance unchanged"
        );
    }

    function testOwnerIsDeployer() public {
        raiseBoxDeployer.run();
        RaiseBoxFaucet box = raiseBoxDeployer.raiseBox();
        assertEq(box.name(), "raiseboxtoken");
        assertEq(box.symbol(), "RB");
        // assertTrue(address(raiseBoxDeployer) == address(raiseBoxDeployer.raiseBox()));
    }

    // MINT RELATED TESTS

    function testMintFailsIfRecepientIsNotContract() public {
        vm.prank(owner);
        vm.expectRevert();
        raiseBoxFaucet.mintFaucetTokens(user1, 100 * 10 ** 18);
    }

    function testOnlyOwnerCanMintFaucetTokens() public {
        // balance have to be below a certain threshold before new tokens can be minted
        // burn function has to be called first
        // only owner can call burn
        vm.startPrank(owner);
        raiseBoxFaucet.burnFaucetTokens(INITIAL_SUPPLY_MINTED);
        vm.stopPrank();

        vm.prank(owner);
        raiseBoxFaucet.mintFaucetTokens(
            raiseBoxFaucetContractAddress,
            200 * 10 ** 18
        );

        vm.prank(user1);
        vm.expectRevert();
        raiseBoxFaucet.mintFaucetTokens(
            raiseBoxFaucetContractAddress,
            100 * 10 ** 18
        );
    }

    function testTotalSupplyUpdatesCorrectlyOnMint() public {
        uint256 contractInititalTokenSupply = raiseBoxFaucet
            .getFaucetTotalSupply();
        uint256 contractInitialSepEthSupply = raiseBoxFaucet
            .getContractSepEthBalance();

        vm.startPrank(owner);
        raiseBoxFaucet.burnFaucetTokens(INITIAL_SUPPLY_MINTED);
        vm.stopPrank();

        assertEq(
            raiseBoxFaucet.getFaucetTotalSupply(),
            0,
            "All faucet tokens have been burnt"
        );
        assertEq(
            raiseBoxFaucet.getContractSepEthBalance(),
            contractInitialSepEthSupply,
            "Sep Eth balance remains unchanged"
        );

        vm.prank(owner);
        raiseBoxFaucet.mintFaucetTokens(
            raiseBoxFaucetContractAddress,
            1000000 * 10 ** 18
        );

        uint256 contractFinalTokenSupply = raiseBoxFaucet
            .getFaucetTotalSupply();

        assertEq(
            raiseBoxFaucet.getFaucetTotalSupply(),
            contractFinalTokenSupply,
            "Current faucet balance should be equal to amount minted"
        );
        assertEq(
            raiseBoxFaucet.getContractSepEthBalance(),
            contractInitialSepEthSupply,
            "sep eth balance should remain unchanged since no new token was minted here"
        );
    }

    function testInitialSupplyMintedOnDeployment() public {
        assertEq(
            raiseBoxFaucet.getBalance(address(raiseBoxFaucet)),
            INITIAL_SUPPLY_MINTED
        );
    }

    // CLAIM RELATED TESTS

    function testUserClaimsExactWithdrawalAmountOfFaucetTokensPerClaim()
        public
    {
        // user receives 1000 faucet tokens on each claim
        uint256 amountOfFaucetTokensPerClaim = raiseBoxFaucet.faucetDrip();

        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();

        assertEq(
            raiseBoxFaucet.getBalance(user1),
            amountOfFaucetTokensPerClaim
        );

        //Simulate cooldown passing...

        vm.prank(user1);
        advanceBlockTime(block.timestamp + 3 days);
        raiseBoxFaucet.claimFaucetTokens();

        assertEq(
            raiseBoxFaucet.getBalance(user1),
            amountOfFaucetTokensPerClaim * 2,
            "User1 faucet balance must equal faucet drip * 2: second claim without spending"
        );

        vm.prank(user2);
        raiseBoxFaucet.claimFaucetTokens();

        assertEq(
            raiseBoxFaucet.getBalance(user2),
            amountOfFaucetTokensPerClaim,
            "User2 faucet balance must equal faucet drip"
        );

        vm.prank(user2);
        vm.expectRevert();
        raiseBoxFaucet.claimFaucetTokens();

        assertEq(
            raiseBoxFaucet.getBalance(user2),
            amountOfFaucetTokensPerClaim,
            "User2 second claim failed, balance remains unchanged"
        );
    }

    function testNewUserClaimsFaucetTokensAndEth() public {
        uint256 userInitialEthBalance = address(user1).balance;
        uint256 userInitialFaucetTokenBalance = raiseBoxFaucet.getBalance(
            user1
        );

        // claim is suppose to send both faucet tokens and eth to claimers
        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();
        assertEq(
            raiseBoxFaucet.getBalance(user1),
            raiseBoxFaucet.faucetDrip(),
            "user 1 should receive 1000 faucet tokens"
        );
        assertEq(
            address(user1).balance,
            0.005 ether,
            "user 1 should receive 0.005 ether"
        );

        assertTrue(
            address(user1).balance > userInitialEthBalance,
            "Final balance should greater, User1 received sep eth"
        );

        assertTrue(
            raiseBoxFaucet.getBalance(user1) > userInitialFaucetTokenBalance,
            "Final balance should be greater, User1 received faucet tokens"
        );
    }

    function testClaimDoesNotFailWhenSepEthBalanceIsLow() public {
        // this test checks to assert that claim suceeds even when sep eth balance is low
        // and no sep eth drips can be made along with faucet token drips
        RaiseBoxFaucet testRaiseBoxContract = new RaiseBoxFaucet(
            "raiseboxtoken",
            "RB",
            1000 * 10 ** 18,
            0.01 ether,
            1 ether
        );
        // this contract instance has no sep eth in it balance

        vm.prank(user1);
        testRaiseBoxContract.claimFaucetTokens();

        assertEq(
            testRaiseBoxContract.getBalance(user1),
            raiseBoxFaucet.faucetDrip(),
            "User1 received faucet tokens successfully"
        );
        assertEq(
            address(user1).balance,
            0,
            "No sep eth was dripped: Low balance"
        );
    }

    function testClaimIsSuccessfulForMultipleUsers() public {
        address[10] memory users = [
            user1,
            user2,
            user3,
            user4,
            user5,
            user6,
            user7,
            user8,
            user9,
            user10
        ];

        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            raiseBoxFaucet.claimFaucetTokens();

            assertEq(address(users[i]).balance, 0.005 ether);
            assertEq(
                raiseBoxFaucet.getBalance(users[i]),
                raiseBoxFaucet.faucetDrip()
            );
        }
    }

    function testUserHasClaimedEthStorageUpdatesCorrectlyOnClaim() public {
        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();
        bool claimed = raiseBoxFaucet.getHasClaimedEth(user1);
        assertEq(claimed, true, "User has not successfully claimed eth");
    }

    function testHasClaimedEthStorageUpdatesCorrectlyForMultipleClaimers()
        public
    {
        address[6] memory users = [user1, user2, user3, user4, user5, user6];

        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            raiseBoxFaucet.claimFaucetTokens();

            bool claimed = raiseBoxFaucet.getHasClaimedEth(users[i]);

            assertEq(
                claimed,
                true,
                "has Claimed Storage Not Successfully updated: claims not successfully"
            );
        }
    }

    function testSupplyDepletesAsUsersClaim() public {
        uint256 contractInitialBalance = raiseBoxFaucet.getFaucetTotalSupply();
        console.log(contractInitialBalance);

        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();

        vm.prank(user2);
        raiseBoxFaucet.claimFaucetTokens();

        uint256 totalClaimedByUser1AndUser2 = (raiseBoxFaucet.getBalance(
            user1
        ) + raiseBoxFaucet.getBalance(user2));

        uint256 contractFinalBalance = raiseBoxFaucet.getFaucetTotalSupply();

        assertEq(
            (contractInitialBalance - contractFinalBalance),
            totalClaimedByUser1AndUser2,
            "contract supply should deplete by amount claimed by Users 1&2"
        );
    }

    function testClaimsFailIfNonUsersTryToClaim() public {
        // Non users in this case:
        // 1. address(0)
        // 2. owner
        // 3. contract/contract address

        vm.prank(address(0));
        vm.expectRevert();
        raiseBoxFaucet.claimFaucetTokens();

        vm.prank(address(raiseBoxFaucet));
        vm.expectRevert();
        raiseBoxFaucet.claimFaucetTokens();

        vm.prank(owner);
        vm.expectRevert();
        raiseBoxFaucet.claimFaucetTokens();
    }

    // REFILL RELATED TESTS

    function testRefillSepEth() public {
        /**
         * @notice owner initial eth balance is 10, dealed during test setup
         */
        vm.prank(owner);
        raiseBoxFaucet.refillSepEth{value: 50 ether}(50 ether);
        assertTrue(owner.balance == 50 ether);
    }

    function testRefillFailsWhenNonOwnerCalls() public {
        vm.deal(user1, 3 ether);
        vm.prank(user1);
        vm.expectRevert();
        raiseBoxFaucet.refillSepEth{value: 3 ether}(3 ether);
    }

    function testOnlyOwnerCanRefillSepEth() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        vm.expectRevert();
        raiseBoxFaucet.refillSepEth{value: 2 ether}(2 ether);
    }

    function testZeroAddressAndContractCannotClaimFaucetTokens() public {
        vm.prank(address(0));
        vm.expectRevert();
        raiseBoxFaucet.claimFaucetTokens();

        vm.prank(address(raiseBoxFaucet));
        vm.expectRevert();
        raiseBoxFaucet.claimFaucetTokens();
    }

    // check vector:
    // does faucet still send eth after ethdrippause has been called

    function TestRaiseBoxFaucetPauseEthDripWhenEthPauseIsCalled() public {
        vm.prank(owner);
        raiseBoxFaucet.toggleEthDripPause(true);

        uint256 user1InitialEthBalance = address(user1).balance;
        console.log(user1InitialEthBalance);

        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();

        uint256 user1FinalEthBalance1 = address(user1).balance;
        console.log(user1FinalEthBalance1);

        assertTrue(
            user1InitialEthBalance == user1FinalEthBalance1,
            "ETH DRIP PAUSED: No eth dripped to user 1"
        );

        vm.prank(owner);
        raiseBoxFaucet.toggleEthDripPause(false);

        vm.warp(6 days);
        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();

        uint256 user1FinalEthBalance = address(user1).balance;
        console.log(user1FinalEthBalance);

        assertTrue(
            user1FinalEthBalance > user1InitialEthBalance,
            "ETH DRIP UNPAUSED: User1 final eth balance greater than initial"
        );
    }

    function testToggleSepEthDrip() public {
        vm.prank(owner);
        raiseBoxFaucet.toggleEthDripPause(true);
        assertTrue(raiseBoxFaucet.sepEthDripsPaused());

        vm.prank(owner);
        raiseBoxFaucet.toggleEthDripPause(false);
        assertFalse(raiseBoxFaucet.sepEthDripsPaused());
    }

    function testDailyClaimCountResetsAfter24Hours() public {
        address[11] memory faucetUsers = [
            user1,
            user2,
            user3,
            user4,
            user5,
            user6,
            user7,
            user8,
            user9,
            user10,
            user11
        ];

        for (uint256 i = 0; i < faucetUsers.length; i++) {
            vm.prank(faucetUsers[i]);
            raiseBoxFaucet.claimFaucetTokens();
        }

        advanceBlockTime(block.timestamp + 3 days);
        vm.prank(user3);
        raiseBoxFaucet.claimFaucetTokens();
        assertTrue(
            raiseBoxFaucet.dailyClaimCount() == 1,
            "Daily claim count should be 1 since it resets every 24 hours"
        );

        vm.prank(user12);
        raiseBoxFaucet.claimFaucetTokens();
        assertTrue(
            raiseBoxFaucet.dailyClaimCount() == 2,
            "Daily claim count should be 2: Two claims have been made today"
        );

        advanceBlockTime(block.timestamp + 3 days);
        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();
        assertEq(
            address(user1).balance,
            0.005 ether,
            "Ether balance of user1 should remain unchanged: Not first timer"
        );
        assertTrue(
            raiseBoxFaucet.dailyClaimCount() == 1,
            "Daily claim count should be 1: More than 24 hours passed"
        );
    }

    function testContractRecievesDirectDeposits() public {
        vm.deal(user1, 10 ether);
        (bool success, ) = address(raiseBoxFaucet).call{value: 5 ether}("");

        assertTrue(success);
        assertEq(
            raiseBoxFaucetContractAddress.balance,
            6 ether,
            "Contract balance should increase: 5 ether sent by user1 + 1 ether initial balance"
        );

        vm.prank(user1);
        (bool sent, ) = address(raiseBoxFaucet).call{value: 0 ether}(
            abi.encode("Donated Sep Eth to raisebox")
        );
        assertTrue(sent);
    }

    function testGetBalanceReturnsCorrectBalance() public {
        vm.prank(owner);
        raiseBoxFaucet.getBalance(owner);

        assertTrue(
            raiseBoxFaucet.getBalance(owner) == 0,
            "ownwer should have zero faucet balance"
        );

        vm.prank(user1);
        raiseBoxFaucet.getBalance(user1);

        assertTrue(
            raiseBoxFaucet.getBalance(user1) == 0,
            "user1 should have no balance"
        );

        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();

        assertTrue(
            raiseBoxFaucet.getBalance(user1) > 0,
            "user1 balance should be greater than zero, claimed faucet tokens"
        );
        assertEq(
            raiseBoxFaucet.getBalance(user1),
            raiseBoxFaucet.faucetDrip(),
            "user1 balance should be equal faucet_drip"
        );
    }

    function testUserHasClaimedEth() public {
        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();

        assertTrue(
            raiseBoxFaucet.getHasClaimedEth(user1),
            "user should have claimed eth"
        );

        vm.prank(owner);
        raiseBoxFaucet.toggleEthDripPause(true);

        vm.prank(user2);
        raiseBoxFaucet.claimFaucetTokens();

        assertTrue(
            raiseBoxFaucet.getHasClaimedEth(user2) == false,
            "eth drip paused: no eth should be dripped to user2"
        );
    }

    function testUserLastClaimTimeUpdatesCorrectly() public {
        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();

        assertTrue(
            raiseBoxFaucet.getUserLastClaimTime(user1) == 3 days,
            "user last claim time should 3 days after deployment"
        ); // just for this testing envionment

        vm.warp(6 days);
        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();
        assertTrue(
            raiseBoxFaucet.getUserLastClaimTime(user1) != 3 days,
            "user last claim time should be 6 days now"
        );
    }

    function testClaimCompleteFlow() public {
        vm.startPrank(user1);
        raiseBoxFaucet.claimFaucetTokens();

        assertTrue(
            block.timestamp == raiseBoxFaucet.getUserLastClaimTime(user1),
            "Last claim time: current block timestamp"
        );

        assertTrue(user1 != address(0), "user1 is not the zero address");

        assertTrue(user1 != raiseBoxFaucet.getOwner(), "user1 is not owner");

        assertTrue(
            user1 != raiseBoxFaucetContractAddress,
            "user1 is not contract"
        );

        assertTrue(
            raiseBoxFaucet.getBalance(raiseBoxFaucetContractAddress) >
                raiseBoxFaucet.faucetDrip(),
            "Contract shouls have enough faucet tokens"
        );

        assertTrue(
            raiseBoxFaucet.dailyClaimCount() < raiseBoxFaucet.dailyClaimLimit(),
            "Daily claim count must be less than daily claim limit of 100 claims"
        );

        assertTrue(
            raiseBoxFaucet.getHasClaimedEth(user1),
            "User1 has not claimed eth"
        );

        assertTrue(!raiseBoxFaucet.sepEthDripsPaused(), "Sep Eth drip is ON");

        assertTrue(
            raiseBoxFaucet.lastDripDay() != block.timestamp,
            "User1 last sep eth claim day should be today, current timestamp"
        );

        assertTrue(
            raiseBoxFaucet.dailyDrips() + raiseBoxFaucet.sepEthAmountToDrip() <
                address(raiseBoxFaucet).balance,
            "Contract Balance exceeded, top up sep eth"
        );

        assertTrue(
            address(raiseBoxFaucet).balance >
                raiseBoxFaucet.sepEthAmountToDrip(),
            "Contract Sep Eth balance is low"
        );

        assertTrue(
            raiseBoxFaucet.dailyDrips() == raiseBoxFaucet.sepEthAmountToDrip(),
            "Daily drip aount not updated successfully"
        );

        assertTrue(
            address(user1).balance == raiseBoxFaucet.sepEthAmountToDrip(),
            "User1 received No Sep Eth on claim"
        );

        assertTrue(
            raiseBoxFaucet.dailyDrips() != 0,
            "User1 claimed: Daily drip should be 0.005 ether"
        );

        assertTrue(
            raiseBoxFaucet.dailyClaimCount() != 0,
            "User1 claimed: Daily claim count should be 1"
        );

        assertTrue(
            block.timestamp != raiseBoxFaucet.lastFaucetDripDay() + 1,
            "Still in current day"
        );

        assertTrue(
            raiseBoxFaucet.getUserLastClaimTime(user1) == block.timestamp,
            "User1 last claim time should be current timestamp"
        );

        assertTrue(
            raiseBoxFaucet.dailyClaimCount() == 1,
            "Claim count did not Increase by 1"
        );

        assertTrue(
            raiseBoxFaucet.getBalance(user1) == raiseBoxFaucet.faucetDrip(),
            "User1 faucet token balance should equal 1000 $RB"
        );

        assertTrue(
            raiseBoxFaucet.getClaimer() == user1,
            "Claimer should be User1"
        );

        vm.stopPrank();
    }

    function testGetClaimer() public {
        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();

        assertTrue(
            user1 == raiseBoxFaucet.getClaimer(),
            "Claimer should be User1"
        );
    }

    function testGetHasClaimedEth() public {
        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();

        assertTrue(
            raiseBoxFaucet.getHasClaimedEth(user1),
            "User1 has not claimed Sep Eth"
        );
    }

    function testGetTotalSupply() public {
        assertTrue(
            raiseBoxFaucet.getFaucetTotalSupply() == INITIAL_SUPPLY_MINTED,
            "Total supply should be equal to Intial supply minted"
        );

        vm.prank(owner);
        raiseBoxFaucet.burnFaucetTokens(INITIAL_SUPPLY_MINTED);

        assertTrue(
            raiseBoxFaucet.getFaucetTotalSupply() == 0,
            "Token Burn: Supply should be zero"
        );

        vm.prank(owner);
        raiseBoxFaucet.mintFaucetTokens(
            raiseBoxFaucetContractAddress,
            INITIAL_SUPPLY_MINTED
        );
        assertTrue(
            raiseBoxFaucet.getFaucetTotalSupply() != 0,
            "Token Mint: Supply should equal amount minted"
        );
    }
}
