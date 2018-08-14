# P2PCP Smart Contract

1.  User to call **APPROVE** in *Token Contract* to allow *Contract Address* to spend their token

2.  User to call **MakeTransaction** in *Contract Address* with -
    - `_tokenOwner` (user address)
    - `_premiumAmount` (payment in wei)
    - `_payoutAmount` (payout in wei)
    - `_exchange` (exchange name)
    - `_token` (token ticker)
    - `_id` (id in int)
