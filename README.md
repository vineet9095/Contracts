Token Vesting Flow Guide
Step 1 — Deploy TestToken
Deploy the TestToken contract
No constructor arguments are required

After deployment:

Your wallet will receive 1,000,000 TTK tokens

Copy the deployed contract address.
This will be your _token address.

Step 2 — Deploy VestingContract
Deploy the VestingContract

Constructor parameter:

_token = <paste TestToken contract address>
Step 3 — Approve Tokens (Important)

Before creating vesting, you must approve tokens.

Call approve on the TestToken contract:

approve(
    spender = <VestingContract address>,
    amount  = 10000000000000000000000
)

This allows the vesting contract to transfer tokens on your behalf.

Do not skip this step.
Otherwise, createVesting() will fail with "transfer failed".

Step 4 — Create Vesting

Call createVesting on the VestingContract:

createVesting(
    user   = <user wallet address>,
    amount = 1000000000000000000000
)

This creates a vesting schedule for 1000 TTK tokens.

Step 5 — Claim Tokens
After 3 minutes, the user can claim tokens

Call from the user wallet:

claim()
Token Amount Reference
Tokens	Value (18 decimals)
1 TTK	1000000000000000000
100 TTK	100000000000000000000
1000 TTK	1000000000000000000000
10000 TTK	10000000000000000000000
Vesting Logic
Total Tokens: 1000 TTK
Duration: 1 hour
Interval: 3 minutes

Total intervals = 20

Release Schedule
Time	Tokens Released
After 3 minutes	50 TTK
After 6 minutes	50 TTK
After 9 minutes	50 TTK
...	...
After 60 minutes	Full 1000 TTK