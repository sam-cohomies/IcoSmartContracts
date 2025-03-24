// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ChmSharesVesting} from "./ChmSharesVesting.sol";
import {Fraction} from "../utils/Structs.sol";

/// @custom:security-contact sam@cohomies.io
contract ChmTeamVesting is ChmSharesVesting {
    error ShareholderAlreadyAdded();

    Fraction[] internal _shareFractions;

    constructor(address accessControlManager_, address chmToken_, address chmIcoGovernanceToken_)
        ChmSharesVesting(accessControlManager_, chmToken_, chmIcoGovernanceToken_, 0, 365 days, 365 days, 0)
    {}

    function addShareholder(address shareholder, Fraction calldata shareFraction) external restricted nonReentrant {
        Fraction memory dilution =
            Fraction(shareFraction.denominator - shareFraction.numerator, shareFraction.denominator);
        for (uint256 i = 0; i < shareholders.length - 1; i++) {
            if (shareholders[i] == shareholder) {
                revert ShareholderAlreadyAdded();
            }
            _shareFractions[i].numerator = _shareFractions[i].numerator * dilution.numerator;
            _shareFractions[i].denominator = _shareFractions[i].denominator * dilution.denominator;
        }
        shareholders.push(shareholder);
        _shareFractions.push(shareFraction);
        sharesOwed.push(0);
        uint128 chmBalance = uint128(CHM_TOKEN.balanceOf(address(this)));
        if (shareholders.length == 1) {
            sharesOwed[0] = chmBalance;
            totalSharesOwed = chmBalance;
        } else {
            _allocateSharesFromFractions();
        }
    }

    function _allocateSharesFromFractions() internal vestingNotStarted {
        uint128 chmBalance = uint128(CHM_TOKEN.balanceOf(address(this)));
        if (chmBalance == 0 || shareholders.length == 0 || _shareFractions.length == 0) {
            revert NothingToRelease();
        }
        totalSharesOwed = 0;
        for (uint256 i = 0; i < shareholders.length - 1; i++) {
            sharesOwed[i] = (chmBalance * _shareFractions[i].numerator / _shareFractions[i].denominator);
            totalSharesOwed += sharesOwed[i];
        }
    }

    function _assignGovernanceTokens() internal vestingNotStarted {
        for (uint256 i = 0; i < shareholders.length; i++) {
            CHM_ICO_GOVERNANCE_TOKEN.transfer(shareholders[i], sharesOwed[i]);
        }
    }

    function _startVestingBoilerplate() internal override {
        _allocateSharesFromFractions();
        _assignGovernanceTokens();
        super._startVestingBoilerplate();
    }
}
