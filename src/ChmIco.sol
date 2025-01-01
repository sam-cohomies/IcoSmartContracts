// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {AccessManaged} from "lib/openzeppelin-contracts/contracts/access/manager/AccessManaged.sol";

/// @custom:security-contact sam@cohomies.io
contract ChmIco is AccessManaged {
    error ZeroAddressNotAllowed();

    constructor(address _accessControlManager) AccessManaged(_accessControlManager) {}

    
}