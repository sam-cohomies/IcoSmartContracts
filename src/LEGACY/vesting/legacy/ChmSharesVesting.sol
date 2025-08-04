// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ChmBaseVesting} from "./ChmBaseVesting.sol";
import {VestingTerms} from "../utils/Structs.sol";

/// @custom:security-contact sam@cohomies.io
abstract contract ChmSharesVesting is ChmBaseVesting {
    uint96 public immutable CHM_FOR_SHARES;

    address[] internal shareholders;
    uint96[] internal sharesOwed;
    uint96 internal totalSharesOwed;

    constructor(
        address accessControlManager_,
        address chmToken_,
        address chmIcoGovernanceToken_,
        VestingTerms memory vestingTerms_,
        uint96 chmForShares_
    ) ChmBaseVesting(accessControlManager_, chmToken_, chmIcoGovernanceToken_, vestingTerms_) {
        CHM_FOR_SHARES = chmForShares_;
    }

    function _allocateTokensFromShares() internal vestingNotStarted {
        uint96 chmBalance = uint96(CHM_TOKEN.balanceOf(address(this)));
        uint256 shareholdersLength = shareholders.length;
        if (chmBalance == 0 || shareholdersLength == 0 || sharesOwed.length == 0) {
            revert NothingToRelease();
        }
        uint96 chmForShares = CHM_FOR_SHARES > 0 ? CHM_FOR_SHARES : chmBalance;
        uint96 chmAllocated = 0;
        address maxShareholder = shareholders[0];
        uint96 maxShares = sharesOwed[0];
        for (uint256 i = 0; i < shareholdersLength; ++i) {
            uint96 chmToAllocate = chmForShares * sharesOwed[i] / totalSharesOwed;
            _userVesting[shareholders[i]].chmOwed += chmToAllocate;
            chmAllocated += chmToAllocate;
            if (sharesOwed[i] > maxShares) {
                maxShareholder = shareholders[i];
                maxShares = sharesOwed[i];
            }
        }
        if (chmAllocated < chmForShares) {
            _userVesting[maxShareholder].chmOwed += chmForShares - chmAllocated;
        }
    }

    function _startVestingBoilerplate() internal virtual override {
        _allocateTokensFromShares();
        super._startVestingBoilerplate();
    }
}
