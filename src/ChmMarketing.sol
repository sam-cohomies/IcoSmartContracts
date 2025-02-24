// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ChmSharesVesting} from "./ChmSharesVesting.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {TokensVested} from "./utils/Structs.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

using SafeERC20 for IERC20;

contract ChmAdvisorVesting is ChmSharesVesting {
    constructor(address _accessControlManager) ChmSharesVesting(2 days, 0, 30 days, _accessControlManager) {}
}
