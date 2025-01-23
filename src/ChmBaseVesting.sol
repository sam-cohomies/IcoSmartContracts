// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {TokensVested} from "./utils/Structs.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

/// @custom:security-contact sam@cohomies.io
abstract contract ChmBaseVesting is AccessManaged, ReentrancyGuard {
    error MismatchedInputLengths(uint256 usersLength, uint256 chmOwedLength);
    error NothingToRelease();
    error ChmAddressNotSet();
    error VestingAlreadyBegun(uint256 start);
    error VestingNotBegun();

    event VestingBegun();
    event Released();

    mapping(address => TokensVested) internal userVesting;

    address public chmTokenAddress;

    uint256 public start;
    uint256 public immutable DELAY;
    uint256 public immutable CLIFF;
    uint256 public immutable DURATION;

    constructor(uint256 delay, uint256 cliff, uint256 duration) {
        DELAY = delay;
        CLIFF = cliff;
        DURATION = duration;
    }

    function setChmTokenAddress(address _chmTokenAddress) external restricted {
        chmTokenAddress = _chmTokenAddress;
    }

    function _beginVestingSetUp(address[] memory _users, uint128[] memory _chmOwed)
        internal
        view
        returns (uint256, IERC20)
    {
        if (start != 0) {
            revert VestingAlreadyBegun(start);
        }
        if (chmTokenAddress == address(0)) {
            revert ChmAddressNotSet();
        }
        if (_users.length != _chmOwed.length) {
            revert MismatchedInputLengths(_users.length, _chmOwed.length);
        }
        IERC20 chmToken = IERC20(chmTokenAddress);
        uint256 chmBalance = chmToken.balanceOf(address(this));
        if (chmBalance == 0) {
            revert NothingToRelease();
        }
        return (chmBalance, chmToken);
    }

    function _beginVestingFinishUp() internal {
        start = block.timestamp + DELAY;
        emit VestingBegun();
    }

    function release() external nonReentrant {
        if (start == 0) {
            revert VestingNotBegun();
        }
        uint128 amount = _vestingSchedule(msg.sender) - userVesting[msg.sender].released;
        if (amount == 0) {
            revert NothingToRelease();
        }
        userVesting[msg.sender].released += amount;
        IERC20(chmTokenAddress).safeTransfer(msg.sender, amount);
        emit Released();
    }

    function released() external view returns (uint256) {
        return userVesting[msg.sender].released;
    }

    function totalAmount() external view returns (uint256) {
        return userVesting[msg.sender].total;
    }

    function vestedAmount(address user) external view returns (uint256) {
        return _vestingSchedule(user);
    }

    function _vestingSchedule(address user) internal view returns (uint128) {
        if (block.timestamp < start + CLIFF) {
            return 0;
        } else if (block.timestamp >= start + DURATION) {
            return userVesting[user].total;
        } else {
            return uint128(userVesting[user].total * (block.timestamp - start) / DURATION);
        }
    }
}
