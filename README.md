Step 1 — Deploy TestToken

Deploy karo, koi argument nahi chahiye
Tumhare wallet ko mil jayenge 1,000,000 TTK
Copy the deployed address → ye hai tera _token address

Step 2 — Deploy VestingContract
_token = <TestToken address paste karo>

Step 3 — Approve karo (IMPORTANT ⚠️)
TestToken → approve(
    spender = <VestingContract address>,
    amount  = 10000000000000000000000  // ya jitna chahiye
)

Ye step miss mat karna — bina approve ke createVesting fail hoga with transfer failed

Step 4 — Create Vesting
VestingContract → createVesting(
    user   = <user wallet address>,
    amount = 1000000000000000000000   // 1000 TTK (18 decimals)
)

Step 5 — 3 min baad claim karo user wallet se
VestingContract → claim()

Token Amount Quick Reference
1 TTK      = 1000000000000000000      (1 * 10^18)
100 TTK    = 100000000000000000000
1000 TTK   = 1000000000000000000000
10000 TTK  = 10000000000000000000000


Total = 1000 tokens, Duration = 1 hour, Interval = 3 min
→ 20 intervals total

After 3 min  → claim 50 tokens  (1/20)
After 6 min  → claim 50 tokens  (2/20)
After 9 min  → claim 50 tokens  ...
After 60 min → all 1000 released
