// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {User} from "./utils/Structs.sol";

/// @custom:security-contact sam@cohomies.io
contract ChmPublicVesting is AccessManaged {
    event VestingBegun(address[] addresses, User[] users);

    mapping(address => User) private userData;

    uint256 private chmSold;

    constructor(address _accessControlManager) AccessManaged(_accessControlManager) {}

    function beginVesting(address[] memory _addresses, User[] memory _users, uint256 _chmSold) external restricted {
        require(_addresses.length == _users.length, "Mismatched input lengths");
        for (uint256 i = 0; i < _addresses.length; i++) {
            userData[_addresses[i]] = _users[i];
        }
        chmSold = _chmSold;
        // TODO: Implement vesting logic
        emit VestingBegun(_addresses, _users);
    }
}
