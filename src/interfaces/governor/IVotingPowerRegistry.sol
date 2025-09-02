// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.30;

interface IVotingPowerRegistry {
    function getTotalVotingPower() external view returns (uint208 votingPower);
    function getTotalVotingPowerAtBlock(uint48 _blockNumber) external view returns (uint208 votingPower);
    /**
     * @notice Returns the voting power of a user at a specific block.
     * @param _user The address of the user.
     * @param _blockNumber The block number at which to check the voting power.
     * @return votingPower The voting power of the user at the specified block.
     */
    function getUserVotingPowerAtBlock(address _user, uint48 _blockNumber)
        external
        view
        returns (uint208 votingPower);

    function addAllocation(address _user, uint208 _amount) external;

    function removeAllocation(address _user, uint208 _amount) external;

    function getTotalUnclaimedVotingPowerAtBlock(uint48 _blockNumber) external view returns (uint208 votingPower);

    function getTotalUnclaimedVotingPower() external view returns (uint208 votingPower);
}
