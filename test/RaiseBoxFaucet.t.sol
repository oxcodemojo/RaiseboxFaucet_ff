// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.30;
import {Test, console} from "../lib/forge-std/src/Test.sol";
import {RaiseBoxFaucet} from "../src/RaiseBoxFaucet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DeployRaiseboxContract} from "../script/DeployRaiseBox.s.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestRaiseBoxFaucet is Test {
    RaiseBoxFaucet raiseBoxFaucet;
    DeployRaiseboxContract raiseBoxDeployer;

    // address owner = address(0x0);
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
    address raiseBoxFaucetContract;

    // test constants
    uint256 public constant FAUCET_DRIP = 1000 * 10 ** 18;
    uint256 public constant INITIAL_SUPPLY_MINTED = 1000000000 * 10 ** 18;

    // create users to interact with token

    function setUp() public {
        owner = address(this);
        raiseBoxFaucet = new RaiseBoxFaucet("raiseboxtoken", "RB");
        raiseBoxFaucetContract = address(raiseBoxFaucet);
        raiseBoxDeployer = new DeployRaiseboxContract();

        vm.deal(raiseBoxFaucetContract, 1 ether);
        vm.deal(owner, 100 ether);
        vm.warp(3 days);
    }

    function testOnlyOwnerCanDeployRaiseBox() public {
        raiseBoxDeployer.run();
        RaiseBoxFaucet raiseBox = raiseBoxDeployer.contractAddress();
        assertEq(raiseBox.name(), "raiseboxfaucet");
        assertEq(raiseBox.symbol(), "RB");
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
        raiseBoxFaucet.mintFaucetTokens(raiseBoxFaucetContract, 200 * 10 ** 18);

        vm.prank(user1);
        vm.expectRevert();
        raiseBoxFaucet.mintFaucetTokens(raiseBoxFaucetContract, 100 * 10 ** 18);
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
            raiseBoxFaucetContract,
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
        uint256 amountOfFaucetTokensPerClaim = raiseBoxFaucet.FAUCET_DRIP();

        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();
        assertEq(
            raiseBoxFaucet.getBalance(user1),
            amountOfFaucetTokensPerClaim
        );

        //Simulate cooldown passing...
        vm.warp(6 days);
        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();
        assertEq(
            raiseBoxFaucet.getBalance(user1),
            amountOfFaucetTokensPerClaim * 2
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
            "User2 faucet balance is greater than since user2 has claimed twice now"
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
            FAUCET_DRIP,
            "user 1 should receive 1000 faucet tokens"
        );
        assertEq(
            address(user1).balance,
            0.01 ether,
            "user 1 should receive 0.01 ether"
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
            "RB"
        );
        // this contract instance has no sep eth in it balance

        vm.prank(user1);
        testRaiseBoxContract.claimFaucetTokens();

        assertEq(
            testRaiseBoxContract.getBalance(user1),
            FAUCET_DRIP,
            "User1 received faucet tokens successfully"
        );
        assertEq(
            address(user1).balance,
            0,
            "No sep eth was dripped: Low balance"
        );
    }

    function testClaimIsSuccessfulForMultipleUsers() public {
        address[11] memory users = [
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

        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            raiseBoxFaucet.claimFaucetTokens();

            assertEq(address(users[i]).balance, 0.01 ether);
            assertEq(raiseBoxFaucet.getBalance(users[i]), FAUCET_DRIP);
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
            console.log(raiseBoxFaucet.getHasClaimedEth(users[i]));
            assertEq(
                claimed,
                true,
                "has Claimed Storage Not Successfully: claims not successfully"
            );
        }

        // test oneof the above users tries to claim faucet immediately after first claim
        vm.prank(user1);
        vm.expectRevert();
        raiseBoxFaucet.claimFaucetTokens();
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
            "contract supply should deplete by amount claimed by Us 1&2"
        );
    }

    // REFILL RELATED TESTS

    function testRefillSepEth() public {
        /**
         * @notice owner initial eth balance is 10, dealed during test setup
         */

        vm.prank(owner);
        raiseBoxFaucet.refillSepEth{value: 50 ether}(50 ether);
        assertTrue(owner.balance == 50 ether);
        console.log(owner.balance);

        // vm.prank(owner);
        // raiseBoxFaucet.refillSepEth{value: 2 ether}(2 ether);

        // assertTrue(address(raiseBoxFaucet).balance == 5 ether, "Contract sep eth balnce should be equal initial balance plus the refilled amount (1 + 2 ether)");
        // assertTrue(address(owner).balance == 6 ether, "Owner sep eth balance should deplete by a value of 2");
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

    function testContractRecievesDirectDeposits() public {
        vm.deal(user1, 10 ether);
        (bool success, ) = address(raiseBoxFaucet).call{value: 5 ether}("");

        assertTrue(success);
        assertEq(raiseBoxFaucetContract.balance, 6 ether, "Contract balance should increase: 5 ether sent by user1 + 1 ether initial balance");

        console.log(raiseBoxFaucetContract.balance);

    }

    function testGetBalanceReturnsCorrectBalance() public {
        vm.prank(owner);
        raiseBoxFaucet.getBalance(owner);

        assertTrue(raiseBoxFaucet.getBalance(owner) == 0, "ownwer should have zero faucet balance");

        vm.prank(user1);
        raiseBoxFaucet.getBalance(user1);

        assertTrue(raiseBoxFaucet.getBalance(user1) == 0, "user1 should have no balance");

        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();

        assertTrue(raiseBoxFaucet.getBalance(user1) > 0, "user1 balance should be greater than zero, claimed faucet tokens");
        assertEq(raiseBoxFaucet.getBalance(user1), FAUCET_DRIP, "user1 balance should be equal faucet_drip");


    }

    function testUserHasClaimedEth() public {
        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();

        assertTrue(raiseBoxFaucet.getHasClaimedEth(user1), "user should have claimed eth");

        vm.prank(owner);
        raiseBoxFaucet.toggleEthDripPause(true);

        vm.prank(user2);
        raiseBoxFaucet.claimFaucetTokens();

        assertTrue(raiseBoxFaucet.getHasClaimedEth(user2) == false, "eth drip paused: no eth should be dripped to user2");

    }


    function testUserLastClaimTimeUpdatesCorrectly() public {
        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();

        assertTrue(raiseBoxFaucet.getUserLastClaimTime(user1) == 3 days, "user last claim time should 3 days after deployment"); // just for this testing envionment

        vm.warp(6 days);
        vm.prank(user1);
        raiseBoxFaucet.claimFaucetTokens();
        assertTrue(raiseBoxFaucet.getUserLastClaimTime(user1) != 3 days, "user last claim time should be 6 days now");
    }
}
