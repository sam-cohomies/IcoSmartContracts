// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.30;

import {GovernorCountingSimpleUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";

// Custom Errors for clarity
error InvalidThresholdPercentage();

/**
 * @dev Custom counting module that extends GovernorCountingSimple with a veto/pass threshold logic.
 *
 * This module implements the following voting rules:
 * - A proposal is VETOED if 'Against' votes exceed a specific percentage of the total supply.
 * - A proposal is PASSED if 'For' votes exceed a specific percentage of the total supply.
 * - If the voting period ends and the proposal is NOT vetoed, it is considered PASSED by default.
 * - Quorum is disabled.
 */
abstract contract MyCustomGovernorCounting is GovernorCountingSimpleUpgradeable {
    uint256 public vetoThresholdPercentage; // X%
    uint256 public passThresholdPercentage; // (100-X)% or another value

    /**
     * @dev Initializes the custom counting module with specific thresholds.
     * @param _vetoThreshold The percentage of total supply required for 'Against' votes to veto (e.g., 20 for 20%).
     * @param _passThreshold The percentage of total supply required for 'For' votes to explicitly pass (e.g., 51 for 51%).
     */
    function __MyCustomGovernorCounting_init(uint256 _vetoThreshold, uint256 _passThreshold)
        internal
        onlyInitializing
    {
        // Call the parent initializer
        __GovernorCountingSimple_init_unchained();

        if (_vetoThreshold > 100 || _passThreshold > 100) {
            revert InvalidThresholdPercentage();
        }

        vetoThresholdPercentage = _vetoThreshold;
        passThresholdPercentage = _passThreshold;
    }

    /**
     * @dev See {IGovernor-COUNTING_MODE}.
     */
    function COUNTING_MODE() public pure virtual override returns (string memory) {
        // Describes the voting logic for off-chain tools.
        return "support=bravo&quorum=false&veto=true";
    }

    /**
     * @dev Disables quorum requirements as requested. A proposal's validity
     * will only depend on the pass/veto threshold logic.
     * @inheritdoc GovernorUpgradeable
     */
    function _quorumReached(uint256) internal view virtual override returns (bool) {
        // Quorum is disabled, so this always returns true.
        return true;
    }

    /**
     * @dev Implements the custom vote success logic based on veto and pass thresholds.
     * @inheritdoc GovernorUpgradeable
     */
    function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool voteSucceeded) {
        // Get the vote counts for the proposal
        (uint256 againstVotes, uint256 forVotes,) = proposalVotes(proposalId);

        // Get the total voting power at the time of the proposal's snapshot
        uint256 totalVotingPower = votingToken().getPastTotalSupply(proposalSnapshot(proposalId));

        // If total voting power is zero, no proposal can pass.
        if (totalVotingPower == 0) {
            return false;
        }

        // 1. VETO CHECK: If 'Against' votes exceed the veto threshold, the proposal fails immediately.
        // This is the "if more than X% votes against, the vote fails" rule.
        if (againstVotes * 100 > totalVotingPower * vetoThresholdPercentage) {
            // Note: Using `>` for "more than X%".
            return false; // Vetoed
        }

        // 2. EXPLICIT PASS CHECK: If 'For' votes exceed the pass threshold, the proposal succeeds.
        // This is the "if more than 100-X% votes for, the vote passes" rule.
        // You can set passThresholdPercentage to whatever you need (e.g., 51 for a simple majority).
        if (forVotes * 100 > totalVotingPower * passThresholdPercentage) {
            return true; // Explicitly Passed
        }

        // 3. DEFAULT PASS (INSUFFICIENT VETO): If the voting period has ended and the proposal
        // was not vetoed (checked in step 1), it passes by default.
        // This is the "if the time elapses without more than X% votes against, the vote passes" rule.
        return true;
    }

    // The _countVote function is inherited directly from GovernorCountingSimpleUpgradeable
    // and does not need to be changed, as per your request.
}
