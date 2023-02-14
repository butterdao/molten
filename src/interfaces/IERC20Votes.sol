// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IERC20} from "openzeppelin/token/ERC20/ERC20.sol";

interface IERC20Votes is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function delegate(address) external;
}
