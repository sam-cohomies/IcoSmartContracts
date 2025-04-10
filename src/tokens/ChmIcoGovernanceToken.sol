// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {ChmBaseToken} from "./ChmBaseToken.sol";
import {AllocationAddresses} from "../utils/Structs.sol";

/// @custom:security-contact sam@cohomies.io
contract ChmIcoGovernanceToken is ChmBaseToken {
    error NotADistributor();

    uint128 private constant ALLOCATION_LIQUIDITY_POOLS = 0;
    uint128 private constant ALLOCATION_LIQUIDITY_REWARDS = 0;

    mapping(address => bool) private _distributors;

    constructor(address accessControlManager_, AllocationAddresses memory allocationAddresses_)
        ChmBaseToken(
            "CoHomies ICO Governance",
            "CIG",
            accessControlManager_,
            allocationAddresses_,
            [true, true, true, false]
        )
    {
        _distributors[allocationAddresses_.presaleIco] = true;
        _distributors[allocationAddresses_.marketing] = true;
        _distributors[allocationAddresses_.team] = true;
    }

    modifier onlyDistributor(address sender) {
        if (!_distributors[sender]) {
            revert NotADistributor();
        }
        _;
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        onlyDistributor(msg.sender)
        returns (bool)
    {
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount)
        public
        override
        onlyDistributor(sender)
        returns (bool)
    {
        return super.transferFrom(sender, recipient, amount);
    }

    function addDistributor(address distributor) external restricted {
        _distributors[distributor] = true;
    }
}
