// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ChmBaseVesting} from "./ChmBaseVesting.sol";
import {Fraction} from "../utils/Structs.sol";

/// @custom:security-contact sam@cohomies.io
abstract contract ChmSharesVesting is ChmBaseVesting {
    uint128 public immutable CHM_FOR_SHARES;

    address[] internal shareholders;
    uint128[] internal sharesOwed;
    uint128 internal totalSharesOwed;

    constructor(
        address accessControlManager_,
        address chmToken_,
        address chmIcoGovernanceToken_,
        uint256 delay_,
        uint256 cliff_,
        uint256 duration_,
        uint128 chmForShares_
    ) ChmBaseVesting(accessControlManager_, chmToken_, chmIcoGovernanceToken_, delay_, cliff_, duration_) {
        CHM_FOR_SHARES = chmForShares_;
    }

    function _allocateTokensFromShares() internal vestingNotStarted {
        uint256 chmBalance = CHM_TOKEN.balanceOf(address(this));
        if (chmBalance == 0 || shareholders.length == 0 || sharesOwed.length == 0) {
            revert NothingToRelease();
        }
        uint128 chmForShares = CHM_FOR_SHARES > 0 ? CHM_FOR_SHARES : uint128(chmBalance);
        uint128 chmAllocated = 0;
        address maxShareholder = shareholders[0];
        uint128 maxShares = sharesOwed[0];
        for (uint256 i = 0; i < shareholders.length; i++) {
            uint128 chmToAllocate = chmForShares * sharesOwed[i] / totalSharesOwed;
            userVesting[shareholders[i]].chmOwed += chmToAllocate;
            chmAllocated += chmToAllocate;
            if (sharesOwed[i] > maxShares) {
                maxShareholder = shareholders[i];
                maxShares = sharesOwed[i];
            }
        }
        if (chmAllocated < chmForShares) {
            userVesting[maxShareholder].chmOwed += chmForShares - chmAllocated;
        }
    }

    function _startVestingBoilerplate() internal virtual override {
        _allocateTokensFromShares();
        super._startVestingBoilerplate();
    }
}
