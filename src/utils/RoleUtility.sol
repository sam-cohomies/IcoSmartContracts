// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {Role} from "./Structs.sol";

/// @custom:security-contact sam@cohomies.io
contract RoleUtility is AccessManaged {
    // Event to notify when a new role is added
    event RoleAdded(string roleName, Role role);

    // Mapping from human-readable role names to role data
    mapping(string => Role) private roleMapping;

    // List of all role names for enumeration purposes
    string[] private _roleNames;

    // Custom errors
    error RoleAlreadyExists(string roleName);
    error RoleDoesNotExist(string roleName);

    constructor(address accessControlManager_, string[] memory initialRoles_) AccessManaged(accessControlManager_) {
        // Initialize with predefined roles
        uint256 initialRoles_Length = initialRoles_.length;
        for (uint256 i = 0; i < initialRoles_Length; ++i) {
            _addRole(initialRoles_[i]);
        }
    }

    // External function to add a new role, guardian, and admin
    function addRole(string memory roleName) external restricted {
        _addRole(roleName);
    }

    // Internal function to add a new role, guardian, and admin
    function _addRole(string memory roleName) internal {
        if (roleMapping[roleName].roleId != 0) {
            revert RoleAlreadyExists(roleName);
        }
        uint16 len3 = uint16(3 * _roleNames.length);
        Role memory role = Role(len3 + 1, len3 + 2, len3 + 3);
        roleMapping[roleName] = role;
        _roleNames.push(roleName);
        emit RoleAdded(roleName, role);
    }

    // Get the uint16 IDs of a role by name
    function getRoleIds(string memory roleName) external view returns (Role memory) {
        if (roleMapping[roleName].roleId == 0) {
            revert RoleDoesNotExist(roleName);
        }
        return roleMapping[roleName];
    }

    // Get the full list of roles as human-readable names
    function getAll_RoleNames() external view returns (string[] memory) {
        return _roleNames;
    }
}
