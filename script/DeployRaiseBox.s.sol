//SPDX-Lincense-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {RaiseBoxFaucet} from "../src/RaiseBoxFaucet.sol";

contract DeployRaiseboxContract is Script {
    RaiseBoxFaucet public raiseBox;

    function run() public {
        vm.startBroadcast();
        raiseBox = new RaiseBoxFaucet("raiseboxtoken", "RB", 1000 * 10 ** 18, 0.005 ether, 1 ether);
        vm.stopBroadcast();
    }
}
