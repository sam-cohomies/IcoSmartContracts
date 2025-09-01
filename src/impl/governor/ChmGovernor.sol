// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.30;

import {GovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {Errors} from "../../utils/Errors.sol";

contract ChmGovernor is GovernorUpgradeable, AccessManaged {
    uint256 private constant VOTING_PERIOD_BLOCKS = 2 weeks / 12; // 2 weeks in blocks (assuming 12 seconds per block)
    uint256 private constant VETO_THRESHOLD_PERCENTAGE = 70; // 70% of total supply required to veto a proposal

    constructor(
        ERC20Votes _chmIcoGovernanceToken,
        ERC20Votes _chmToken,
        TimelockController _timelockController,
        address accessControlManager
    ) AccessManaged(accessControlManager) {
        if (
            address(_chmIcoGovernanceToken) == address(0) || address(_chmToken) == address(0)
                || address(_timelockController) == address(0)
        ) {
            revert Errors.ZeroAddressNotAllowed();
        }
        _timelockController.grantRole(_timelockController.PROPOSER_ROLE(), address(this));
        _timelockController.grantRole(_timelockController.EXECUTOR_ROLE(), address(this));
        _timelockController.grantRole(_timelockController.CANCELLER_ROLE(), address(this));
        _timelockController.revokeRole(_timelockController.DEFAULT_ADMIN_ROLE(), msg.sender);
    }
}
