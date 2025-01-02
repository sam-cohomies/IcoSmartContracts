// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

struct User {
    uint256 usdtSpent; // Total USDT measured in microUSDT spent by the user (6 decimals)
    uint256 usdcSpent; // Total USDC measured in microUSDC spent by the user (6 decimals)
    uint256 ethSpent; // Total ETH measured in wei spent by the user (18 decimals)
    uint256 chmOwed; // Total CHM owed to the user (no decimals)
    uint256 index; // Index into the user list
}
