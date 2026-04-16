// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract VestingContract is Ownable, ReentrancyGuard {

    IERC20 public immutable token;

    // uint256 public constant INTERVAL = 30 days / 10; // 10 equal intervals over 30 days
    // uint256 public constant TOTAL_DURATION = 30 days;

    uint256 public constant INTERVAL = 3 minutes;   // token release every 3 min
    uint256 public constant TOTAL_DURATION = 1 hours; // full vest in 1 hour
    // totalIntervals = 60/3 = 20 intervals

    struct Vesting {
        uint256 total;
        uint256 start;
        uint256 released;
        bool exists;
        bool revoked;
    }

    mapping(address => Vesting) public vestings;

    // ── Events ────────────────────────────────────────────────
    event VestingCreated(address indexed user, uint256 amount, uint256 start);
    event Claimed(address indexed user, uint256 amount);
    event VestingRevoked(address indexed user, uint256 unvestedReturned);

    // ── Constructor ───────────────────────────────────────────
    constructor(address _token) Ownable(msg.sender) {
        require(_token != address(0), "zero token address");
        token = IERC20(_token);
    }

    // ── Owner: Create Vesting ─────────────────────────────────
    function createVesting(address user, uint256 amount) external onlyOwner {
        require(user != address(0), "zero address");
        require(amount > 0, "amount 0");
        require(!vestings[user].exists, "already exists");

        require(token.transferFrom(msg.sender, address(this), amount),"transfer failed");

        vestings[user] = Vesting({
            total: amount,
            start: block.timestamp,
            released: 0,
            exists: true,
            revoked: false
        });

        emit VestingCreated(user, amount, block.timestamp);
    }

    // ── Owner: Revoke Vesting ─────────────────────────────────
    function revokeVesting(address user) external onlyOwner nonReentrant {
        Vesting storage v = vestings[user];
        require(v.exists, "no vesting");
        require(!v.revoked, "already revoked");

        // Let user claim whatever is already vested first
        uint256 claimable = _releasable(user);
        uint256 unvested = v.total - v.released - claimable;

        v.revoked = true;

        // Pay out claimable portion to the user (if any)
        if (claimable > 0) {
            v.released += claimable;
            require(token.transfer(user, claimable), "user transfer failed");
        }

        // Return unvested tokens to owner
        if (unvested > 0) {
            require(token.transfer(owner(), unvested), "owner transfer failed");
        }

        emit VestingRevoked(user, unvested);
    }

    // ── Internal: Releasable Calculation ──────────────────────
    function _releasable(address user) internal view returns (uint256) {
        Vesting memory v = vestings[user];
        if (!v.exists || v.revoked) return 0;

        uint256 elapsed = block.timestamp - v.start;

        if (elapsed >= TOTAL_DURATION) {
            return v.total - v.released;
        }

        uint256 totalIntervals = TOTAL_DURATION / INTERVAL;
        uint256 passedIntervals = elapsed / INTERVAL;

        uint256 vested = (v.total * passedIntervals) / totalIntervals;

        if (vested <= v.released) return 0;
        return vested - v.released;
    }

    // ── User: Claim ───────────────────────────────────────────
    function claim() external nonReentrant {
        Vesting storage v = vestings[msg.sender];
        require(v.exists, "no vesting");
        require(!v.revoked, "vesting revoked");

        uint256 amount = _releasable(msg.sender);
        require(amount > 0, "nothing to claim");

        // CEI: state update before external call
        v.released += amount;

        require(token.transfer(msg.sender, amount), "transfer failed");

        emit Claimed(msg.sender, amount);
    }

    // ── View: UI Info ─────────────────────────────────────────
    function info(address user)
        external
        view
        returns (
            uint256 total,
            uint256 released,
            uint256 claimable,
            bool revoked
        )
    {
        Vesting memory v = vestings[user];
        return (v.total, v.released, _releasable(user), v.revoked);
    }

    // ── View: Contract Balance ────────────────────────────────
    function contractBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}