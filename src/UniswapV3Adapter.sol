pragma solidity ^0.8.17;

import {IUniswapV3OracleConsulter} from "molten-oracle/interfaces/IUniswapV3OracleConsulter.sol";

abstract contract UniswapV3Adapter {
    IUniswapV3OracleConsulter public uniswapV3Oracle;
    address[] public uniswapV3OraclePools;
    address[] public uniswapV3OracleTokens;
    uint32 public uniswapV3OraclePeriod;

    constructor(
        address uniswapV3OracleAddress,
        address[] memory _uniswapV3OraclePools,
        address[] memory _uniswapV3OracleTokens,
        uint32 _uniswapV3OraclePeriod
    ) {
        uniswapV3Oracle = IUniswapV3OracleConsulter(uniswapV3OracleAddress);
        uniswapV3OraclePools = _uniswapV3OraclePools;
        uniswapV3OracleTokens = _uniswapV3OracleTokens;
        uniswapV3OraclePeriod = _uniswapV3OraclePeriod;
    }

    function queryExchangeRate(uint128 baseAmount)
        internal
        view
        returns (uint128)
    {
        uint256 exchangeRate = uniswapV3Oracle.consult(
            uniswapV3OraclePools,
            uniswapV3OracleTokens,
            uniswapV3OraclePeriod,
            baseAmount
        );
        assert(exchangeRate <= type(uint128).max);
        return uint128(exchangeRate);
    }
}
