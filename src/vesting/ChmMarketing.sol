// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ChmSharesVesting} from "./ChmSharesVesting.sol";

// TODO: upgradable?

contract ChmMarketingVesting is ChmSharesVesting {
    uint128 public constant CHM_FOR_AFFILIATE_MARKETING = 100_000_000 * 1e18; // 100,000,000 CHM

    mapping(address => uint256) private _affiliateMarketers;

    event TokensAllocated(address indexed marketer, uint128 chm, string cid);

    constructor(address accessControlManager_, address chmToken_, address chmIcoGovernanceToken_)
        ChmSharesVesting(
            accessControlManager_,
            chmToken_,
            chmIcoGovernanceToken_,
            2 days,
            0,
            30 days,
            CHM_FOR_AFFILIATE_MARKETING
        )
    {}

    // TODO: hook this up to ICO contract
    function allocateAffiliateMarketingShares(address marketer, uint128 shares) external restricted nonReentrant {
        if (_affiliateMarketers[marketer] == 0) {
            shareholders.push(marketer);
            _affiliateMarketers[marketer] = shareholders.length;
            sharesOwed.push(shares);
        } else {
            sharesOwed[_affiliateMarketers[marketer] - 1] += shares;
        }
        totalSharesOwed += shares;
    }

    function allocateMarketingTokens(address marketer, uint128 chm, string calldata cid)
        external
        restricted
        nonReentrant
    {
        if (!CHM_ICO_GOVERNANCE_TOKEN.approve(marketer, chm)) {
            revert TransferFailed();
        }
        _userVesting[marketer].chmOwed += chm;
        emit TokensAllocated(marketer, chm, cid);
    }
}
