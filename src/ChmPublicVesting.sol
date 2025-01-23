// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ChmBaseVesting} from "./ChmBaseVesting.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {User} from "./utils/Structs.sol";
import {TokensVested} from "./utils/Structs.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

/// @custom:security-contact sam@cohomies.io
contract ChmPublicVesting is ChmBaseVesting {
    constructor(address _accessControlManager)
        ChmBaseVesting(2 days, 0, 30 days)
        AccessManaged(_accessControlManager)
    {}

    function beginVesting(address[] memory _users, uint128[] memory _chmOwed, uint256 _chmSold) external restricted {
        (uint256 chmBalance, IERC20 chmToken) = _beginVestingSetUp(_users, _chmOwed);
        for (uint256 i = 0; i < _users.length; i++) {
            userVesting[_users[i]] = TokensVested(0, _chmOwed[i]);
        }
        if (chmBalance > _chmSold) {
            // TODO: Work out what to do with unsold tokens, currently sending them to the contract owner
            chmToken.safeTransfer(msg.sender, chmBalance - _chmSold);
        }
        _beginVestingFinishUp();
    }
}
