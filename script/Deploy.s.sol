// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {Script} from "lib/forge-std/src/Script.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {CHMToken} from "../src/CHMToken.sol";

contract Deploy is Script {
    AccessManager manager;
    CHMToken chm;

    // Roles
    uint64 public constant CALLER_ROLE = 1;
    uint64 public constant CALLER_GUARDIAN_ROLE = 2;
    uint64 public constant CALLER_ADMIN_ROLE = 3;

    uint64 public constant PAUSER_ROLE = 4;
    uint64 public constant PAUSER_GUARDIAN_ROLE = 5;
    uint64 public constant PAUSER_ADMIN_ROLE = 6;

    // Execution delays
    // TODO: Set the execution delays to the appropriate values
    uint64 public constant CALLER_ROLE_EXECUTION_DELAY = 1 days;
    uint64 public constant CALLER_GUARDIAN_ROLE_EXECUTION_DELAY = 1 days;
    uint64 public constant CALLER_ADMIN_ROLE_EXECUTION_DELAY = 1 days;

    uint64 public constant PAUSER_ROLE_EXECUTION_DELAY = 1 days;
    uint64 public constant PAUSER_GUARDIAN_ROLE_EXECUTION_DELAY = 1 days;
    uint64 public constant PAUSER_ADMIN_ROLE_EXECUTION_DELAY = 1 days;

    function setUp() public {}

    function run() public {
        // Load the admin address from the environment variable
        string memory adminEnvVar = vm.envString("ADMIN_MULTISIG");
        address admin = vm.parseAddress(adminEnvVar);
        string memory escrowInitialEnvVar = vm.envString("ESCROW_INITIAL_MULTISIG");
        address escrowInitial = vm.parseAddress(escrowInitialEnvVar);

        // Ensure admin address is valid
        require(admin != address(0), "Invalid admin address");

        // Start broadcasting the transaction from the caller's address
        vm.startBroadcast();

        // Deploy CHMAccessManager
        manager = new AccessManager(admin);

        // Deploy CHMToken
        CHMToken chm = new CHMToken(
            address(manager),
            address(escrowInitial)
        );

        // Deploy CoHomies

        // Restrict functions
        manager.setTargetFunctionRole(
            address(chm),
            _asSingletonArray(CHMToken.pause.selector),
            PAUSER_ROLE
        );

        manager.setTargetFunctionRole(
            address(chm),
            _asSingletonArray(CHMToken.unpause.selector),
            PAUSER_ROLE
        );

        vm.stopBroadcast();

        // Log the deployed contract address
        console.log("YourContract deployed at:", address(yourContract));
        console.log("Admin set to:", admin);
    }
}