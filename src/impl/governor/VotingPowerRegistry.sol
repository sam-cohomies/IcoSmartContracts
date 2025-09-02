// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.30;

import {IVotingPowerRegistry} from "src/interfaces/governor/IVotingPowerRegistry.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

contract VotingPowerRegistry is IVotingPowerRegistry {
    using Checkpoints for Checkpoints.Trace208;

    error InsufficientVotingPower();

    // Mapping to store user voting power allocations
    mapping(address => Checkpoints.Trace208) private userVotingPower;
    // Total voting power at a specific block
    Checkpoints.Trace208 private totalVotingPower;
    // Unclaimed voting power at a specific block
    Checkpoints.Trace208 private totalUnclaimedVotingPower;

    constructor() {
        totalVotingPower.push(uint48(block.number), 0);
        totalUnclaimedVotingPower.push(uint48(block.number), 0);
    }

    function getTotalVotingPower() external view override returns (uint208 votingPower) {
        return totalVotingPower.latest();
    }

    function getTotalVotingPowerAtBlock(uint48 _blockNumber) external view override returns (uint208 votingPower) {
        return totalVotingPower.upperLookupRecent(_blockNumber);
    }

    function getUserVotingPowerAtBlock(address _user, uint48 _blockNumber)
        external
        view
        override
        returns (uint208 votingPower)
    {
        return userVotingPower[_user].upperLookupRecent(_blockNumber);
    }

    function addAllocation(address _user, uint208 _amount) external override {
        userVotingPower[_user].push(uint48(block.number), userVotingPower[_user].latest() + _amount);
        totalVotingPower.push(uint48(block.number), totalVotingPower.latest() + _amount);
    }

    function removeAllocation(address _user, uint208 _amount) external override {
        if (userVotingPower[_user].latest() < _amount) {
            revert InsufficientVotingPower();
        }
        userVotingPower[_user].push(uint48(block.number), userVotingPower[_user].latest() - _amount);
        totalVotingPower.push(uint48(block.number), totalVotingPower.latest() - _amount);
    }

    function getTotalUnclaimedVotingPowerAtBlock(uint48 _blockNumber)
        external
        view
        override
        returns (uint208 votingPower)
    {
        return totalUnclaimedVotingPower.upperLookup(_blockNumber);
    }

    function getTotalUnclaimedVotingPower() external view override returns (uint208 votingPower) {
        return totalUnclaimedVotingPower.latest();
    }
}
