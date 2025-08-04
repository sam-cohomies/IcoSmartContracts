// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.30;

interface IVestingLogic {
    function vestedAmount(address _user) external view returns (uint256 amount);

    function releasableAmount(address _user) external view returns (uint256 amount);

    function addAllocation(address _user, uint256 amount) external;
}
