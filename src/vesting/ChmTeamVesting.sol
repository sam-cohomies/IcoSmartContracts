// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ChmSharesVesting} from "./ChmSharesVesting.sol";
import {Fraction} from "../utils/Structs.sol";

/// @custom:security-contact sam@cohomies.io
contract ChmTeamVesting is ChmSharesVesting {
    Fraction[] internal shareFractions;

    constructor(address _accessControlManager, address _chmToken)
        ChmSharesVesting(_accessControlManager, _chmToken, 0, 365 days, 365 days, 0)
    {}

    function addShareholder(address shareholder, Fraction calldata shareFraction) external restricted {
        shareholders.push(shareholder);
        shareFractions.push(shareFraction);
    }

    function _allocateSharesFromFractions() internal vestingNotStarted {
        uint128 chmBalance = uint128(CHM_TOKEN.balanceOf(address(this)));
        if (chmBalance == 0 || shareholders.length == 0 || shareFractions.length == 0) {
            revert NothingToRelease();
        }
        for (uint256 i = 1; i < shareholders.length; i++) {
            Fraction memory dilution =
                Fraction(shareFractions[i].denominator - shareFractions[i].numerator, shareFractions[i].denominator);
            for (uint256 j = 0; j < i; j++) {
                shareFractions[j].numerator = shareFractions[j].numerator * dilution.numerator;
                shareFractions[j].denominator = shareFractions[j].denominator * dilution.denominator;
            }
        }
        for (uint256 i = 0; i < shareholders.length; i++) {
            sharesOwed.push(chmBalance * shareFractions[i].numerator / shareFractions[i].denominator);
            totalSharesOwed += sharesOwed[i];
        }
    }

    function _startVestingBoilerplate() internal override {
        _allocateSharesFromFractions();
        super._startVestingBoilerplate();
    }
}
