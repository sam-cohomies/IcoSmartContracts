// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

struct Role {
    // Base role - can do action
    uint64 roleId;
    // Guardian role - can cancel action
    uint64 guardianRoleId;
    // Admin role - can cancel action, grant / revoke roles
    uint64 adminRoleId;
}

struct Stage {
    uint256 tokensAvailable; // Total tokens currently available for sale (no decimals)
    uint256 price; // Price of one token in microUSDT (6 decimals)
    uint256 duration; // Duration of the stage using solidity default encoding
    uint256 startTime; // Start time of the stage using solidity default encoding
}

struct TeamMember {
    address member; // Address of the team member
    uint128 id; // ID of the team member
    uint128 shares; // Number of shares owned by the team member
}

struct TokensVested {
    uint128 released;
    uint128 total;
}

struct User {
    uint256 usdtSpent; // Total USDT measured in microUSDT spent by the user (6 decimals)
    uint256 usdcSpent; // Total USDC measured in microUSDC spent by the user (6 decimals)
    uint256 ethSpent; // Total ETH measured in wei spent by the user (18 decimals)
    uint256 chmOwed; // Total CHM owed to the user (no decimals)
    uint256 index; // Index into the user list
}
