// SPDX-License-Identifier: UNLICENSED
// solhint-disable no-empty-blocks
// solhint-disable contract-name-camelcase
pragma solidity ^0.8.17;

import {ERC20, ERC20Pausable, Pausable} from "openzeppelin/token/ERC20/extensions/ERC20Pausable.sol";
import {Owned} from "solmate/auth/Owned.sol";

contract MTokenMock is ERC20Pausable, Owned {
    bool public __mockFail = false;

    struct __MintCall {
        address _sender;
        address to;
        uint256 amount;
    }
    __MintCall public __mintCalledWith;
    struct __BurnCall {
        address _sender;
        address account;
        uint256 amount;
    }
    __BurnCall public __burnCalledWith;

    constructor(
        string memory name_,
        string memory symbol_,
        address _owner
    ) ERC20(name_, symbol_) Pausable() Owned(_owner) {}

    function pause() external onlyOwner {
        //
    }

    function unpause() external onlyOwner {
        //
    }

    function mint(address to, uint256 amount) public virtual onlyOwner {
        __mintCalledWith = __MintCall({
            _sender: msg.sender,
            to: to,
            amount: amount
        });
        require(!__mockFail, "MTFM mint");
    }

    function burn(address account, uint256 amount) public virtual onlyOwner {
        __burnCalledWith = __BurnCall({
            _sender: msg.sender,
            account: account,
            amount: amount
        });
        require(!__mockFail, "MTFM burn");
    }

    function totalSupply() public view override returns (uint256) {
        return super.totalSupply();
    }

    function __setFail() public {
        __mockFail = true;
    }

    function __unsetFail() public {
        __mockFail = false;
    }
}
