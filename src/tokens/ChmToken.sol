// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {ChmBaseToken} from "./ChmBaseToken.sol";
import {AllocationAddresses} from "../utils/Structs.sol";

/// @custom:security-contact sam@cohomies.io
contract ChmToken is ChmBaseToken, AccessManaged, ERC20Pausable, ERC20Permit {
    constructor(address _accessControlManager, AllocationAddresses memory allocationAddresses_)
        ChmBaseToken("CoHomies", "CHM", allocationAddresses_, true)
        AccessManaged(_accessControlManager)
        ERC20Permit("CoHomies")
    {}

    function pause() public restricted {
        _pause();
    }

    function unpause() public restricted {
        _unpause();
    }

    function _update(address from, address to, uint256 value) internal override(ChmBaseToken, ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
