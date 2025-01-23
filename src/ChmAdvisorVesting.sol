// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ChmBaseVesting} from "./ChmBaseVesting.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {TokensVested} from "./utils/Structs.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

/// @custom:security-contact sam@cohomies.io
contract ChmAdvisorVesting is ChmBaseVesting {
    constructor(address _accessControlManager)
        ChmBaseVesting(0, 365 days, 2 * 365 days)
        AccessManaged(_accessControlManager)
    {}

    function beginVesting(address[] memory _advisors, uint128[] memory _shares) external restricted {
        (uint256 _chmBalance, IERC20 chmToken) = _beginVestingSetUp(_advisors, _shares);
        uint128 totalShares = 0;
        uint256 maxShares = 0;
        address maxSharesAddress;
        for (uint256 i = 0; i < _advisors.length; i++) {
            totalShares += _shares[i];
            if (_shares[i] > maxShares) {
                maxShares = _shares[i];
                maxSharesAddress = _advisors[i];
            }
        }
        uint128 chmBalance = uint128(_chmBalance);
        for (uint256 i = 0; i < _advisors.length; i++) {
            userVesting[_advisors[i]] = TokensVested(0, chmBalance * _shares[i] / totalShares);
        }
        chmBalance = uint128(chmToken.balanceOf(address(this)));
        if (chmBalance > 0) {
            userVesting[maxSharesAddress].total += chmBalance;
        }
        _beginVestingFinishUp();
    }
}
