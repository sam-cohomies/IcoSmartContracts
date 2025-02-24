// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ChmBaseVesting} from "./ChmBaseVesting.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {TokensVested} from "./utils/Structs.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

using SafeERC20 for IERC20;

/// @custom:security-contact sam@cohomies.io
abstract contract ChmSharesVesting is ChmBaseVesting {
    constructor(uint256 delay, uint256 cliff, uint256 duration, address _accessControlManager)
        ChmBaseVesting(delay, cliff, duration)
        AccessManaged(_accessControlManager)
    {}

    function beginVesting(address[] memory _shareholders, uint128[] memory _shares) external restricted {
        (uint256 _chmBalance, ERC20Burnable chmToken) = _beginVestingSetUp(_shareholders, _shares);
        uint128 totalShares = 0;
        uint256 maxShares = 0;
        address maxSharesAddress;
        for (uint256 i = 0; i < _shareholders.length; i++) {
            totalShares += _shares[i];
            if (_shares[i] > maxShares) {
                maxShares = _shares[i];
                maxSharesAddress = _shareholders[i];
            }
        }
        if (totalShares == 0) {
            revert NothingToRelease();
        }
        uint128 chmBalance = uint128(_chmBalance);
        for (uint256 i = 0; i < _shareholders.length; i++) {
            userVesting[_shareholders[i]] = TokensVested(0, chmBalance * _shares[i] / totalShares);
        }
        chmBalance = uint128(chmToken.balanceOf(address(this)));
        if (chmBalance > 0) {
            userVesting[maxSharesAddress].total += chmBalance;
        }
        _beginVestingFinishUp();
    }
}
