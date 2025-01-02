// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {User} from "./utils/Structs.sol";

/// @custom:security-contact sam@cohomies.io
contract ChmPublicVesting is AccessManaged {
    event VestingBegun(address[] addresses, User[] users);

    mapping(address => User) private userData;

    constructor(address _accessControlManager) AccessManaged(_accessControlManager) {}

    function beginVesting(address[] memory _addresses, User[] memory _users) external restricted {
        require(_addresses.length == _users.length, "Mismatched input lengths");
        for (uint256 i = 0; i < _addresses.length; i++) {
            userData[_addresses[i]] = _users[i];
        }
        // TODO: Implement vesting logic
        emit VestingBegun(_addresses, _users);
    }
}
