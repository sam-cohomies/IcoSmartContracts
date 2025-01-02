// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {TeamMember} from "./utils/Structs.sol";
import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

using SafeERC20 for IERC20;

/// @custom:security-contact sam@cohomies.io
contract ChmTeamVesting is AccessManaged, ReentrancyGuard {
    event VestingBegun(uint128[] ids, address[] addresses);

    TeamMember[] private teamMembers;

    uint256 private totalShares;

    address private chmTokenAddress;

    constructor(address _accessControlManager, TeamMember[] memory _teamMembers) AccessManaged(_accessControlManager) {
        for (uint256 i = 0; i < _teamMembers.length; i++) {
            teamMembers.push(_teamMembers[i]);
            totalShares += _teamMembers[i].shares;
        }
    }

    function setChmTokenAddress(address _chmTokenAddress) external restricted {
        chmTokenAddress = _chmTokenAddress;
    }

    function beginVesting() external restricted nonReentrant {
        address[] memory addresses = new address[](teamMembers.length);
        uint128[] memory ids = new uint128[](teamMembers.length);
        // get the total number of chm tokens in this contract
        IERC20 chmToken = IERC20(chmTokenAddress);
        uint256 chmBalance = chmToken.balanceOf(address(this));
        uint128 maxShares = 0;
        address maxSharesAddress;
        for (uint256 i = 0; i < teamMembers.length; i++) {
            VestingWallet vestingWallet =
                new VestingWallet(teamMembers[i].member, uint64(block.timestamp), uint64(3 * 365 days));
            address vestingWalletAddress = address(vestingWallet);
            chmToken.safeTransfer(vestingWalletAddress, chmBalance * teamMembers[i].shares / totalShares);
            vestingWallet.transferOwnership(teamMembers[i].member);
            addresses[i] = address(vestingWalletAddress);
            if (teamMembers[i].shares > maxShares) {
                maxShares = teamMembers[i].shares;
                maxSharesAddress = vestingWalletAddress;
            }
            ids[i] = teamMembers[i].id;
        }
        chmBalance = chmToken.balanceOf(address(this));
        if (chmBalance > 0) {
            chmToken.safeTransfer(maxSharesAddress, chmBalance);
        }
        emit VestingBegun(ids, addresses);
    }
}
