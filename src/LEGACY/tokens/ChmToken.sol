// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.30;

import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ChmBaseToken} from "./ChmBaseToken.sol";
import {AllocationAddresses} from "../utils/Structs.sol";

/// @custom:security-contact sam@cohomies.io
contract ChmToken is ChmBaseToken, ERC20Pausable {
    constructor(address accessControlManager_, AllocationAddresses memory allocationAddresses_)
        ChmBaseToken("CoHomies", "CHM", accessControlManager_, allocationAddresses_, [true, true, true, true])
    {}

    function pause() public restricted {
        _pause();
    }

    function unpause() public restricted {
        _unpause();
    }

    function _update(address from, address to, uint256 value) internal override(ChmBaseToken, ERC20Pausable) {
        super._update(from, to, value);
    }
}
