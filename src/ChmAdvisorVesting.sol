// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {TokensVested} from "./utils/Structs.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

/// @custom:security-contact sam@cohomies.io
contract ChmAdvisorVesting is AccessManaged, ReentrancyGuard {
    error MismatchedInputLengths(uint256 advisorLength, uint256 sharesLength);
    error NothingToRelease();
    error ChmAddressNotSet();
    error VestingAlreadyBegun(uint256 start);
    error VestingNotBegun();

    event VestingBegun();
    event Released();

    mapping(address => uint256) private advisorShares;

    mapping(address => TokensVested) private advisorVesting;

    address private chmTokenAddress;

    uint256 private totalShares;

    uint256 private start;
    uint256 private constant CLIFF = 365 days;
    uint256 private constant DURATION = 2 * 365 days;

    constructor(address _accessControlManager) AccessManaged(_accessControlManager) {}

    function setChmTokenAddress(address _chmTokenAddress) external restricted {
        chmTokenAddress = _chmTokenAddress;
    }

    function beginVesting(address[] memory _advisors, uint256[] memory _shares) external restricted {
        if (_advisors.length != _shares.length) {
            revert MismatchedInputLengths(_advisors.length, _shares.length);
        }
        if (chmTokenAddress == address(0)) {
            revert ChmAddressNotSet();
        }
        if (start != 0) {
            revert VestingAlreadyBegun(start);
        }
        IERC20 chmToken = IERC20(chmTokenAddress);
        uint256 chmBalance = chmToken.balanceOf(address(this));
        if (chmBalance == 0) {
            revert NothingToRelease();
        }
        for (uint256 i = 0; i < _advisors.length; i++) {
            advisorShares[_advisors[i]] = _shares[i];
            totalShares += _shares[i];
        }
        uint256 maxShares = 0;
        address maxSharesAddress;
        for (uint256 i = 0; i < _advisors.length; i++) {
            advisorVesting[_advisors[i]] = TokensVested(0, uint128(chmBalance * _shares[i] / totalShares));
            if (_shares[i] > maxShares) {
                maxShares = _shares[i];
                maxSharesAddress = _advisors[i];
            }
        }
        chmBalance = chmToken.balanceOf(address(this));
        if (chmBalance > 0) {
            advisorVesting[maxSharesAddress].total += uint128(chmBalance);
        }
        start = block.timestamp;
        emit VestingBegun();
    }

    function release() external nonReentrant {
        if (start == 0) {
            revert VestingNotBegun();
        }
        uint128 amount = _vestingSchedule(msg.sender) - advisorVesting[msg.sender].released;
        if (amount == 0) {
            revert NothingToRelease();
        }
        advisorVesting[msg.sender].released += amount;
        IERC20(chmTokenAddress).safeTransfer(msg.sender, amount);
        emit Released();
    }

    function released() external view returns (uint256) {
        return advisorVesting[msg.sender].released;
    }

    function totalAmount() external view returns (uint256) {
        return advisorVesting[msg.sender].total;
    }

    function vestedAmount(address advisor) external view returns (uint256) {
        return _vestingSchedule(advisor);
    }

    function _vestingSchedule(address advisor) internal view returns (uint128) {
        if (block.timestamp < start + CLIFF) {
            return 0;
        } else if (block.timestamp >= start + DURATION) {
            return advisorVesting[advisor].total;
        } else {
            return uint128(advisorVesting[advisor].total * (block.timestamp - start) / DURATION);
        }
    }
}
