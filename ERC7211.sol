// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.6.0
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Burnable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

contract MyToken is ERC1155, Ownable, ERC1155Burnable {

    // Track minted IDs aur total supply
    mapping(uint256 => uint256) private _totalSupply;
    uint256 private _nextTokenId;
    // Add this mapping
    mapping(uint256 => string) private _tokenURIs;

    constructor(address initialOwner) ERC1155("") Ownable(initialOwner) {}


    modifier validTokenId(uint256 id) {
        require(_totalSupply[id] > 0, "Invalid token ID: never minted");
        _;
    }

    // Internal setter
    function _setTokenURI(uint256 id, string memory tokenURI) internal {
        _tokenURIs[id] = tokenURI;
    }

    function mint(address account, uint256 amount, string memory newuri) public onlyOwner {
        uint256 id = _nextTokenId++;
        _totalSupply[id] += amount;
        _setTokenURI(id, newuri);
        _setURI(newuri);
        _mint(account, id, amount, "");
    }

    function mintBatch(address to, uint256[] memory amounts, string[] memory uris) public onlyOwner {
        require(amounts.length == uris.length, "Amounts and URIs length mismatch");
        uint256[] memory ids = new uint256[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            ids[i] = _nextTokenId++;
            _totalSupply[ids[i]] += amounts[i];
            _setTokenURI(ids[i], uris[i]);  // per-token URI
            _setURI(uris[i]);               // global URI (last wala override karega)
        }
        _mintBatch(to, ids, amounts, "");
    }

    function burnToken(uint256 id, uint256 amount) public validTokenId(id) {
        require(balanceOf(msg.sender, id) >= amount, "Insufficient balance to burn");
        burn(msg.sender, id, amount);
    }

    function transferToken(address to, uint256 id, uint256 amount) public validTokenId(id) {
        require(to != address(0), "Cannot transfer to zero address");
        require(balanceOf(msg.sender, id) >= amount, "Insufficient balance to transfer");
        safeTransferFrom(msg.sender, to, id, amount, "");
    }


    function totalSupply(uint256 id) public view returns (uint256) {
        return _totalSupply[id];
    }
}