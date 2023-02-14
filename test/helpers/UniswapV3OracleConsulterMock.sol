pragma solidity ^0.8.17;

contract OracleConsulterMock {
    uint256 public returnValue;

    constructor(uint256 _returnValue) {
        returnValue = _returnValue;
    }

    function consult(
        address,
        uint32,
        uint128,
        address,
        address
    ) external view returns (uint256) {
        return returnValue;
    }

    function consult(
        address[] calldata,
        address[] calldata,
        uint32,
        uint128
    ) external view returns (uint256) {
        return returnValue;
    }
}
