// SPDX-License-Identifier: UNLICENSED
// solhint-disable not-rely-on-time
pragma solidity ^0.8.17;

import {IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {IUniswapV3OracleConsulter} from "molten-oracle/interfaces/IUniswapV3OracleConsulter.sol";

import {IERC20Votes} from "./interfaces/IERC20Votes.sol";
import {MToken} from "./MToken.sol";
import {UniswapV3Adapter} from "./UniswapV3Adapter.sol";

contract MoltenFunding is ReentrancyGuard, UniswapV3Adapter {
    address public candidateAddress;
    address public daoTreasuryAddress;
    MToken public mToken;
    IERC20 public depositToken;
    IERC20Votes public daoToken;

    // ⚠️  This mapping is not emptied on exchange. After exchange, its values
    // are really only what was deposited by a given address.
    mapping(address => uint128) public deposited;
    // ⚠️  Not emptied on exchange.
    uint128 public totalDeposited;

    uint256 public exchangeTime;
    /// @notice number of dao wei-tokens valued at 1 dao token
    uint256 public exchangeRate;
    uint256 public lockingDuration;

    mapping(address => bool) public mTokensClaimed;

    uint256 public liquidationTime;
    mapping(address => bool) public votedForLiquidation;
    uint256 public totalVotesForLiquidation;

    constructor(
        address daoTokenAddress,
        uint256 _lockingDuration,
        address depositTokenAddress,
        address _daoTreasuryAddress,
        address uniswapV3OracleAddress,
        address[] memory _uniswapV3OraclePools,
        address[] memory _uniswapV3OracleTokens,
        uint32 _uniswapV3OraclePeriod
    )
        UniswapV3Adapter(
            uniswapV3OracleAddress,
            _uniswapV3OraclePools,
            _uniswapV3OracleTokens,
            _uniswapV3OraclePeriod
        )
    {
        candidateAddress = msg.sender;
        lockingDuration = _lockingDuration;
        daoToken = IERC20Votes(daoTokenAddress);
        depositToken = IERC20(depositTokenAddress);
        daoTreasuryAddress = _daoTreasuryAddress;

        mToken = new MToken(
            string.concat("Molten ", daoToken.name()),
            string.concat("m", daoToken.symbol()),
            address(this)
        );
    }

    function deposit(uint128 amount) external {
        require(exchangeTime == 0, "Molten: exchange happened");

        deposited[msg.sender] += amount;
        totalDeposited += amount;

        depositToken.transferFrom(msg.sender, address(this), amount);
    }

    function refund(uint128 amount) external {
        require(exchangeTime == 0, "Molten: exchange happened");
        require(
            amount <= deposited[msg.sender],
            "Molten: refund amount too large"
        );

        deposited[msg.sender] -= amount;
        totalDeposited -= amount;

        depositToken.transfer(msg.sender, amount);
    }

    /**
     * @notice Delegates to candidate and swaps dao tokens for deposit tokens.
     * ⚠️  Nothing resets delegation in this contract.
     */
    function exchange() external nonReentrant {
        require(
            msg.sender == daoTreasuryAddress,
            "Molten: exchange only by DAO"
        );
        require(exchangeTime == 0, "Molten: exchange happened");
        require(totalDeposited > 0, "Molten: no deposits");

        exchangeTime = block.timestamp;
        exchangeRate = queryExchangeRate(totalDeposited);

        mToken.mint(
            address(this),
            (totalDeposited * 10**mToken.decimals()) / exchangeRate
        );
        depositToken.transfer(daoTreasuryAddress, totalDeposited);
        daoToken.transferFrom(
            msg.sender,
            address(this),
            (totalDeposited * 10**daoToken.decimals()) / exchangeRate
        );
        daoToken.delegate(candidateAddress);
    }

    function _claimableMTokensBalance(address account)
        private
        view
        returns (uint256)
    {
        assert(exchangeRate > 0);

        return (deposited[account] * 10**mToken.decimals()) / exchangeRate;
    }

    function claimMTokens() external {
        require(deposited[msg.sender] > 0, "Molten: no mToken to claim");
        require(exchangeTime > 0, "Molten: exchange not happened");
        require(!mTokensClaimed[msg.sender], "Molten: mTokens already claimed");

        mTokensClaimed[msg.sender] = true;

        // [FIXME] We are not making sure that the total amount of claimable
        // mTokens is going to match exactly the total minted supply.
        mToken.transfer(msg.sender, _claimableMTokensBalance(msg.sender));
    }

    /**
     * @notice Sets the contract as liquidated, which allows claiming of DAO
     * governance tokens by mToken holders.
     * ⚠️  Resets delegation to null. After claiming their tokens, token holders
     * may change delegation.
     */
    function liquidate() external {
        bool lockEnded = block.timestamp >= exchangeTime + lockingDuration;
        bool unanimousLiquidationVote = totalVotesForLiquidation ==
            totalDeposited;

        require(exchangeTime > 0, "Molten: exchange not happened");
        require(lockEnded || unanimousLiquidationVote, "Molten: locked");

        liquidationTime = block.timestamp;

        mToken.pause();
        daoToken.delegate(address(0x00));
    }

    function claim() external {
        uint256 mTokenBalance = mToken.balanceOf(msg.sender);
        uint256 unclaimedMTokenBalance = (
            mTokensClaimed[msg.sender]
                ? 0
                : _claimableMTokensBalance(msg.sender)
        );
        uint256 claimableBalance = mTokenBalance + unclaimedMTokenBalance;

        require(claimableBalance > 0, "Molten: nothing to claim");
        require(liquidationTime > 0, "Molten: not liquidated");

        mToken.unpause();
        mToken.burn(msg.sender, mTokenBalance);
        mToken.burn(address(this), unclaimedMTokenBalance);
        mToken.pause();
        daoToken.transfer(msg.sender, claimableBalance);
    }

    function voteForLiquidation() external {
        uint256 _deposited = deposited[msg.sender];

        require(deposited[msg.sender] > 0, "Molten: no voting power");
        require(exchangeTime > 0, "Molten: exchange not happened");
        require(
            block.timestamp < exchangeTime + lockingDuration,
            "Molten: not locked"
        );
        require(!votedForLiquidation[msg.sender], "Molten: already voted");

        votedForLiquidation[msg.sender] = true;
        totalVotesForLiquidation += _deposited;
    }

    function withdrawVoteForLiquidation() external {
        uint256 _deposited = deposited[msg.sender];

        require(deposited[msg.sender] > 0, "Molten: no voting power");
        require(exchangeTime > 0, "Molten: exchange not happened");
        require(
            block.timestamp < exchangeTime + lockingDuration,
            "Molten: not locked"
        );
        require(votedForLiquidation[msg.sender], "Molten: not voted");

        delete votedForLiquidation[msg.sender];
        totalVotesForLiquidation -= _deposited;
    }
}
