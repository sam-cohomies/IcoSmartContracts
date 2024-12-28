// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {console, Test} from "lib/forge-std/src/Test.sol";
import {AccessManager} from "lib/openzeppelin-contracts/contracts/access/manager/AccessManager.sol";
import {CHMToken} from "../src/CHMToken.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {Role, RoleUtility} from "../src/RoleUtility.sol";

contract CHMTokenTest is Test {
    AccessManager private manager;
    CHMToken private token;
    RoleUtility private roleUtility;

    address private deployer = address(1);
    address private userNonPauser = address(2);
    address private userPauserNoDelay = address(3);
    address private userPauserDelay = address(4);
    address private pauserGuardian = address(5);
    address private pauserAdmin = address(6);

    function setUp() public {
        // Deploy the token contract
        vm.startPrank(deployer);
        manager = new AccessManager(deployer);
        token = new CHMToken(address(manager), deployer);

        string[] memory roles = new string[](1);
        roles[0] = "CHM_TOKEN_PAUSER";
        roleUtility = new RoleUtility(address(manager), roles);

        bytes4[] memory pauserSelectors = new bytes4[](2);
        pauserSelectors[0] = token.pause.selector;
        pauserSelectors[1] = token.unpause.selector;
        _restrictFunctions(address(token), pauserSelectors, "CHM_TOKEN_PAUSER");

        Role memory roleData = roleUtility.getRoleIds("CHM_TOKEN_PAUSER");
        manager.setRoleAdmin(roleData.roleId, manager.ADMIN_ROLE());
        manager.setRoleAdmin(roleData.guardianRoleId, manager.ADMIN_ROLE());
        manager.setRoleAdmin(roleData.adminRoleId, manager.ADMIN_ROLE());
        manager.grantRole(roleData.roleId, deployer, 0);
        manager.grantRole(roleData.roleId, userPauserNoDelay, 0);
        manager.grantRole(roleData.roleId, userPauserDelay, 10);
        manager.grantRole(roleData.guardianRoleId, pauserGuardian, 0);
        manager.grantRole(roleData.adminRoleId, pauserAdmin, 0);

        vm.stopPrank();
    }

    function _restrictFunctions(address target, bytes4[] memory selectors, string memory role) internal {
        Role memory roleData = roleUtility.getRoleIds(role);
        manager.setTargetFunctionRole(target, selectors, roleData.roleId);
        manager.setRoleGuardian(roleData.roleId, roleData.guardianRoleId);
        manager.setRoleAdmin(roleData.roleId, roleData.adminRoleId);
        manager.setRoleAdmin(roleData.guardianRoleId, roleData.adminRoleId);
        manager.labelRole(roleData.roleId, role);
        manager.labelRole(roleData.guardianRoleId, string(abi.encodePacked(role, "_GUARDIAN")));
        manager.labelRole(roleData.adminRoleId, string(abi.encodePacked(role, "_ADMIN")));
    }

    function testTokenName() public view {
        // Verify the token name
        string memory name = token.name();
        assertEq(name, "CoHomies", "Token name mismatch");
    }

    function testTokenSymbol() public view {
        // Verify the token symbol
        string memory symbol = token.symbol();
        assertEq(symbol, "CHM", "Token symbol mismatch");
    }

    function testInitialSupply() public view {
        // Verify the total supply matches the initial supply
        uint256 totalSupply = token.totalSupply();
        assertEq(totalSupply, 2 * 10 ** (9 + 18), "Initial supply mismatch");
    }

    function testTransferSuccess() public {
        // Transfer tokens and verify balances
        uint256 transferAmount = 1_000 * 10 ** 18;

        // Fund deployer with tokens
        vm.prank(deployer);
        token.transfer(userNonPauser, transferAmount);

        // Check balances
        uint256 userBalance = token.balanceOf(userNonPauser);
        uint256 deployerBalance = token.balanceOf(deployer);

        assertEq(userBalance, transferAmount, "User balance mismatch");
        assertEq(deployerBalance, 2 * 10 ** (9 + 18) - transferAmount, "Deployer balance mismatch");
    }

    function testPauseAndUnpause() public {
        // Test pausing and unpausing the contract
        vm.prank(deployer);
        token.pause();

        // Verify the contract is paused
        bool paused = token.paused();
        assertTrue(paused, "Token should be paused");

        vm.prank(deployer);
        token.unpause();

        // Verify the contract is unpaused
        paused = token.paused();
        assertFalse(paused, "Token should be unpaused");
    }

    function testCannotTransferWhenPaused() public {
        uint256 transferAmount = 1_000 * 10 ** 18;

        // Pause the contract
        vm.prank(deployer);
        token.pause();

        // Attempt to transfer while paused
        vm.prank(deployer);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.transfer(userNonPauser, transferAmount);
    }
}
