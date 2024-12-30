// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "lib/forge-std/src/Test.sol";
import {AccessManager} from "lib/openzeppelin-contracts/contracts/access/manager/AccessManager.sol";
import {CHMToken} from "../src/CHMToken.sol";
import {ERC20Permit} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IAccessManaged} from "lib/openzeppelin-contracts/contracts/access/manager/IAccessManaged.sol";
import {IAccessManager} from "lib/openzeppelin-contracts/contracts/access/manager/IAccessManager.sol";
import {IERC20Errors} from "lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {Role, RoleUtility} from "../src/RoleUtility.sol";

/// @custom:security-contact sam@cohomies.io
contract CHMTokenTest is Test {
    AccessManager private manager;
    CHMToken private token;
    RoleUtility private roleUtility;

    uint256 private constant DEPLOYER_PRIVATE_KEY = 1;
    uint256 private constant USER_NON_PAUSER_PRIVATE_KEY = 2;
    uint256 private constant USER_PAUSER_NO_DELAY_PRIVATE_KEY = 3;
    uint256 private constant USER_PAUSER_DELAY_PRIVATE_KEY = 4;
    uint256 private constant PAUSER_GUARDIAN_PRIVATE_KEY = 5;
    uint256 private constant PAUSER_ADMIN_PRIVATE_KEY = 6;
    uint256 private constant SPENDER_PRIVATE_KEY = 7;
    uint256 private constant RECIPIENT_PRIVATE_KEY = 8;
    uint256 private constant PRESALE_PRIVATE_KEY = 9;
    uint256 private constant MARKETING_PRIVATE_KEY = 10;
    uint256 private constant EXCHANGE_PRIVATE_KEY = 11;
    uint256 private constant TEAM_PRIVATE_KEY = 12;
    uint256 private constant ADVISORS_PRIVATE_KEY = 13;
    address private deployer;
    address private userNonPauser;
    address private userPauserNoDelay;
    address private userPauserDelay;
    address private pauserGuardian;
    address private pauserAdmin;
    address private spender;
    address private recipient;
    address private presale;
    address private marketing;
    address private exchange;
    address private team;
    address private advisors;

    uint32 private constant DELAY = 100;

    function setUp() public {
        // Derive addresses
        deployer = vm.addr(DEPLOYER_PRIVATE_KEY);
        userNonPauser = vm.addr(USER_NON_PAUSER_PRIVATE_KEY);
        userPauserNoDelay = vm.addr(USER_PAUSER_NO_DELAY_PRIVATE_KEY);
        userPauserDelay = vm.addr(USER_PAUSER_DELAY_PRIVATE_KEY);
        pauserGuardian = vm.addr(PAUSER_GUARDIAN_PRIVATE_KEY);
        pauserAdmin = vm.addr(PAUSER_ADMIN_PRIVATE_KEY);
        spender = vm.addr(SPENDER_PRIVATE_KEY);
        recipient = vm.addr(RECIPIENT_PRIVATE_KEY);
        presale = vm.addr(PRESALE_PRIVATE_KEY);
        marketing = vm.addr(MARKETING_PRIVATE_KEY);
        exchange = vm.addr(EXCHANGE_PRIVATE_KEY);
        team = vm.addr(TEAM_PRIVATE_KEY);
        advisors = vm.addr(ADVISORS_PRIVATE_KEY);

        // Deploy the token contract
        vm.startPrank(deployer);
        manager = new AccessManager(deployer);
        token = new CHMToken(address(manager), [presale, marketing, exchange, team, advisors]);

        string[] memory roles = new string[](1);
        roles[0] = "CHM_TOKEN_PAUSER";

        vm.expectEmit();
        Role memory role = Role(1, 2, 3);
        emit RoleUtility.RoleAdded(roles[0], role);

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
        manager.grantRole(roleData.roleId, userPauserDelay, DELAY);
        manager.grantRole(roleData.guardianRoleId, pauserGuardian, 0);
        manager.grantRole(roleData.adminRoleId, pauserAdmin, 0);
        manager.setRoleAdmin(roleData.roleId, roleData.adminRoleId);
        manager.setRoleAdmin(roleData.guardianRoleId, roleData.adminRoleId);

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
        // Verify that each allocation has the correct balance
        uint256[5] memory allocations = token.getAllocations();
        uint256 totalBalance = 0;

        for (uint256 i = 0; i < allocations.length; i++) {
            uint256 balance = token.remainingAllocation(CHMToken.AllocationType(i));
            assertEq(balance, allocations[i] * 10 ** token.decimals(), "Initial allocation balance mismatch");
            totalBalance += balance;
        }

        uint256 totalSupply = token.totalSupply();
        assertEq(totalSupply, totalBalance, "Initial supply mismatch");
    }

    function testTransferSuccess() public {
        // Transfer tokens and verify balances
        uint256 transferAmount = 1_000 * 10 ** token.decimals();

        // Transfer from presale to userNonPauser
        vm.prank(presale);
        token.transfer(userNonPauser, transferAmount);

        // Check balances
        uint256 userBalance = token.balanceOf(userNonPauser);
        uint256 presaleBalance = token.balanceOf(presale);

        assertEq(userBalance, transferAmount, "User balance mismatch");
        assertEq(
            presaleBalance,
            token.getAllocations()[0] * 10 ** token.decimals() - transferAmount,
            "Presale balance mismatch"
        );
    }

    function testTransferInsufficientFunds() public {
        // Attempt to transfer more tokens than the sender has
        uint256 transferAmount = 1 * 10 ** token.decimals();

        // Attempt to transfer more tokens than the sender has
        vm.prank(userNonPauser);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, userNonPauser, 0, transferAmount)
        );
        token.transfer(deployer, transferAmount);
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
        vm.prank(presale);
        token.approve(spender, allowanceAmount);

        // Transfer tokens on behalf of presale
        vm.prank(spender);
        token.transferFrom(presale, recipient, transferAmount);

        // Check recipient balance
        assertEq(token.balanceOf(recipient), transferAmount);

        // Check allowance is reduced
        assertEq(token.allowance(presale, spender), allowanceAmount - transferAmount);
    }

    function testTransferFromFailsForInsufficientAllowance() public {
        uint256 allowanceAmount = 500 * 10 ** token.decimals();
        uint256 transferAmount = 600 * 10 ** token.decimals();

        // Approve spender
        vm.prank(presale);
        token.approve(spender, allowanceAmount);

        // Attempt to transfer more than allowed
        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, spender, allowanceAmount, transferAmount
            )
        );
        token.transferFrom(presale, recipient, transferAmount);
    }

    function testRevokeAllowance() public {
        uint256 allowanceAmount = 500 * 10 ** token.decimals();

        // Approve spender
        vm.prank(presale);
        token.approve(spender, allowanceAmount);

        // Revoke allowance
        vm.prank(presale);
        token.approve(spender, 0);

        // Attempt to transfer
        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, allowanceAmount)
        );
        token.transferFrom(presale, recipient, allowanceAmount);
    }

    function testTransferFromFailsWithNoAllowance() public {
        uint256 transferAmount = 100 * 10 ** token.decimals();

        // Attempt to transfer without approval
        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, transferAmount)
        );
        token.transferFrom(presale, recipient, transferAmount);
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
        uint256 transferAmount = 1_000 * 10 ** token.decimals();

        // Pause the contract
        vm.prank(deployer);
        token.pause();

        // Attempt to transfer while paused
        vm.prank(presale);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.transfer(userNonPauser, transferAmount);
    }

    function testUnauthorizedPauseReverts() public {
        // Attempt to call `pause` as an unauthorized user
        vm.prank(userNonPauser);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, userNonPauser));
        token.pause();
    }

    function testUnauthorizedUnpauseReverts() public {
        // First, pause the contract using an authorized user
        vm.prank(deployer);
        token.pause();

        // Attempt to call `unpause` as an unauthorized user
        vm.prank(userNonPauser);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, userNonPauser));
        token.unpause();
    }

    function testImmediatePauserCanPauseAndUnpause() public {
        // Pause the contract
        vm.prank(userPauserNoDelay);
        token.pause();
        assertTrue(token.paused(), "Token should be paused");

        // Unpause the contract
        vm.prank(userPauserNoDelay);
        token.unpause();
        assertFalse(token.paused(), "Token should be unpaused");
    }

    function testDelayedPauserCanPauseAfterDelay() public {
        bytes memory pauseSelector = abi.encodeWithSelector(token.pause.selector);
        // Schedule pause
        vm.prank(userPauserDelay);
        manager.schedule(address(token), pauseSelector, uint48(block.timestamp + DELAY));
        assertFalse(token.paused(), "Token should not be paused immediately");

        // Move forward in time
        vm.warp(block.timestamp + DELAY);

        // Execute pause
        vm.prank(userPauserDelay);
        manager.execute(address(token), pauseSelector);
        assertTrue(token.paused(), "Token should be paused after delay");
    }

    function testGuardianCanCancelDelayedPause() public {
        bytes memory pauseSelector = abi.encodeWithSelector(token.pause.selector);
        // Schedule pause
        vm.prank(userPauserDelay);
        (bytes32 operationId,) = manager.schedule(address(token), pauseSelector, uint48(block.timestamp + DELAY));
        assertFalse(token.paused(), "Token should not be paused immediately");

        // Guardian cancels the scheduled pause
        vm.prank(pauserGuardian);
        manager.cancel(userPauserDelay, address(token), pauseSelector);

        // Move forward in time
        vm.warp(block.timestamp + DELAY);

        // Attempt to execute pause
        vm.prank(userPauserDelay);
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.AccessManagerNotScheduled.selector, operationId));
        manager.execute(address(token), pauseSelector);
    }

    function testAdminCanModifyPermissions() public {
        Role memory roleData = roleUtility.getRoleIds("CHM_TOKEN_PAUSER");

        // Revoke pauser role from a user
        vm.prank(pauserAdmin);
        manager.revokeRole(roleData.roleId, userPauserNoDelay);

        // Verify that user can no longer pause
        vm.prank(userPauserNoDelay);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, userPauserNoDelay));
        token.pause();

        // Grant pauser role to a new user
        vm.prank(pauserAdmin);
        manager.grantRole(roleData.roleId, userNonPauser, 0);

        // Verify that new user can now pause
        vm.prank(userNonPauser);
        token.pause();
        assertTrue(token.paused(), "Token should be paused by new pauser");
    }

    function testExecutionTimingForDelayedPauser() public {
        bytes memory pauseSelector = abi.encodeWithSelector(token.pause.selector);
        // Schedule pause
        vm.prank(userPauserDelay);
        (bytes32 operationId,) = manager.schedule(address(token), pauseSelector, uint48(block.timestamp + DELAY));
        assertFalse(token.paused(), "Token should not be paused immediately");

        // Attempt to pause before delay expires
        vm.warp(block.timestamp + DELAY - 1);
        vm.prank(userPauserDelay);
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.AccessManagerNotReady.selector, operationId));
        manager.execute(address(token), pauseSelector);

        // Pause after delay expires
        vm.warp(block.timestamp + DELAY);
        vm.prank(userPauserDelay);
        manager.execute(address(token), pauseSelector);
        assertTrue(token.paused(), "Token should be paused after delay expires");
    }

    function testAdminCanGrantAndRevokeGuardianRole() public {
        Role memory roleData = roleUtility.getRoleIds("CHM_TOKEN_PAUSER");

        // Grant guardian role to a new user
        vm.prank(pauserAdmin);
        manager.grantRole(roleData.guardianRoleId, userNonPauser, 0);

        // Schedule a pause
        bytes memory pauseSelector = abi.encodeWithSelector(token.pause.selector);

        vm.prank(userPauserDelay);
        (bytes32 operationId, uint32 nonce) =
            manager.schedule(address(token), pauseSelector, uint48(block.timestamp + DELAY));

        // Verify new guardian can cancel
        vm.prank(userNonPauser);
        manager.cancel(userPauserDelay, address(token), pauseSelector);

        // Revoke guardian role from the user
        vm.prank(pauserAdmin);
        manager.revokeRole(roleData.guardianRoleId, userNonPauser);

        // Schedule a new pause
        vm.prank(userPauserDelay);
        (operationId, nonce) = manager.schedule(address(token), pauseSelector, uint48(block.timestamp + DELAY));

        // Verify revoked guardian cannot cancel
        vm.prank(userNonPauser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManager.AccessManagerUnauthorizedCancel.selector,
                userNonPauser,
                userPauserDelay,
                address(token),
                token.pause.selector
            )
        );
        manager.cancel(userPauserDelay, address(token), pauseSelector);
    }

    function calculateDigest(bytes32 structHash) public view returns (bytes32) {
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function testPermitValidSignature() public {
        uint256 allowanceAmount = 500 * 10 ** token.decimals();
        uint256 nonce = token.nonces(deployer);
        uint256 deadline = block.timestamp + 1 days;

        // Construct the digest
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                deployer,
                spender,
                allowanceAmount,
                nonce,
                deadline
            )
        );
        bytes32 digest = calculateDigest(structHash);

        // Generate a valid signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(DEPLOYER_PRIVATE_KEY, digest);

        // Call permit
        token.permit(deployer, spender, allowanceAmount, deadline, v, r, s);

        // Verify allowance
        assertEq(token.allowance(deployer, spender), allowanceAmount, "Allowance not set correctly");
    }

    function testPermitInvalidSignature() public {
        uint256 allowanceAmount = 500 * 10 ** token.decimals();
        uint256 nonce = token.nonces(deployer);
        uint256 deadline = block.timestamp + 1 days;

        // Construct the digest
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                deployer,
                spender,
                allowanceAmount,
                nonce,
                deadline
            )
        );
        bytes32 digest = calculateDigest(structHash);

        // Generate an invalid signature (use a different address)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(USER_NON_PAUSER_PRIVATE_KEY, digest);

        // Expect revert
        vm.expectRevert(abi.encodeWithSelector(ERC20Permit.ERC2612InvalidSigner.selector, userNonPauser, deployer));
        token.permit(deployer, spender, allowanceAmount, deadline, v, r, s);
    }

    function testPermitExpiredDeadline() public {
        uint256 allowanceAmount = 500 * 10 ** token.decimals();
        uint256 nonce = token.nonces(deployer);
        uint256 deadline = block.timestamp - 1; // Expired

        // Construct the digest
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                deployer,
                spender,
                allowanceAmount,
                nonce,
                deadline
            )
        );
        bytes32 digest = calculateDigest(structHash);

        // Generate a valid signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(uint160(deployer)), digest);

        // Expect revert
        vm.expectRevert(abi.encodeWithSelector(ERC20Permit.ERC2612ExpiredSignature.selector, deadline));
        token.permit(deployer, spender, allowanceAmount, deadline, v, r, s);
    }

    function testPermitReplayAttack() public {
        uint256 allowanceAmount = 500 * 10 ** token.decimals();
        uint256 nonce = token.nonces(deployer);
        uint256 deadline = block.timestamp + 1 days;

        // Construct the digest
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                deployer,
                spender,
                allowanceAmount,
                nonce,
                deadline
            )
        );
        bytes32 digest = calculateDigest(structHash);

        // Generate a valid signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(DEPLOYER_PRIVATE_KEY, digest);

        // Call permit for the first time
        token.permit(deployer, spender, allowanceAmount, deadline, v, r, s);

        // Verify that nonce has incremented
        assertEq(token.nonces(deployer), nonce + 1, "Nonce did not increment correctly");

        // Attempt to reuse the same signature
        vm.expectRevert(); // Expect any revert due to nonce mismatch
        token.permit(deployer, spender, allowanceAmount, deadline, v, r, s);
    }

    function testPermitNonceIncrements() public {
        uint256 allowanceAmount = 500 * 10 ** token.decimals();
        uint256 nonce = token.nonces(deployer);
        uint256 deadline = block.timestamp + 1 days;

        // Construct the digest
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                deployer,
                spender,
                allowanceAmount,
                nonce,
                deadline
            )
        );
        bytes32 digest = calculateDigest(structHash);

        // Generate a valid signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(DEPLOYER_PRIVATE_KEY, digest);

        // Call permit
        token.permit(deployer, spender, allowanceAmount, deadline, v, r, s);

        // Verify that nonce increments
        assertEq(token.nonces(deployer), nonce + 1, "Nonce did not increment correctly");
    }

    function testDelegateVotingPower() public {
        uint256 balance = token.balanceOf(presale);

        // Delegate voting power from presale to spender
        vm.prank(presale);
        token.delegate(spender);

        // Check voting power
        assertEq(token.getVotes(spender), balance, "Voting power mismatch");
        assertEq(token.getVotes(presale), 0, "Voting power should be zero");
    }

    function testRevokeDelegation() public {
        uint256 balance = token.balanceOf(presale);

        // Delegate and then revoke
        vm.prank(presale);
        token.delegate(spender);
        vm.prank(presale);
        token.delegate(presale);

        // Check voting power
        assertEq(token.getVotes(presale), balance, "Voting power mismatch after revoking");
        assertEq(token.getVotes(spender), 0, "Voting power should be zero after revoking");
    }

    function testChangeDelegation() public {
        uint256 balance = token.balanceOf(presale);

        // Delegate to spender
        vm.prank(presale);
        token.delegate(spender);

        // Change delegation to recipient
        vm.prank(presale);
        token.delegate(recipient);

        // Check voting power
        assertEq(token.getVotes(spender), 0, "Voting power should be zero after delegation change");
        assertEq(token.getVotes(recipient), balance, "Voting power mismatch for new delegatee");
    }

    function testVotingPowerReflectsTransfers() public {
        uint256 transferAmount = 1_000 * 10 ** token.decimals();

        // Delegate to spender
        vm.prank(presale);
        token.delegate(spender);

        // Transfer tokens
        vm.prank(presale);
        token.transfer(recipient, transferAmount);

        // Check voting power
        assertEq(token.getVotes(spender), token.balanceOf(presale), "Voting power mismatch after transfer");
    }

    function testSnapshotVotingPower() public {
        uint256 balance = token.balanceOf(presale);
        uint256 transferAmount = 1000 * 10 ** token.decimals();

        // Delegate to spender
        vm.prank(presale);
        token.delegate(spender);

        // Record the current block timestamp
        uint256 blockTimestamp = block.timestamp;

        // Ensure the timestamp is valid
        vm.warp(block.timestamp + 1);

        // Transfer tokens
        vm.prank(presale);
        token.transfer(recipient, transferAmount);

        // Check voting power at the recorded timestamp
        assertEq(token.getPastVotes(spender, blockTimestamp), balance, "Snapshot voting power mismatch");
    }

    function testClockIntegrity() public {
        // Check initial timestamp
        uint256 initialTimestamp = block.timestamp;
        assertEq(token.clock(), initialTimestamp, "Clock mismatch with block timestamp");

        // Advance time
        uint256 advancedTime = 1000;
        vm.warp(block.timestamp + advancedTime);

        // Verify clock reflects the updated timestamp
        assertEq(token.clock(), block.timestamp, "Clock mismatch after time warp");
    }

    function testClockMode() public view {
        // Verify CLOCK_MODE outputs the correct string
        assertEq(token.CLOCK_MODE(), "mode=timestamp", "CLOCK_MODE mismatch");
    }

    function testTransferFullBalance() public {
        uint256 senderBalance = token.balanceOf(presale);

        // Transfer entire balance
        vm.prank(presale);
        token.transfer(recipient, senderBalance);

        // Check balances
        assertEq(token.balanceOf(presale), 0, "Sender balance should be zero after transferring full balance");
        assertEq(token.balanceOf(recipient), senderBalance, "Recipient balance should equal the transferred amount");
    }

    function testSetAllowanceToZero() public {
        uint256 initialAllowance = 500 * 10 ** token.decimals();

        // Approve spender
        vm.prank(presale);
        token.approve(spender, initialAllowance);

        // Set allowance to zero
        vm.prank(presale);
        token.approve(spender, 0);

        // Attempt to transfer
        vm.prank(spender);
        uint256 transferAmount = 1;
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, transferAmount)
        );
        token.transferFrom(presale, userPauserNoDelay, transferAmount);
    }

    function testTransferZeroTokens() public {
        uint256 senderBalance = token.balanceOf(presale);
        uint256 recipientBalance = token.balanceOf(userNonPauser);

        // Transfer zero tokens
        vm.prank(presale);
        token.transfer(userNonPauser, 0);

        // Check balances remain unchanged
        assertEq(token.balanceOf(presale), senderBalance, "Sender balance should remain unchanged");
        assertEq(token.balanceOf(userNonPauser), recipientBalance, "Recipient balance should remain unchanged");
    }
}
