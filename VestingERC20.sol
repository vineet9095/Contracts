// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestToken is ERC20, Ownable {

    constructor() ERC20("Test Token", "TTK") Ownable(msg.sender) {
        // Mint 1,000,000 TTK to deployer on deploy
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    // Owner can mint more if needed
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}