// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {AccessManaged} from "lib/openzeppelin-contracts/contracts/access/manager/AccessManaged.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "lib/openzeppelin-contracts/contracts/utils/Nonces.sol";

/// @custom:security-contact sam@cohomies.io
contract CHMToken is ERC20, ERC20Pausable, AccessManaged, ERC20Permit, ERC20Votes {
    enum AllocationType {
        PRESALE,
        MARKETING,
        EXCHANGE,
        TEAM,
        ADVISORS
    }

    uint256[5] private _allocations;

    address[5] private _allocationAddresses;

    error ZeroAddressNotAllowed();

    constructor(address _accessControlManager, address[5] memory allocationAddresses)
        ERC20("CoHomies", "CHM")
        AccessManaged(_accessControlManager)
        ERC20Permit("CoHomies")
    {
        for (uint256 i = 0; i < allocationAddresses.length; i++) {
            if (allocationAddresses[i] == address(0)) {
                revert ZeroAddressNotAllowed();
            }
        }
        _allocations = [
            1e9, // PRESALE
            4e8, // MARKETING
            3e8, // EXCHANGE
            2e8, // TEAM
            1e8 // ADVISORS
        ];
        _allocationAddresses = allocationAddresses;
        for (uint256 i = 0; i < _allocations.length; i++) {
            _mint(allocationAddresses[i], _allocations[i] * 10 ** decimals());
        }
    }

    function getAllocations() public view returns (uint256[5] memory) {
        return _allocations;
    }

    function remainingAllocation(AllocationType allocationType) public view returns (uint256) {
        return balanceOf(_allocationAddresses[uint256(allocationType)]);
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
