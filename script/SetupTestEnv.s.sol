// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ERC20PresetMinterPauser} from "openzeppelin/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {ERC20VotesMintable} from "../test/helpers/ERC20VotesMintable.sol";
import {OracleConsulterMock} from "../test/helpers/UniswapV3OracleConsulterMock.sol";
import {MoltenFunding} from "../src/MoltenFunding.sol";

abstract contract Setup is Script {
    function setupDaoToken() public returns (address) {
        if (vm.envBytes("TEST_DAO_TOKEN_ADDRESS").length > 0) {
            console2.logString(
                unicode"💾 DAO token address loaded from env, nothing deployed."
            );
            return vm.envAddress("TEST_DAO_TOKEN_ADDRESS");
        }

        uint256 deployerPrivKey = vm.envUint("TEST_DEPLOYER_PRIVKEY");
        address daoTreasuryAddress = vm.envAddress("TEST_DAO_ADDRESS");

        vm.startBroadcast(deployerPrivKey);
        ERC20VotesMintable daoToken = new ERC20VotesMintable(
            "DAO governance token",
            "GT"
        );
        daoToken.mint(daoTreasuryAddress, 4242e18);
        vm.stopBroadcast();

        console2.logString(unicode"🚀 DAO ERC20Votes token deployed at:");
        console2.logAddress(address(daoToken));

        return address(daoToken);
    }

    function setupDepositToken() public returns (address) {
        if (vm.envBytes("TEST_DEPOSIT_TOKEN_ADDRESS").length > 0) {
            console2.logString(
                unicode"💾 Deposit token address loaded from env, nothing deployed."
            );
            return vm.envAddress("TEST_DEPOSIT_TOKEN_ADDRESS");
        }

        uint256 deployerPrivKey = vm.envUint("TEST_DEPLOYER_PRIVKEY");
        address investor1Address = vm.envAddress("TEST_INVESTOR_1_ADDRESS");
        address investor2Address = vm.envAddress("TEST_INVESTOR_2_ADDRESS");
        address investor3Address = vm.envAddress("TEST_INVESTOR_3_ADDRESS");

        vm.startBroadcast(deployerPrivKey);
        ERC20PresetMinterPauser depositToken = new ERC20PresetMinterPauser(
            "Stable token",
            "BAI"
        );
        depositToken.mint(investor1Address, 1000e18);
        depositToken.mint(investor2Address, 1000e18);
        depositToken.mint(investor3Address, 1000e18);
        vm.stopBroadcast();

        console2.logString(unicode"🚀 Deposit ERC20 token deployed at:");
        console2.logAddress(address(depositToken));

        return address(depositToken);
    }

    function deployOracleMock() public returns (address) {
        if (vm.envBytes("TEST_ORACLE_ADDRESS").length > 0) {
            console2.logString(
                unicode"💾 Oracle address loaded from env, nothing deployed."
            );
            return vm.envAddress("TEST_ORACLE_ADDRESS");
        }

        uint256 deployerPrivKey = vm.envUint("TEST_DEPLOYER_PRIVKEY");

        vm.startBroadcast(deployerPrivKey);
        OracleConsulterMock oracleConsulterMock = new OracleConsulterMock(
            20e18
        );
        vm.stopBroadcast();

        console2.logString(unicode"🚀 Mock Uniswap v3 oracle deployed at:");
        console2.logAddress(address(oracleConsulterMock));

        return address(oracleConsulterMock);
    }

    function deployMolten(
        address daoTokenAddress,
        address depositTokenAddress,
        address oracleAddress
    ) public returns (address) {
        if (vm.envBytes("TEST_MOLTEN_ADDRESS").length > 0) {
            console2.logString(
                unicode"💾 Molten funding address loaded from env, nothing deployed."
            );
            return vm.envAddress("TEST_MOLTEN_ADDRESS");
        }

        uint256 candidatePrivKey = vm.envUint("TEST_CANDIDATE_PRIVKEY");
        address daoTreasuryAddress = vm.envAddress("TEST_DAO_ADDRESS");

        vm.startBroadcast(candidatePrivKey);
        MoltenFunding moltenFunding = new MoltenFunding(
            daoTokenAddress,
            15 days,
            depositTokenAddress,
            daoTreasuryAddress,
            oracleAddress,
            new address[](0),
            new address[](0),
            7 days
        );
        vm.stopBroadcast();

        console2.logString(unicode"🚀 Molten funding contract deployed at:");
        console2.logAddress(address(moltenFunding));

        return address(moltenFunding);
    }
}

contract DeployMolten is Setup {
    function run() external {
        address daoTokenAddress = setupDaoToken();
        address depositTokenAddress = setupDepositToken();
        address oracleAddress = deployOracleMock();
        deployMolten(daoTokenAddress, depositTokenAddress, oracleAddress);
    }
}

contract DeployAndDealDaoToken is Setup {
    function run() external {
        setupDaoToken();
    }
}

contract DeployAndDealDepositToken is Setup {
    function run() external {
        setupDepositToken();
    }
}

contract DeployOracle is Setup {
    function run() external {
        deployOracleMock();
    }
}

contract FundAddresses is Script {
    function run() external {
        uint256 deployerPrivKey = vm.envUint("TEST_DEPLOYER_PRIVKEY");

        vm.startBroadcast(deployerPrivKey);
        payable(vm.envAddress("TEST_CANDIDATE_ADDRESS")).transfer(1e16);
        payable(vm.envAddress("TEST_DAO_ADDRESS")).transfer(1e16);
        payable(vm.envAddress("TEST_INVESTOR_1_ADDRESS")).transfer(1e16);
        payable(vm.envAddress("TEST_INVESTOR_2_ADDRESS")).transfer(1e16);
        payable(vm.envAddress("TEST_INVESTOR_3_ADDRESS")).transfer(1e16);
        vm.stopBroadcast();
    }
}
