//SPDX-Lincense-Identifier: MIT
pragma solidity ^0.8.30;
import {Script} from "forge-std/Script.sol";
import {MyFaucet} from "../src/CrowdfundFaucet.sol";

contract DeployCrowdFunderFaucet is Script {
    function run() public {
        vm.startBroadcast();
        MyFaucet myFaucet = new MyFaucet("crowdfundtesttoken", "CFTT");
        vm.stopBroadcast();
    }
}


