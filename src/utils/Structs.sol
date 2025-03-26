// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

struct Role {
    uint16 roleId; // can do action
    uint16 guardianRoleId; // can cancel action
    uint16 adminRoleId; // can cancel action, grant / revoke roles
}

struct Stage {
    uint96 tokensAvailable; // Total tokens currently available for sale (18 decimals) (min uint88)
    uint32 startTime; // Start time of the stage using solidity default encoding (min uint32)
    uint32 duration; // Duration of the stage using solidity default encoding (min uint32)
    uint24 price; // Price of one token in microUSDT (6 decimals) (min uint24)
}

struct User {
    uint96 chmOwed; // Total CHM owed to the user (18 decimals) (min uint88)
    uint96 chmReleased; // Total CHM released to the user (18 decimals) (min uint88)
    uint96 ethOwed; // Total ETH measured in wei owed to the user (18 decimals) (min uint80)
    uint96 usdtOwed; // Total USDT measured in microUSDT owed to the user (6 decimals) (min uint48)
    uint96 usdcOwed; // Total USDC measured in microUSDC owed to the user (6 decimals) (min uint48)
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
}
