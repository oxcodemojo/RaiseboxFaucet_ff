// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.30;
import {Test, console} from "../lib/forge-std/src/Test.sol";
import {MyFaucet} from "../src/CrowdfundFaucet.sol";

contract TestFaucet is Test {
    MyFaucet myFaucet ;

    address owner;
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    // create users to interact with token

    function setUp() public {
        myFaucet = new MyFaucet("crowdfundtoken", "CFT");
        owner = address(this);
        vm.warp(1 days); // atleast a day paases before user can withdraw from faucet again... // for testing environment since this returns 1 for blocktimestamp
    }

    function testMint() public {
        vm.prank(owner);
        myFaucet.mintTokensToFaucet(1000000);

        assertEq(myFaucet.totalSupply(), 1000000);
        assertEq(myFaucet.balanceOf(address(myFaucet)), 1000000);

    }

    function testWithdrawal() public {

       vm.prank(owner);
       myFaucet.mintTokensToFaucet(1000 ether);
        
       vm.prank(user1);
       myFaucet.withdrawTokenFromFaucet(user1);

       assertEq(myFaucet.balanceOf(user1), myFaucet.WITHDRAWAL_AMOUNT());

       vm.prank(user2);
       myFaucet.withdrawTokenFromFaucet(user2);

       assertEq(myFaucet.balanceOf(user2), myFaucet.WITHDRAWAL_AMOUNT());

       console.log(myFaucet.balanceOf(address(myFaucet)));
       console.log(myFaucet.balanceOf(user1));
       console.log(myFaucet.balanceOf(user2));
       console.log(block.timestamp);

       

    }


}





    

