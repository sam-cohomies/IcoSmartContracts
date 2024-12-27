// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {Script} from "lib/forge-std/src/Script.sol";
import {AccessManager} from "lib/openzeppelin-contracts/contracts/access/manager/AccessManager.sol";
import {CHMToken} from "../src/CHMToken.sol";
import {Role, RoleUtility} from "../src/RoleUtility.sol";

contract Deploy is Script {
    error InvalidAdminAddress(address admin);

    function run() public {
        // Load the admin address from the environment variable
        string memory adminEnvVar = vm.envString("ADMIN_MULTISIG");
        address admin = vm.parseAddress(adminEnvVar);
        string memory escrowInitialEnvVar = vm.envString("ESCROW_INITIAL_MULTISIG");
        address escrowInitial = vm.parseAddress(escrowInitialEnvVar);

        if (admin == address(0)) {
            revert InvalidAdminAddress(admin);
        }

        // Start broadcasting the transaction from the caller's address
        vm.startBroadcast();

        // Deploy CHMAccessManager
        AccessManager manager = new AccessManager(admin);

        // Roles
        string[] memory roles = ["CHM_TOKEN_PAUSER", "CHM_ICO_PAUSER", "CHM_ICO_ENDER"];

        // Execution delays
        // TODO: Set appropriate execution delays

        // Deploy RoleUtility
        RoleUtility roleUtility = new RoleUtility(address(manager), roles);

        // Deploy CHMToken
        CHMToken chm = new CHMToken(address(manager), address(escrowInitial));

        // Deploy ICO
        // TODO: develop ICO contract

        // Restrict functions
        bytes4[] memory chmPauserSelectors = [chm.pause.selector, chm.unpause.selector];
        _restrictFunctions(manager, roleUtility, address(chm), chmPauserSelectors, "CHM_TOKEN_PAUSER");

        // TODO: restrict ICO functions
        // bytes4[] memory icoPauserSelectors = []; // TODO: add ICO pauser selectors
        // _restrictFunctions(
        //     manager,
        //     roleUtility,
        //     address(0), // TODO: replace with ICO contract address
        //     icoPauserSelectors,
        //     "CHM_ICO_PAUSER"
        // );

        // bytes4[] memory icoEnderSelectors = []; // TODO: add ICO ender selectors
        // _restrictFunctions(
        //     manager,
        //     roleUtility,
        //     address(0), // TODO: replace with ICO contract address
        //     icoEnderSelectors,
        //     "CHM_ICO_ENDER"
        // );

        vm.stopBroadcast();
    }

    function _restrictFunctions(
        AccessManager manager,
        RoleUtility roleUtility,
        address target,
        bytes4[] memory selectors,
        string memory role
    ) internal {
        Role memory roleData = roleUtility.getRoleIds(role);
        manager.setTargetFunctionRole(target, selectors, roleData.roleId);
        manager.setRoleGuardian(roleData.roleId, roleData.guardianRoleId);
        manager.setRoleAdmin(roleData.roleId, roleData.adminRoleId);
        manager.setRoleAdmin(roleData.guardianRoleId, roleData.adminRoleId);
        manager.labelRole(roleData.roleId, role);
        manager.labelRole(roleData.guardianRoleId, string(abi.encodePacked(role, "_GUARDIAN")));
        manager.labelRole(roleData.adminRoleId, string(abi.encodePacked(role, "_ADMIN")));
    }

    function _asSingletonArray(bytes4 element) private pure returns (bytes4[] memory) {
        bytes4[] memory array = new bytes4[](1);
        array[0] = element;
        return array;
    }
}
