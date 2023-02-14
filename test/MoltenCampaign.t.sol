// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {MoltenCampaign} from "../src/MoltenCampaign.sol";
import {MToken} from "../src/MToken.sol";
import {ERC20VotesMintable} from "./helpers/ERC20VotesMintable.sol";
import {ERC20VotesMintableMock} from "./helpers/ERC20VotesMintable.sol";
import {MTokenMock} from "./helpers/MTokenMock.sol";
import {MoltenElectionStub, MoltenElectionMock, MoltenCampaignStub} from "./helpers/MoltenCampaignMock.sol";

abstract contract TestBase is Test {
    uint256 public threshold = 100;
    uint128 public duration = 60;
    uint128 public cooldownDuration = 15;
    address public delegate = address(0x123);
    string public delegateName = "deldel";
    MoltenCampaignStub public campaign;

    ERC20VotesMintableMock public daoToken;
    MTokenMock public mToken;

    // See MoltenCampaignFactory
    function setUp() public virtual {
        daoToken = new ERC20VotesMintableMock("DAO governance token", "GT");
        MoltenElectionStub election = new MoltenElectionStub(
            address(0xdeadbeefcf),
            address(daoToken),
            threshold,
            duration,
            cooldownDuration
        );
        vm.prank(delegate);
        mToken = new MTokenMock(
            string.concat("Molten ", daoToken.name()),
            string.concat("m", daoToken.symbol(), "-", delegateName),
            address(this)
        );
        campaign = new MoltenCampaignStub(
            delegate,
            address(election),
            address(mToken)
        );
        mToken.transferOwnership(address(campaign));
        election.__stubHasCampaign(address(campaign), true);
    }

    function setFailTransfer() public virtual {
        daoToken.__setFail();
    }

    function unsetFailTransfer() public virtual {
        daoToken.__unsetFail();
    }

    function setFailMint() public virtual {
        mToken.__setFail();
    }

    function unsetFailMint() public virtual {
        mToken.__unsetFail();
    }
}

contract CreationTest is Test {
    MoltenCampaign public campaign;

    function setUp() public {
        campaign = new MoltenCampaign(
            address(0x4242),
            address(0x42424242),
            address(0x424242424242)
        );
    }

    function testSetsRepresentative() public {
        assertEq(campaign.representative(), address(0x4242));
    }

    function testSetsElection() public {
        assertEq(address(campaign.election()), address(0x42424242));
    }

    function testSetsMToken() public {
        assertEq(address(campaign.mToken()), address(0x424242424242));
    }
}

contract CantStakeTest is TestBase {
    address public staker = address(0x331);

    function testNeedsSuccessfulMint() public {
        setFailMint();

        vm.prank(staker);
        vm.expectRevert("MTFM mint");
        campaign.stake(333);
    }

    function testNeedsSuccessfulTransfer() public {
        setFailTransfer();

        vm.prank(staker);
        vm.expectRevert("ERC20VMFM transferFrom");
        campaign.stake(333);
    }

    function testRequiresNotInOffice() public {
        campaign.__stubInOffice(true);

        vm.prank(staker);
        vm.expectRevert("Molten: in office");
        campaign.stake(333);
    }
}

contract StakeTest is TestBase {
    address public staker = address(0x331);
    address public staker2 = address(0x332);

    function setUp() public override {
        super.setUp();

        vm.prank(staker);
        campaign.stake(333);
    }

    function testStakeUpdatesStaked() public {
        assertEq(campaign.staked(staker), 333);
    }

    function testStakeUpdatesTotalStaked() public {
        vm.prank(staker2);
        campaign.stake(222);

        assertEq(campaign.totalStaked(), 555);
    }

    function testStakeCallsTransfer() public {
        (address from, address to, uint256 amount) = daoToken
            .__transferFromCalledWith();
        assertEq(from, staker);
        assertEq(to, address(campaign));
        assertEq(amount, 333);
    }

    function testStakeMintsMTokens() public {
        (address _sender, address to, uint256 amount) = mToken
            .__mintCalledWith();
        assertEq(_sender, mToken.owner());
        assertEq(to, staker);
        assertEq(amount, 333);
    }

    function testStakeResetsCooldown() public {
        assertEq(campaign.cooldownEnd(), block.timestamp + cooldownDuration);
    }
}

contract CantUnstakeTest is TestBase {
    address public staker = address(0x331);

    function testNeedsAStake() public {
        vm.prank(staker);
        vm.expectRevert("Molten: unstake 0");
        campaign.unstake();
    }

    function testNeedsSucessfulTransfer() public {
        campaign.__stubStaked(staker, 333);
        campaign.__stubTotalStaked(333);
        setFailTransfer();

        vm.prank(staker);
        vm.expectRevert("ERC20VMFM transferFrom");
        campaign.unstake();
    }

    function testNeedsNeedsSuccessfulBurn() public {
        campaign.__stubStaked(staker, 333);
        campaign.__stubTotalStaked(333);
        setFailMint();

        vm.prank(staker);
        vm.expectRevert("MTFM burn");
        campaign.unstake();
    }

    function testRequiresNotInOffice() public {
        campaign.__stubStaked(staker, 333);
        campaign.__stubTotalStaked(333);
        campaign.__stubInOffice(true);

        vm.prank(staker);
        vm.expectRevert("Molten: in office");
        campaign.unstake();
    }
}

contract UnstakeTest is TestBase {
    address public staker = address(0x331);
    address public staker2 = address(0x332);

    function setUp() public override {
        super.setUp();

        campaign.__stubStaked(staker, 333);
        campaign.__stubStaked(staker2, 222);
        campaign.__stubTotalStaked(555);
    }

    function testUnstakeUpdatesStaked() public {
        vm.prank(staker);
        campaign.unstake();

        assertEq(campaign.staked(staker), 0);
    }

    function testUnstakeUpdatesTotalStaked() public {
        vm.prank(staker);
        campaign.unstake();
        vm.prank(staker2);
        campaign.unstake();

        assertEq(campaign.totalStaked(), 0);
    }

    function testUnstakeCallsTransfer() public {
        vm.prank(staker);
        campaign.unstake();

        (address from, address to, uint256 amount) = daoToken
            .__transferFromCalledWith();
        assertEq(from, address(campaign));
        assertEq(to, staker);
        assertEq(amount, 333);
    }

    function testUnstakeBurnsMTokens() public {
        vm.prank(staker);
        campaign.unstake();

        (address _sender, address to, uint256 amount) = mToken
            .__burnCalledWith();
        assertEq(_sender, mToken.owner());
        assertEq(to, staker);
        assertEq(amount, 333);
    }

    function testUnstakeResetsCooldown() public {
        vm.prank(staker);
        campaign.unstake();

        assertEq(campaign.cooldownEnd(), block.timestamp + cooldownDuration);
    }
}

contract CantTakeOfficeTest is TestBase {
    address public staker = address(0x331);

    function testNoTresholdCantTakeOffice(uint256 stake) public {
        vm.assume(stake < threshold);
        campaign.__stubStaked(staker, stake);
        campaign.__stubTotalStaked(stake);

        vm.expectRevert("Molten: threshold not reached");
        campaign.takeOffice();
    }

    function testCooldownNotEndedCantTakeOffice(
        uint256 stake,
        uint256 cooldownEnd
    ) public {
        vm.assume(stake >= threshold);
        vm.assume(cooldownEnd > block.timestamp);
        campaign.__stubStaked(staker, stake);
        campaign.__stubTotalStaked(stake);
        campaign.__stubCooldownEnd(cooldownEnd);

        vm.expectRevert("Molten: cooldown ongoing");
        campaign.takeOffice();
    }

    function testTresholdAndCooldownOkCanTakeOffice(
        uint256 stake,
        uint256 cooldownEnd
    ) public {
        vm.assume(stake >= threshold);
        vm.assume(cooldownEnd <= block.timestamp);
        campaign.__stubStaked(staker, stake);
        campaign.__stubTotalStaked(stake);
        campaign.__stubCooldownEnd(cooldownEnd);

        campaign.takeOffice();
    }
}

contract TakeOfficeTest is TestBase {
    address public staker = address(0x331);
    MoltenElectionMock public election;

    function setUp() public override {
        daoToken = new ERC20VotesMintableMock("DAO governance token", "GT");
        election = new MoltenElectionMock(
            address(0xdeadbeefcf),
            address(daoToken),
            threshold,
            duration,
            cooldownDuration
        );
        vm.prank(delegate);
        mToken = new MTokenMock(
            string.concat("Molten ", daoToken.name()),
            string.concat("m", daoToken.symbol(), "-", delegateName),
            address(this)
        );
        campaign = new MoltenCampaignStub(
            delegate,
            address(election),
            address(mToken)
        );
        mToken.transferOwnership(address(campaign));
    }

    function testSideEffects(uint256 totalStaked, uint256 cooldownEnd) public {
        vm.assume(totalStaked >= threshold);
        vm.assume(cooldownEnd <= block.timestamp);
        campaign.__stubStaked(staker, totalStaked);
        campaign.__stubTotalStaked(totalStaked);
        campaign.__stubCooldownEnd(cooldownEnd);

        campaign.takeOffice();

        // Sets inOffice
        assertTrue(campaign.inOffice());
        // Calls election.end()
        address from = election.__endCalledWith();
        assertEq(from, address(campaign));
        // [XXX] Calls yieldManager.
    }
}
