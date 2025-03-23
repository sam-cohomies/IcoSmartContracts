// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {ChmBaseToken} from "./ChmBaseToken.sol";
import {AllocationAddresses} from "../utils/Structs.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/// @custom:security-contact sam@cohomies.io
contract ChmIcoGovernanceToken is ChmBaseToken {
    error NotADistributor();

    uint128 private constant ALLOCATION_LIQUIDITY_POOLS = 0;
    uint128 private constant ALLOCATION_LIQUIDITY_REWARDS = 0;

    string public constant _NAME = "CoHomies ICO Governance";

    mapping(address => bool) private _distributors;

    constructor(AllocationAddresses memory allocationAddresses_)
        ChmBaseToken(_NAME, "CIG", allocationAddresses_, false)
        EIP712(_NAME, "1")
    {
        _distributors[allocationAddresses_.presaleIco] = true;
        _distributors[allocationAddresses_.marketing] = true;
        _distributors[allocationAddresses_.team] = true;
    }

    modifier onlyDistributor() {
        if (!_distributors[msg.sender]) {
            revert NotADistributor();
        }
        _;
    }

    function transfer(address recipient, uint256 amount) public override onlyDistributor returns (bool) {
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount)
        public
        override
        onlyDistributor
        returns (bool)
    {
        return super.transferFrom(sender, recipient, amount);
    }
}
