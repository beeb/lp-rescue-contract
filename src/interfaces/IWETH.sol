// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

interface IWETH {
    function balanceOf(address account) external view returns (uint256);

    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;

    function approve(address guy, uint256 wad) external returns (bool);
}
