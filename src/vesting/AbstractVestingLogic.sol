// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.30;

import {IVestingLogic} from "../interfaces/IVestingLogic.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {Errors} from "../utils/Errors.sol";
import {VestingUser, VestingTerms} from "../utils/Structs.sol";
import {ChmBaseToken} from "../tokens/ChmBaseToken.sol";

abstract contract AbstractVestingLogic is IVestingLogic, AccessManaged {
    error NothingToRelease();
    error VestingAlreadyBegun(uint256 start);
    error VestingNotBegun();

    event VestingStarted(address indexed user, uint256 amount);
    event TokensReleased(address indexed user, uint256 amount);

    mapping(address => VestingUser) internal _vestingUsers;

    ChmBaseToken public immutable CHM_TOKEN;
    ChmBaseToken public immutable CHM_ICO_GOVERNANCE_TOKEN;

    uint32 public immutable DELAY_;
    uint32 public immutable CLIFF_;
    uint32 public immutable DURATION_;
    uint32 public start;

    constructor(
        address accessControlManager_,
        address chmToken_,
        address chmIcoGovernanceToken_,
        VestingTerms memory vestingTerms_
    ) AccessManaged(accessControlManager_) {
        if (chmToken_ == address(0) || chmIcoGovernanceToken_ == address(0)) {
            revert Errors.ZeroAddressNotAllowed();
        }
        DELAY_ = vestingTerms_.delay;
        CLIFF_ = vestingTerms_.cliffDuration;
        DURATION_ = vestingTerms_.vestingDuration;
        CHM_TOKEN = ChmBaseToken(chmToken_);
        CHM_ICO_GOVERNANCE_TOKEN = ChmBaseToken(chmIcoGovernanceToken_);
    }
}
