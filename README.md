# LP Rescue Contract

This contract allows to add liquidity to a Uniswap v2 or PancakeSwap v2 LP contract which was exploited by sending
base tokens and calling the `sync` function, effectively setting one of the reserves to a non-zero value.

The Router contract will refuse to add liquidity to such a pool, so this contract can be used to add liquidity instead.

```shell
npx hardhat help
npx hardhat test
GAS_REPORT=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```
