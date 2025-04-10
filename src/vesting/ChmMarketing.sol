// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ChmSharesVesting} from "./ChmSharesVesting.sol";
import {VestingTerms} from "../utils/Structs.sol";
import {ChmAffiliateCodes} from "../lib/ChmAffiliateCodes.sol";

// TODO: upgradable?

contract ChmMarketingVesting is ChmSharesVesting {
    uint96 public constant CHM_FOR_AFFILIATE_MARKETING = 100_000_000 * 1e18; // 100,000,000 CHM
    uint8 public constant CHM_AFFILIATE_DISCOUNT = 5; // 5% discount

    mapping(uint24 => address) private _seedToMarketer;
    mapping(address => uint256) private _marketerToShareholderIndex;

    event TokensAllocated(address indexed marketer, uint96 indexed chm, string indexed cid);
    event AffiliateRegistered(address indexed affiliate, string indexed code);

    error InvalidAddress(address addr);

    constructor(address accessControlManager_, address chmToken_, address chmIcoGovernanceToken_)
        ChmSharesVesting(
            accessControlManager_,
            chmToken_,
            chmIcoGovernanceToken_,
            VestingTerms(2 days, 0, 30 days),
            CHM_FOR_AFFILIATE_MARKETING
        )
    {}

    function registerAffiliate(address marketer) external nonReentrant returns (string memory code) {
        if (marketer == address(0)) {
            revert InvalidAddress(marketer);
        }
        uint24 seed = ChmAffiliateCodes.generateSeed(marketer, _seedToMarketer);
        if (_seedToMarketer[seed] != address(0)) {
            revert InvalidAddress(marketer);
        }
        _seedToMarketer[seed] = marketer;
        code = ChmAffiliateCodes.getCodeFromSeed(seed);
        emit AffiliateRegistered(marketer, code);
    }

    function allocateAffiliateMarketingSales(address marketer, uint96 chmSold) external restricted nonReentrant {
        if (marketer == address(0)) {
            revert InvalidAddress(marketer);
        }
        if (_marketerToShareholderIndex[marketer] == 0) {
            shareholders.push(marketer);
            _marketerToShareholderIndex[marketer] = shareholders.length;
            sharesOwed.push(chmSold);
        } else {
            sharesOwed[_marketerToShareholderIndex[marketer] - 1] += chmSold;
        }
        totalSharesOwed += chmSold;
    }

    function allocateMarketingTokens(address marketer, uint96 chm, string calldata cid)
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

    function getMarketerFromCode(string calldata code) external view returns (address marketer) {
        marketer = _getMarketerFromCode(code);
    }

    function _getMarketerFromCode(string calldata code) internal view returns (address marketer) {
        uint24 seed = ChmAffiliateCodes.getSeedFromCode(code);
        marketer = _seedToMarketer[seed];
    }
}
