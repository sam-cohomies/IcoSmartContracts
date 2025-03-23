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

struct User {
    uint128 ethOwed; // Total ETH measured in wei owed to the user (18 decimals)
    uint128 usdtOwed; // Total USDT measured in microUSDT owed to the user (6 decimals)
    uint128 usdcOwed; // Total USDC measured in microUSDC owed to the user (6 decimals)
    uint128 chmOwed; // Total CHM owed to the user (18 decimals)
    uint128 chmReleased; // Total CHM released to the user (18 decimals)
}

struct Fraction {
    uint128 numerator;
    uint128 denominator;
}

struct AllocationAddresses {
    address presaleIco;
    address marketing;
    address team;
    address liquidityPools;
    address liquidityRewards;
}
