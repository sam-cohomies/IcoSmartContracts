// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {Script} from "@forge-std/Script.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {ChmToken} from "../src/ChmToken.sol";
import {Role, RoleUtility} from "../src/RoleUtility.sol";

/// @custom:security-contact sam@cohomies.io
contract Deploy is Script {
    error ZeroAddressNotAllowed();

    function run() public {
        // Load and validate addresses from environment variables
        string memory adminEnvVar = vm.envString("ADMIN_MULTISIG");
        address admin = vm.parseAddress(adminEnvVar);
        if (admin == address(0)) {
            revert ZeroAddressNotAllowed();
        }

        string memory presaleEnvVar = vm.envString("PRESALE_MULTISIG");
        address presale = vm.parseAddress(presaleEnvVar);
        if (presale == address(0)) {
            revert ZeroAddressNotAllowed();
        }

        string memory marketingEnvVar = vm.envString("MARKETING_MULTISIG");
        address marketing = vm.parseAddress(marketingEnvVar);
        if (marketing == address(0)) {
            revert ZeroAddressNotAllowed();
        }

        string memory exchangeEnvVar = vm.envString("EXCHANGE_MULTISIG");
        address exchange = vm.parseAddress(exchangeEnvVar);
        if (exchange == address(0)) {
            revert ZeroAddressNotAllowed();
        }

        string memory teamEnvVar = vm.envString("TEAM_MULTISIG");
        address team = vm.parseAddress(teamEnvVar);
        if (team == address(0)) {
            revert ZeroAddressNotAllowed();
        }

        string memory advisorsEnvVar = vm.envString("ADVISORS_MULTISIG");
        address advisors = vm.parseAddress(advisorsEnvVar);
        if (advisors == address(0)) {
            revert ZeroAddressNotAllowed();
        }

        // Start broadcasting the transaction from the caller's address
        vm.startBroadcast();

        // Deploy CHMAccessManager
        AccessManager manager = new AccessManager(admin);

        // Roles
        string[] memory roles = new string[](3);
        roles[0] = "CHM_TOKEN_PAUSER";
        roles[1] = "CHM_ICO_PAUSER";
        roles[2] = "CHM_ICO_ENDER";

        // Execution delays
        // TODO: Set appropriate execution delays

        // Deploy RoleUtility
        RoleUtility roleUtility = new RoleUtility(address(manager), roles);

        // Deploy ChmToken
        ChmToken chm = new ChmToken(address(manager), [presale, marketing, exchange, team, advisors]);

        // Deploy ICO
        // TODO: develop ICO contract

        // Restrict functions
        bytes4[] memory chmPauserSelectors = new bytes4[](2);
        chmPauserSelectors[0] = chm.pause.selector;
        chmPauserSelectors[1] = chm.unpause.selector;
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
