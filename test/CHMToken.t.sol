// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {console, Test} from "lib/forge-std/src/Test.sol";
import {AccessManager} from "lib/openzeppelin-contracts/contracts/access/manager/AccessManager.sol";
import {CHMToken} from "../src/CHMToken.sol";
import {IERC20Errors} from "lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";
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
    address private spender = address(7);
    address private recipient = address(8);

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

    function testTransferInsufficientFunds() public {
        // Attempt to transfer more tokens than the sender has
        uint256 transferAmount = 3 * 10 ** (9 + 18);

        // Attempt to transfer more tokens than the sender has
        vm.prank(deployer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, deployer, 2 * 10 ** (9 + 18), transferAmount
            )
        );
        token.transfer(userNonPauser, transferAmount);
    }

    function testApproveSetsAllowance() public {
        uint256 allowanceAmount = 500 * 10 ** token.decimals();

        // Approve spender to spend deployer's tokens
        vm.prank(deployer);
        token.approve(spender, allowanceAmount);

        // Check that allowance is set
        assertEq(token.allowance(deployer, spender), allowanceAmount);
    }

    function testTransferFromRespectsAllowance() public {
        uint256 allowanceAmount = 500 * 10 ** token.decimals();
        uint256 transferAmount = 200 * 10 ** token.decimals();

        // Approve spender
        vm.prank(deployer);
        token.approve(spender, allowanceAmount);

        // Transfer tokens on behalf of deployer
        vm.prank(spender);
        token.transferFrom(deployer, recipient, transferAmount);

        // Check recipient balance
        assertEq(token.balanceOf(recipient), transferAmount);

        // Check allowance is reduced
        assertEq(token.allowance(deployer, spender), allowanceAmount - transferAmount);
    }

    function testTransferFromFailsForInsufficientAllowance() public {
        uint256 allowanceAmount = 500 * 10 ** token.decimals();
        uint256 transferAmount = 600 * 10 ** token.decimals();

        // Approve spender
        vm.prank(deployer);
        token.approve(spender, allowanceAmount);

        // Attempt to transfer more than allowed
        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, spender, allowanceAmount, transferAmount
            )
        );
        token.transferFrom(deployer, recipient, transferAmount);
    }

    function testRevokeAllowance() public {
        uint256 allowanceAmount = 500 * 10 ** token.decimals();

        // Approve spender
        vm.prank(deployer);
        token.approve(spender, allowanceAmount);

        // Revoke allowance
        vm.prank(deployer);
        token.approve(spender, 0);

        // Attempt to transfer
        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 500 * 10 ** 18)
        );
        token.transferFrom(deployer, recipient, allowanceAmount);
    }

    function testTransferFromFailsWithNoAllowance() public {
        uint256 transferAmount = 100 * 10 ** token.decimals();

        // Attempt to transfer without approval
        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, transferAmount)
        );
        token.transferFrom(deployer, recipient, transferAmount);
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
