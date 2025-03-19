// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ChmSharesVesting} from "./ChmSharesVesting.sol";

// TODO: upgradable?

contract ChmMarketingVesting is ChmSharesVesting {
    uint128 public constant CHM_FOR_AFFILIATE_MARKETING = 100_000_000 * 1e18; // 100,000,000 CHM

    mapping(address => uint256) private affiliateMarketers;

    event TokensAllocated(address indexed marketer, uint128 chm, string cid);

    constructor(address _accessControlManager, address _chmToken)
        ChmSharesVesting(_accessControlManager, _chmToken, 2 days, 0, 30 days, CHM_FOR_AFFILIATE_MARKETING)
    {}

    // TODO: hook this up to ICO contract
    function allocateAffiliateMarketingShares(address marketer, uint128 shares) external restricted nonReentrant {
        if (affiliateMarketers[marketer] == 0) {
            shareholders.push(marketer);
            affiliateMarketers[marketer] = shareholders.length;
            sharesOwed.push(shares);
        } else {
            sharesOwed[affiliateMarketers[marketer] - 1] += shares;
        }
        totalSharesOwed += shares;
    }

    function allocateMarketingTokens(address marketer, uint128 chm, string calldata cid)
        external
        restricted
        nonReentrant
    {
        userVesting[marketer].chmOwed += chm;
        emit TokensAllocated(marketer, chm, cid);
    }
}
