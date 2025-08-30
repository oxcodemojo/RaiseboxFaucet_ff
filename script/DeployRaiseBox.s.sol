//SPDX-Lincense-Identifier: MIT
pragma solidity ^0.8.30;
import {Script} from "forge-std/Script.sol";
import {RaiseBoxFaucet} from "../src/RaiseBoxFaucet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


contract DeployRaiseboxContract is Script {
    RaiseBoxFaucet public contractAddress;
    function run() public {
        vm.startBroadcast();
        contractAddress = new RaiseBoxFaucet(
            "raiseboxtoken",
            "RB",
            1000 * 10 ** 18,
            0.01 ether,
            1 ether
        );
        vm.stopBroadcast();
    }
}


