// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

enum AllocationType {
    PRESALE_ICO,
    MARKETING,
    TEAM,
    LIQUIDITY_POOLS
}

enum IcoState {
    Seed,
    Private,
    Stage1,
    Stage2,
    Stage3,
    Stage4,
    Stage5,
    Stage6,
    Stage7,
    Stage8,
    Stage9,
    Stage10,
    Stage11,
    NotStarted,
    Succeeded,
    Failed
}

enum Currency {
    USDT,
    USDC,
    ETH
}
