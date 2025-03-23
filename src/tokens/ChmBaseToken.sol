// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {AllocationType} from "../utils/Enums.sol";
import {AllocationAddresses} from "../utils/Structs.sol";

/// @custom:security-contact sam@cohomies.io
abstract contract ChmBaseToken is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes, AccessManaged {
    uint128 private constant ALLOCATION_PRESALE_ICO = 1e8;
    uint128 private constant ALLOCATION_MARKETING = 3e7;
    uint128 private constant ALLOCATION_TEAM = 2e7;
    uint128 private constant ALLOCATION_LIQUIDITY_POOLS = 5e7;

    address private immutable ALLOCATION_ADDRESS_PRESALE_ICO;
    address private immutable ALLOCATION_ADDRESS_MARKETING;
    address private immutable ALLOCATION_ADDRESS_TEAM;
    address private immutable ALLOCATION_ADDRESS_LIQUIDITY_POOLS;

    error ZeroAddressNotAllowed();
    error InvalidAllocationType();

    constructor(
        string memory name_,
        string memory symbol_,
        address accessControlManager_,
        AllocationAddresses memory allocationAddresses_,
        bool[4] memory mintAddresses_
    ) ERC20(name_, symbol_) ERC20Permit(name_) AccessManaged(accessControlManager_) {
        if (
            address(allocationAddresses_.presaleIco) == address(0)
                || address(allocationAddresses_.marketing) == address(0)
                || address(allocationAddresses_.team) == address(0)
                || address(allocationAddresses_.liquidityPools) == address(0)
        ) {
            revert ZeroAddressNotAllowed();
        }
        ALLOCATION_ADDRESS_PRESALE_ICO = allocationAddresses_.presaleIco;
        ALLOCATION_ADDRESS_MARKETING = allocationAddresses_.marketing;
        ALLOCATION_ADDRESS_TEAM = allocationAddresses_.team;
        ALLOCATION_ADDRESS_LIQUIDITY_POOLS = allocationAddresses_.liquidityPools;
        if (mintAddresses_[0]) {
            _mint(ALLOCATION_ADDRESS_PRESALE_ICO, ALLOCATION_PRESALE_ICO * 10 ** decimals());
        }
        if (mintAddresses_[1]) {
            _mint(ALLOCATION_ADDRESS_MARKETING, ALLOCATION_MARKETING * 10 ** decimals());
        }
        if (mintAddresses_[2]) {
            _mint(ALLOCATION_ADDRESS_TEAM, ALLOCATION_TEAM * 10 ** decimals());
        }
        if (mintAddresses_[3]) {
            _mint(ALLOCATION_ADDRESS_LIQUIDITY_POOLS, ALLOCATION_LIQUIDITY_POOLS * 10 ** decimals());
        }
    }

    function getAllocation(AllocationType allocationType) public pure returns (uint128) {
        if (allocationType == AllocationType.PRESALE_ICO) {
            return ALLOCATION_PRESALE_ICO;
        } else if (allocationType == AllocationType.MARKETING) {
            return ALLOCATION_MARKETING;
        } else if (allocationType == AllocationType.TEAM) {
            return ALLOCATION_TEAM;
        } else if (allocationType == AllocationType.LIQUIDITY_POOLS) {
            return ALLOCATION_LIQUIDITY_POOLS;
        }
        revert InvalidAllocationType();
    }

    function remainingAllocation(AllocationType allocationType) public view returns (uint256) {
        if (allocationType == AllocationType.PRESALE_ICO) {
            return balanceOf(ALLOCATION_ADDRESS_PRESALE_ICO);
        } else if (allocationType == AllocationType.MARKETING) {
            return balanceOf(ALLOCATION_ADDRESS_MARKETING);
        } else if (allocationType == AllocationType.TEAM) {
            return balanceOf(ALLOCATION_ADDRESS_TEAM);
        } else if (allocationType == AllocationType.LIQUIDITY_POOLS) {
            return balanceOf(ALLOCATION_ADDRESS_LIQUIDITY_POOLS);
        }
        revert InvalidAllocationType();
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
