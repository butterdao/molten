// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {MoltenElection, MoltenCampaignFactory, MoltenCampaign} from "../src/MoltenCampaign.sol";
import {ERC20VotesMintable} from "./helpers/ERC20VotesMintable.sol";
import {MoltenElectionStub, MoltenCampaignMock, MoltenCampaignStub} from "./helpers/MoltenCampaignMock.sol";

contract CreationTest is Test {
    ERC20VotesMintable public daoToken;

    function setUp() public {
        daoToken = new ERC20VotesMintable("DAO governance token", "GT");
        vm.label(address(daoToken), "DAO governance token");
    }

    function testHasDaoToken() public {
        MoltenElection election = new MoltenElection(
            address(0xdeadbeefcf),
            address(daoToken),
            1,
            1,
            1
        );

        assertEq(address(election.daoToken()), address(daoToken));
    }

    function testHasThreshold(uint256 threshold) public {
        MoltenElection election = new MoltenElection(
            address(0xdeadbeefcf),
            address(daoToken),
            threshold,
            1,
            1
        );

        assertEq(election.threshold(), threshold);
    }

    function testHasDuration(uint32 duration) public {
        MoltenElection election = new MoltenElection(
            address(0xdeadbeefcf),
            address(daoToken),
            1,
            duration,
            1
        );

        assertEq(election.duration(), duration);
    }

    function testHasCooldownDuration(uint32 cooldownDuration) public {
        MoltenElection election = new MoltenElection(
            address(0xdeadbeefcf),
            address(daoToken),
            1,
            1,
            cooldownDuration
        );

        assertEq(election.cooldownDuration(), cooldownDuration);
    }

    function testNotEnded() public {
        MoltenElection election = new MoltenElection(
            address(0xdeadbeefcf),
            address(daoToken),
            1,
            1,
            1
        );

        assertFalse(election.ended());
    }
}

contract CantAddCampaignTest is Test {
    address public campaignFactory = address(0x4242cf);
    MoltenElectionStub public election;
    ERC20VotesMintable public daoToken;

    function setUp() public {
        daoToken = new ERC20VotesMintable("DAO governance token", "GT");
        election = new MoltenElectionStub(
            campaignFactory,
            address(daoToken),
            1,
            1,
            1
        );
    }

    function testRequiresFromCampaignFactory() public {
        MoltenCampaign campaign = new MoltenCampaign(
            address(0xdeadbeef),
            address(election),
            address(0xdeadbeef1)
        );
        vm.expectRevert("Molten: unauthorized");
        election.addCampaign(campaign);
    }

    function testRequiresSameElection() public {
        MoltenCampaign campaign = new MoltenCampaign(
            address(0xdeadbeef),
            address(0x4242424242424242),
            address(0xdeadbeef1)
        );
        vm.prank(campaignFactory);
        vm.expectRevert("Molten: different election");
        election.addCampaign(campaign);
    }

    function testRequiresNotEnded() public {
        MoltenCampaign campaign = new MoltenCampaign(
            address(0xdeadbeef),
            address(election),
            address(0xdeadbeef1)
        );
        election.__stubEnded(true);
        vm.prank(campaignFactory);
        vm.expectRevert("Molten: election ended");
        election.addCampaign(campaign);
    }
}

contract AddCampaignTest is Test {
    address public campaignFactory = address(0x4242cf);
    MoltenElectionStub public election;
    ERC20VotesMintable public daoToken;
    MoltenCampaign public campaign;

    function setUp() public {
        daoToken = new ERC20VotesMintable("DAO governance token", "GT");
        election = new MoltenElectionStub(
            campaignFactory,
            address(daoToken),
            1,
            1,
            1
        );
        campaign = new MoltenCampaign(
            address(0xdeadbeef),
            address(election),
            address(0xdeadbeef1)
        );
    }

    function testSetsHasCampaign() public {
        vm.prank(campaignFactory);
        election.addCampaign(campaign);
        assertTrue(election.hasCampaign(address(campaign)));
    }
}

contract CantEndTest is Test {
    address public campaignFactory = address(0x4242cf);
    MoltenElectionStub public election;
    ERC20VotesMintable public daoToken;
    uint256 public threshold = 42424242;
    uint128 public duration = 42;
    uint128 public cooldownDuration = 24;

    function setUp() public {
        daoToken = new ERC20VotesMintable("DAO governance token", "GT");
        election = new MoltenElectionStub(
            campaignFactory,
            address(daoToken),
            threshold,
            duration,
            cooldownDuration
        );
    }

    function testRequiresHasCampaignCaller() public {
        MoltenCampaign campaign = new MoltenCampaign(
            address(0xdeadbeef),
            address(election),
            address(0xdeadbeef1)
        );

        vm.prank(address(campaign));
        vm.expectRevert("Molten: unauthorized");
        election.end();
    }

    function testRequiresThresholdReached(uint256 totalStaked) public {
        vm.assume(totalStaked < threshold);
        MoltenCampaignStub campaign = new MoltenCampaignStub(
            address(0xdeadbeef),
            address(election),
            address(0xdeadbeef1)
        );
        election.__stubHasCampaign(address(campaign), true);
        campaign.__stubTotalStaked(totalStaked);

        vm.prank(address(campaign));
        vm.expectRevert("Molten: threshold not reached");
        election.end();
    }

    function testRequiresCooldownEnded(uint256 cooldownEnd) public {
        vm.assume(cooldownEnd > block.timestamp);
        MoltenCampaignStub campaign = new MoltenCampaignStub(
            address(0xdeadbeef),
            address(election),
            address(0xdeadbeef1)
        );
        election.__stubHasCampaign(address(campaign), true);
        campaign.__stubCooldownEnd(cooldownEnd);

        vm.prank(address(campaign));
        vm.expectRevert("Molten: threshold not reached");
        election.end();
    }
}

contract EndTest is Test {
    address public campaignFactory = address(0x4242cf);
    MoltenElectionStub public election;
    ERC20VotesMintable public daoToken;
    uint256 public threshold = 42424242;
    uint128 public duration = 42;
    uint128 public cooldownDuration = 24;
    MoltenCampaignStub campaign;

    function setUp() public {
        daoToken = new ERC20VotesMintable("DAO governance token", "GT");
        election = new MoltenElectionStub(
            campaignFactory,
            address(daoToken),
            threshold,
            duration,
            cooldownDuration
        );
        campaign = new MoltenCampaignStub(
            address(0xdeadbeef),
            address(election),
            address(0xdeadbeef1)
        );
    }

    function testSetsEnded(uint256 totalStaked, uint128 cooldownEnd) public {
        vm.assume(totalStaked >= threshold);
        vm.assume(cooldownEnd <= block.timestamp);
        campaign.__stubTotalStaked(totalStaked);
        campaign.__stubCooldownEnd(cooldownEnd);
        election.__stubHasCampaign(address(campaign), true);

        vm.prank(address(campaign));
        election.end();

        assertTrue(election.ended());
    }
}
