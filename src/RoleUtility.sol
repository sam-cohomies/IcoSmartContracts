// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessManaged} from "lib/openzeppelin-contracts/contracts/access/manager/AccessManaged.sol";

struct Role {
    // Base role - can do action
    uint64 roleId;
    // Guardian role - can cancel action
    uint64 guardianRoleId;
    // Admin role - can cancel action, grant / revoke roles
    uint64 adminRoleId;
}

contract RoleUtility is AccessManaged {
    // Event to notify when a new role is added
    event RoleAdded(string roleName, Role role);

    // Mapping from human-readable role names to role data
    mapping(string => Role) private roleMapping;

    // List of all role names for enumeration purposes
    string[] private roleNames;

    // Custom errors
    error RoleAlreadyExists(string roleName);
    error RoleDoesNotExist(string roleName);

    constructor(address _accessControlManager, string[] memory initialRoles) AccessManaged(_accessControlManager) {
        // Initialize with predefined roles
        uint256 initialRolesLength = initialRoles.length;
        for (uint64 i = 0; i < initialRolesLength; ++i) {
            addRole(initialRoles[i]);
        }
    }

    // Add a new role and associated subroles
    function addRole(string memory roleName) public restricted {
        if (roleMapping[roleName].roleId == 0) {
            revert RoleAlreadyExists(roleName);
        }
        uint64 len3 = 3 * roleNames.length;
        Role memory role = Role(len3 + 1, len3 + 2, len3 + 3);
        roleMapping[roleName] = role;
        roleNames.push(roleName);
        emit RoleAdded(roleName, role);
    }

    // Get the uint64 IDs of a role by name
    function getRoleIds(string memory roleName) external view returns (Role memory) {
        if (roleMapping[roleName].roleId == 0) {
            revert RoleDoesNotExist(roleName);
        }
        return roleMapping[roleName];
    }

    // Get the full list of roles as human-readable names
    function getAllRoleNames() external view returns (string[] memory) {
        return roleNames;
    }
}
