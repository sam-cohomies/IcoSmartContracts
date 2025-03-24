// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {User} from "../utils/Structs.sol";
import {ChmBaseToken} from "../tokens/ChmBaseToken.sol";

/// @custom:security-contact sam@cohomies.io
abstract contract ChmBaseVesting is AccessManaged, ReentrancyGuard {
    error NothingToRelease();
    error ChmAddressNotSet();
    error VestingAlreadyBegun(uint256 start);
    error VestingNotBegun();
    error TransferFailed();

    event VestingBegun();
    event Released();

    mapping(address => User) internal _userVesting;

    ChmBaseToken public immutable CHM_TOKEN;
    ChmBaseToken public immutable CHM_ICO_GOVERNANCE_TOKEN;

    uint256 public start;
    uint256 public immutable DELAY_;
    uint256 public immutable CLIFF_;
    uint256 public immutable DURATION_;

    constructor(
        address accessControlManager_,
        address chmToken_,
        address chmIcoGovernanceToken_,
        uint256 delay_,
        uint256 cliff_,
        uint256 duration_
    ) AccessManaged(accessControlManager_) {
        if (chmToken_ == address(0)) {
            revert ChmAddressNotSet();
        }
        DELAY_ = delay_;
        CLIFF_ = cliff_;
        DURATION_ = duration_;
        CHM_TOKEN = ChmBaseToken(chmToken_);
        CHM_ICO_GOVERNANCE_TOKEN = ChmBaseToken(chmIcoGovernanceToken_);
    }

    modifier vestingNotStarted() {
        if (start != 0) {
            revert VestingAlreadyBegun(start);
        }
        _;
    }

    function _startVestingBoilerplate() internal virtual {
        start = block.timestamp + DELAY_;
        emit VestingBegun();
    }

    function startVesting() public restricted vestingNotStarted {
        _startVestingBoilerplate();
    }

    function release(address user, uint8 v, bytes32 r, bytes32 s) external nonReentrant {
        if (start == 0) {
            revert VestingNotBegun();
        }
        uint128 amount = _vestingSchedule(user) - _userVesting[user].chmReleased;
        if (amount == 0) {
            revert NothingToRelease();
        }
        _userVesting[user].chmReleased += amount;
        if (!CHM_TOKEN.approve(user, amount)) {
            revert TransferFailed();
        }
        CHM_ICO_GOVERNANCE_TOKEN.permit(user, address(this), amount, block.timestamp, v, r, s);
        CHM_ICO_GOVERNANCE_TOKEN.burnFrom(user, amount);
    }

    function released(address user) external restricted returns (uint128) {
        return _userVesting[user].chmReleased;
    }

    function totalOwed(address user) external restricted returns (uint128) {
        return _userVesting[user].chmOwed;
    }

    function vestedAmount(address user) external restricted returns (uint128) {
        return _vestingSchedule(user);
    }

    function released() external view returns (uint128) {
        return _userVesting[msg.sender].chmReleased;
    }

    function totalOwed() external view returns (uint128) {
        return _userVesting[msg.sender].chmOwed;
    }

    function vestedAmount() external view returns (uint128) {
        return _vestingSchedule(msg.sender);
    }

    function _vestingSchedule(address user) internal view returns (uint128) {
        if (block.timestamp < start + CLIFF_) {
            return 0;
        } else if (block.timestamp >= start + DURATION_) {
            return _userVesting[user].chmOwed;
        } else {
            return uint128((_userVesting[user].chmOwed * (block.timestamp - start)) / DURATION_);
        }
    }
}
