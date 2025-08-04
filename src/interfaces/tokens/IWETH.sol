// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
    function safeTransfer(address to, uint256 value) external;
}
