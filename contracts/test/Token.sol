// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20, Ownable {
    constructor(uint initialSupply) ERC20("Token", "TOKE") {
        _mint(owner(), initialSupply);
    }

    function mint(uint amount) external onlyOwner {
        _mint(owner(), amount);
    }
}
