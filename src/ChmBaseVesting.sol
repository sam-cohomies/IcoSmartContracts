// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {User} from "./utils/Structs.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {IWETH} from "./interfaces/IWETH.sol";

using SafeERC20 for IERC20;

/// @custom:security-contact sam@cohomies.io
abstract contract ChmBaseVesting is AccessManaged, ReentrancyGuard {
    error NothingToRelease();
    error ChmAddressNotSet();
    error VestingAlreadyBegun(uint256 start);
    error VestingNotBegun();
    error TransferFailed();

    event VestingBegun();
    event Released();

    mapping(address => User) internal userVesting;

    ERC20Burnable public immutable CHM_TOKEN;

    uint256 public start;
    uint256 public immutable DELAY;
    uint256 public immutable CLIFF;
    uint256 public immutable DURATION;

    constructor(address _accessControlManager, address _chmToken, uint256 delay, uint256 cliff, uint256 duration)
        AccessManaged(_accessControlManager)
    {
        if (_chmToken == address(0)) {
            revert ChmAddressNotSet();
        }
        DELAY = delay;
        CLIFF = cliff;
        DURATION = duration;
        CHM_TOKEN = ERC20Burnable(_chmToken);
    }

    modifier vestingStart() {
        if (start != 0) {
            revert VestingAlreadyBegun(start);
        }
        _;
    }

    function _beginVesting() internal {
        start = block.timestamp + DELAY;
        emit VestingBegun();
    }

    function release(address user) external nonReentrant {
        if (start == 0) {
            revert VestingNotBegun();
        }
        uint128 amount = _vestingSchedule(user) - userVesting[user].chmReleased;
        if (amount == 0) {
            revert NothingToRelease();
        }
        userVesting[user].chmReleased += amount;
        if (!CHM_TOKEN.approve(user, amount)) {
            revert TransferFailed();
        }
    }

    function released() external view returns (uint128) {
        return userVesting[msg.sender].chmReleased;
    }

    function totalOwed() external view returns (uint128) {
        return userVesting[msg.sender].chmOwed;
    }

    function vestedAmount(address user) external view returns (uint128) {
        return _vestingSchedule(user);
    }

    function _vestingSchedule(address user) internal view returns (uint128) {
        if (block.timestamp < start + CLIFF) {
            return 0;
        } else if (block.timestamp >= start + DURATION) {
            return userVesting[user].chmOwed;
        } else {
            return uint128((userVesting[user].chmOwed * (block.timestamp - start)) / DURATION);
        }
    }
}
