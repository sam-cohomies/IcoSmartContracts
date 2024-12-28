// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "lib/forge-std/src/Test.sol";
import {AccessManager} from "lib/openzeppelin-contracts/contracts/access/manager/AccessManager.sol";
import {CHMToken} from "../src/CHMToken.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";

contract CHMTokenTest is Test {
    AccessManager private manager;
    CHMToken private token;

    address private deployer = address(1);
    address private userPauser = address(2);
    address private userNonPauser = address(3);

    function setUp() public {
        // Deploy the token contract
        vm.startPrank(deployer);
        manager = new AccessManager(deployer);
        token = new CHMToken(address(manager), deployer);
        vm.stopPrank();
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

    function testTransfer() public {
        // Transfer tokens and verify balances
        uint256 transferAmount = 1_000 * 10 ** 18;

        // Fund deployer with tokens
        vm.prank(deployer);
        token.transfer(userPauser, transferAmount);

        // Check balances
        uint256 userBalance = token.balanceOf(userPauser);
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
        token.transfer(userPauser, transferAmount);
    }
}
