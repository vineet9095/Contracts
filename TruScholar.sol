// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract VCRegister is Ownable {

    // Issued credentials Merkle roots
    mapping(bytes32 => bytes32) public batchRoots;

    // Revoked credentials Merkle roots
    mapping(bytes32 => bytes32) public revokeRoots;

    event RootAdded(bytes32 indexed batchId, bytes32 merkleRoot, uint256 timestamp);
    event RevokeRootAdded(bytes32 indexed batchId, bytes32 revokeMerkleRoot, uint256 timestamp);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function addMerkleRoot(
        bytes32 batchId,
        bytes32 merkleRoot
    ) external onlyOwner {
        require(batchRoots[batchId] == bytes32(0), "Batch ID already exists");
        batchRoots[batchId] = merkleRoot;
        emit RootAdded(batchId, merkleRoot, block.timestamp);
    }

    function verifyIssued(
        bytes32 batchId,
        bytes32[] calldata proof,
        bytes32 leaf
    ) external view returns (bool) {
        bytes32 root = batchRoots[batchId];
        require(root != bytes32(0), "Unknown batch");

        return MerkleProof.verify(proof, root, leaf);
    }

    function addRevokeMerkleRoot(
        bytes32 batchId,
        bytes32 revokeMerkleRoot
    ) external onlyOwner {
        revokeRoots[batchId] = revokeMerkleRoot;
        emit RevokeRootAdded(batchId, revokeMerkleRoot, block.timestamp);
    }

    function verifyRevoked(
        bytes32 batchId,
        bytes32[] calldata proof,
        bytes32 leaf
    ) external view returns (bool) {
        bytes32 root = revokeRoots[batchId];
        require(root != bytes32(0), "No revoke root found");

        return MerkleProof.verify(proof, root, leaf);
    }
}