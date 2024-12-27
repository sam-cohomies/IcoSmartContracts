// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {AccessManaged} from "lib/openzeppelin-contracts/contracts/access/manager/AccessManaged.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "lib/openzeppelin-contracts/contracts/utils/Nonces.sol";

/// @custom:security-contact sam@cohomies.io
contract CHMToken is ERC20, ERC20Pausable, AccessManaged, ERC20Permit, ERC20Votes {
    constructor(address _accessControlManager, address escrowInitial)
        ERC20("CoHomies", "CHM")
        AccessManaged(_accessControlManager)
    {
        ERC20Permit("CoHomies");
        _mint(escrowInitial, 2 * (10 ** (9 + decimals())));
    }

    function pause() public restricted {
        _pause();
    }

    function unpause() public restricted {
        _unpause();
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
