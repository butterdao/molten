// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";

import {MoltenFundingTestBase, DepositTestBase, ExchangeTestBase, LiquidationTestBase} from "./helpers/MoltenFundingScenarios.sol";

contract MoltenFundingCreationTest is MoltenFundingTestBase {
    function testConstructor() public {
        assertEq(moltenFunding.lockingDuration(), 365 days);
    }

    function testDepositMissingFunds() public {
        depositToken.mint(depositorAddress, 1000 * 10**18);

        vm.expectRevert();
        vm.prank(depositorAddress);
        moltenFunding.deposit(1000 * 10**18);
    }

    function testExchangeMissingDAOFunds() public {
        depositToken.mint(depositorAddress, 1000 * 10**18);
        vm.prank(depositorAddress);
        depositToken.approve(address(moltenFunding), 1000 * 10**18);
        vm.prank(depositorAddress);
        moltenFunding.deposit(1000 * 10**18);

        vm.expectRevert(bytes("ERC20: insufficient allowance"));
        vm.prank(daoTreasuryAddress);
        moltenFunding.exchange();
    }

    function testExchangeNoFunds() public {
        vm.expectRevert("Molten: no deposits");
        vm.prank(daoTreasuryAddress);
        moltenFunding.exchange();
    }

    function testLiquidateBlocked() public {
        vm.expectRevert("Molten: exchange not happened");
        moltenFunding.liquidate();
    }
}

contract DepositTest is DepositTestBase {
    function testRecordsDeposit() public {
        assertEq(moltenFunding.deposited(depositorAddress), 1000 * 10**18);
    }

    function testIncreasesTotalDeposits() public {
        depositToken.mint(address(0x234), 234 * 10**18);
        vm.prank(address(0x234));
        depositToken.approve(address(moltenFunding), 234 * 10**18);
        vm.prank(address(0x234));
        moltenFunding.deposit(234 * 10**18);

        assertEq(moltenFunding.totalDeposited(), 1234 * 10**18);
    }

    function testAllowsRefund() public {
        vm.prank(depositorAddress);
        moltenFunding.refund(1000 * 10**18);

        assertEq(moltenFunding.deposited(depositorAddress), 0);
    }

    function testBlocksTooLargeRefund() public {
        vm.expectRevert("Molten: refund amount too large");
        vm.prank(depositorAddress);
        moltenFunding.refund(1001 * 10**18);
    }

    function testClaimMTokensLocked() public {
        vm.expectRevert("Molten: exchange not happened");
        vm.prank(depositorAddress);
        moltenFunding.claimMTokens();
    }

    function testVoteBlocked() public {
        vm.expectRevert("Molten: exchange not happened");
        vm.prank(depositorAddress);
        moltenFunding.voteForLiquidation();
    }

    function testWithdrawVoteBlocked() public {
        vm.expectRevert("Molten: exchange not happened");
        vm.prank(depositorAddress);
        moltenFunding.withdrawVoteForLiquidation();
    }

    function testExchangeBlockedForNonDAO() public {
        daoToken.mint(daoTreasuryAddress, 4242 * 10**18);
        vm.prank(daoTreasuryAddress);
        daoToken.approve(address(moltenFunding), type(uint256).max);

        vm.expectRevert("Molten: exchange only by DAO");
        moltenFunding.exchange();
    }
}

contract RefundTest is DepositTestBase {
    function setUp() public override {
        super.setUp();

        vm.prank(depositorAddress);
        moltenFunding.refund(800 * 10**18);
    }

    function testDecreasesDeposited() public {
        assertEq(moltenFunding.deposited(depositorAddress), 200 * 10**18);
    }

    function testDecreasesTotalDeposited() public {
        assertEq(moltenFunding.totalDeposited(), 200 * 10**18);
    }
}

contract ExchangeTest is ExchangeTestBase {
    function testSetExchangeTime() public {
        assertTrue(moltenFunding.exchangeTime() > 0);
    }

    function testTransfersDaoTokensToContract() public {
        assertEq(daoToken.balanceOf(address(moltenFunding)), 50 * 10**18);
    }

    function testTransfersDepositsToDaoTreasury() public {
        assertEq(depositToken.balanceOf(address(moltenFunding)), 0);
        assertEq(depositToken.balanceOf(daoTreasuryAddress), 1000 * 10**18);
    }

    function testRepeatedDepositFails() public {
        vm.expectRevert("Molten: exchange happened");
        vm.prank(depositorAddress);
        moltenFunding.deposit(1000);
    }

    function testRepeatedRefundFails() public {
        vm.expectRevert("Molten: exchange happened");
        vm.prank(depositorAddress);
        moltenFunding.refund(1000);
    }

    function testRepeatedExchangeFails() public {
        vm.expectRevert("Molten: exchange happened");
        vm.prank(daoTreasuryAddress);
        moltenFunding.exchange();
    }

    function testMintsMTokens() public {
        assertEq(mToken.totalSupply(), (1000 / 20) * 10**18);
    }

    function testLiquidateTimeLocked() public {
        vm.expectRevert("Molten: locked");
        moltenFunding.liquidate();
    }

    function testDelegatesToCandidate() public {
        assertEq(daoToken.delegates(address(moltenFunding)), candidateAddress);
    }

    function testClaimMTokensBlockedForNonDepositor() public {
        vm.expectRevert("Molten: no mToken to claim");
        vm.prank(daoTreasuryAddress);
        moltenFunding.claimMTokens();
    }
}

contract ClaimMTokensTest is ExchangeTestBase {
    function setUp() public override {
        super.setUp();

        vm.prank(depositorAddress);
        moltenFunding.claimMTokens();
    }

    function testTransfersToDepositor() public {
        assertEq(mToken.balanceOf(address(moltenFunding)), 0);
        assertEq(
            mToken.balanceOf(depositorAddress),
            (1000 / 20) * 10**18 // 50 * 10**18
        );
    }

    function testDepositorCanTransfer() public {
        emit log_uint(mToken.balanceOf(depositorAddress));
        vm.prank(depositorAddress);
        mToken.transfer(address(0x4242), 50 * 10**18);
    }

    function testClaimLocked() public {
        vm.expectRevert("Molten: not liquidated");
        vm.prank(depositorAddress);
        moltenFunding.claim();
    }
}

contract DoubleClaimMTokensTest is MoltenFundingTestBase {
    address depositor2Address = address(0x301);

    function setUp() public override {
        super.setUp();

        depositToken.mint(depositorAddress, 1000e18);
        vm.prank(depositorAddress);
        depositToken.approve(address(moltenFunding), 1000e18);
        depositToken.mint(depositor2Address, 2000e18);
        vm.prank(depositor2Address);
        depositToken.approve(address(moltenFunding), 2000e18);

        // Deposits
        vm.prank(depositorAddress);
        moltenFunding.deposit(1000e18);
        vm.prank(depositor2Address);
        moltenFunding.deposit(2000e18);

        daoToken.mint(daoTreasuryAddress, 4242e18);
        vm.prank(daoTreasuryAddress);
        daoToken.approve(address(moltenFunding), type(uint256).max);

        // Exchange
        vm.prank(daoTreasuryAddress);
        moltenFunding.exchange();
    }

    function testClaimsOK() public {
        vm.prank(depositorAddress);
        moltenFunding.claimMTokens();

        vm.prank(depositor2Address);
        moltenFunding.claimMTokens();
    }

    function testCantDoubleClaim() public {
        vm.prank(depositorAddress);
        moltenFunding.claimMTokens();

        vm.expectRevert("Molten: mTokens already claimed");
        vm.prank(depositorAddress);
        moltenFunding.claimMTokens();
    }
}

contract LiquidationTest is LiquidationTestBase {
    function testPausesMToken() public {
        vm.expectRevert("ERC20Pausable: token transfer while paused");
        vm.prank(depositorAddress);
        mToken.transfer(address(0x4242), 50 * 10**18);
    }

    function testClaimingBlockedForNonDepositors() public {
        vm.expectRevert("Molten: nothing to claim");
        vm.prank(daoTreasuryAddress);
        moltenFunding.claim();
    }

    function testVoteBlocked() public {
        vm.expectRevert("Molten: not locked");
        vm.prank(depositorAddress);
        moltenFunding.voteForLiquidation();
    }

    function testWithdrawVoteBlocked() public {
        vm.expectRevert("Molten: not locked");
        vm.prank(depositorAddress);
        moltenFunding.withdrawVoteForLiquidation();
    }

    function testDelegatesToNull() public {
        assertEq(daoToken.delegates(address(moltenFunding)), address(0x00));
    }
}

contract ClaimTest is LiquidationTestBase {
    function setUp() public override {
        super.setUp();

        vm.prank(depositorAddress);
        moltenFunding.claim();
    }

    function testBurnsMTokens() public {
        assertEq(mToken.balanceOf(depositorAddress), 0);
    }

    function testTransfersDaoTokens() public {
        assertEq(daoToken.balanceOf(depositorAddress), 50 * 10**18);
    }
}

contract ClaimWhenUnclaimedMTokensTest is ExchangeTestBase {
    function setUp() public virtual override {
        super.setUp();

        skip(365 days);
        moltenFunding.liquidate();
        vm.prank(depositorAddress);
        moltenFunding.claim();
    }

    function testStillTransfersDaoTokens() public {
        assertEq(daoToken.balanceOf(depositorAddress), 50 * 10**18);
    }

    function testVoteBlockedForNonDepositors() public {
        vm.expectRevert("Molten: no voting power");
        vm.prank(daoTreasuryAddress);
        moltenFunding.voteForLiquidation();
    }

    function testWithdrawVoteBlockedForNonDepositors() public {
        vm.expectRevert("Molten: no voting power");
        vm.prank(daoTreasuryAddress);
        moltenFunding.withdrawVoteForLiquidation();
    }
}

contract ClaimWhenUnclaimedMTokensAndMTokensBalancePositiveTest is
    MoltenFundingTestBase
{
    address public depositorAddress2 = address(0x11);

    function setUp() public virtual override {
        super.setUp();

        depositToken.mint(depositorAddress, 1000 * 10**18);
        vm.prank(depositorAddress);
        depositToken.approve(address(moltenFunding), 1000 * 10**18);
        vm.prank(depositorAddress);
        moltenFunding.deposit(1000 * 10**18);

        depositToken.mint(depositorAddress2, 500 * 10**18);
        vm.prank(depositorAddress2);
        depositToken.approve(address(moltenFunding), 500 * 10**18);
        vm.prank(depositorAddress2);
        moltenFunding.deposit(500 * 10**18);

        daoToken.mint(daoTreasuryAddress, 4242 * 10**18);
        vm.prank(daoTreasuryAddress);
        daoToken.approve(address(moltenFunding), type(uint256).max);

        vm.prank(daoTreasuryAddress);
        moltenFunding.exchange(); // mTokens supply = 75.

        // 2nd depositor sends 10 mTokens to 1st depositor.
        vm.prank(depositorAddress2);
        moltenFunding.claimMTokens();
        vm.prank(depositorAddress2);
        mToken.transfer(depositorAddress, 10 * 10**18);

        skip(365 days);
        moltenFunding.liquidate();
    }

    function testClaimsDaoTokensForClaimedAndUnclaimedMTokens() public {
        vm.prank(depositorAddress);
        moltenFunding.claim();

        assertEq(daoToken.balanceOf(depositorAddress), 60 * 10**18);
        assertEq(mToken.totalSupply(), 15 * 10**18);
    }

    function testDoesntClaimDaoTokensForTransferredMTokens() public {
        vm.prank(depositorAddress2);
        moltenFunding.claim();

        assertEq(daoToken.balanceOf(depositorAddress2), 15 * 10**18);
        assertEq(mToken.totalSupply(), 60 * 10**18);
    }
}

contract TransferMTokensThenClaimTest is ExchangeTestBase {
    address public depositorAddress2 = address(0x11);

    function setUp() public virtual override {
        super.setUp();

        vm.prank(depositorAddress);
        moltenFunding.claimMTokens();

        vm.prank(depositorAddress);
        mToken.transfer(depositorAddress2, 50 * 10**18);

        skip(365 days);
        moltenFunding.liquidate();
    }

    function testSenderCantClaim() public {
        vm.expectRevert("Molten: nothing to claim");
        vm.prank(depositorAddress);
        moltenFunding.claim();
    }

    function testReceiverCanClaim() public {
        vm.prank(depositorAddress2);
        moltenFunding.claim();

        assertEq(daoToken.balanceOf(depositorAddress2), 50 * 10**18);
    }
}

contract VoteTest is ExchangeTestBase {
    function setUp() public virtual override {
        super.setUp();

        vm.prank(depositorAddress);
        moltenFunding.voteForLiquidation();
    }

    function testUpdatesTotals() public {
        assertEq(
            moltenFunding.totalVotesForLiquidation(),
            moltenFunding.totalDeposited()
        );
    }

    function testEnablesLiquidation() public {
        moltenFunding.liquidate();

        vm.prank(depositorAddress);
        moltenFunding.claim();
    }

    function testWithdrawDisablesLiquidation() public {
        vm.prank(depositorAddress);
        moltenFunding.withdrawVoteForLiquidation();

        assertEq(moltenFunding.totalVotesForLiquidation(), 0);
        vm.expectRevert("Molten: locked");
        moltenFunding.liquidate();
    }

    function testCantDoubleVote() public {
        vm.expectRevert("Molten: already voted");
        vm.prank(depositorAddress);
        moltenFunding.voteForLiquidation();
    }

    function testCantDoubleWithdraw() public {
        vm.prank(depositorAddress);
        moltenFunding.withdrawVoteForLiquidation();

        vm.expectRevert("Molten: not voted");
        vm.prank(depositorAddress);
        moltenFunding.withdrawVoteForLiquidation();
    }
}
