// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {User} from "./utils/Structs.sol";
import {TokensVested} from "./utils/Structs.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

using SafeERC20 for IERC20;

/// @custom:security-contact sam@cohomies.io
contract ChmPublicVesting is AccessManaged, ReentrancyGuard {
    error MismatchedInputLengths(uint256 usersLength, uint256 chmOwedLength);
    error NothingToRelease();
    error ChmAddressNotSet();
    error VestingAlreadyBegun(uint256 start);
    error VestingNotBegun();

    event VestingBegun();
    event Released();

    mapping(address => TokensVested) private userVesting;

    address private chmTokenAddress;

    uint256 private start;
    uint256 private constant DELAY = 2 days;
    uint256 private constant DURATION = 30 days;

    constructor(address _accessControlManager) AccessManaged(_accessControlManager) {}

    function setChmTokenAddress(address _chmTokenAddress) external restricted {
        chmTokenAddress = _chmTokenAddress;
    }

    function beginVesting(address[] memory _users, uint128[] memory _chmOwed, uint256 _chmSold) external restricted {
        if (_users.length != _chmOwed.length) {
            revert MismatchedInputLengths(_users.length, _chmOwed.length);
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
        for (uint256 i = 0; i < _users.length; i++) {
            userVesting[_users[i]] = TokensVested(0, _chmOwed[i]);
        }
        if (chmBalance > _chmSold) {
            // TODO: Work out what to do with unsold tokens, currently sending them to the contract owner
            chmToken.safeTransfer(msg.sender, chmBalance - _chmSold);
        }
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

    function _vestingSchedule(address _user) private view returns (uint128) {
        if (block.timestamp < start) {
            return 0;
        }
        uint256 timeElapsed = block.timestamp - start;
        if (timeElapsed > DURATION) {
            return userVesting[_user].total;
        }
        return uint128(userVesting[_user].total * timeElapsed / DURATION);
    }
}
