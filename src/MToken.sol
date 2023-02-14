// SPDX-License-Identifier: UNLICENSED
// solhint-disable no-empty-blocks
pragma solidity ^0.8.17;

import {ERC20, ERC20Pausable, Pausable} from "openzeppelin/token/ERC20/extensions/ERC20Pausable.sol";
import {Owned} from "solmate/auth/Owned.sol";

contract MToken is ERC20Pausable, Owned {
    constructor(
        string memory name_,
        string memory symbol_,
        address _owner
    ) ERC20(name_, symbol_) Pausable() Owned(_owner) {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }

    function totalSupply() public view override returns (uint256) {
        return super.totalSupply();
    }
}
