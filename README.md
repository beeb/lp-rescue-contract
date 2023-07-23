![LP-Rescue](https://github.com/beeb/lp-rescue-frontend/raw/main/logo-readme.svg)

# LP Rescue Contract

<p align="center">
  <a href="https://github.com/beeb/lp-rescue-contract/actions/workflows/ci.yml">
    <img src="https://github.com/beeb/lp-rescue-contract/actions/workflows/ci.yml/badge.svg" />
  </a> -
  <a href="https://github.com/beeb/lp-rescue-frontend">Front-end dApp</a>
</p>

This contract allows to add liquidity to a Uniswap v2 or PancakeSwap v2 LP contract which was exploited by sending
some tokens and calling the `sync` function, effectively setting one of the reserves to a non-zero value.

The Router contract will refuse to add liquidity to such a pool, so `LPRescue` can be used to add liquidity instead.

## Description of the problem

When calling the `sync` function on an AMM pair contract when one of the balances is zero and the other is non-zero,
the contract will modify the reserve state variables so that they match the balances.

As such, if some `token0` was sent to the pair, and afterwards (before `skim` is called by another actor, for instance)
the `sync` function is called (usually in the same transaction), the contract will set the `reserve0` state variable
to the balance of `token0` in the contract, and `reserve1` will be equal to zero.

In such a situation, the `addLiquidity` or `addLiquidityETH` of the DEX router will revert.

## Description of the solution

The solution is to handle this particular case (one reserve is non-zero and the other is zero) with fewer checks
than the regular `addLiquidity` function.

This contract, in essence, sends the missing amount of tokens to reach the desired liquidity ratio, and then calls
the `mint` function of the pair in the same transaction, effectively resetting reserves and creating liquidity tokens.

In our case, the `mint` function was never called before, because it would revert if one of the balances was zero.
If both balances are non-zero, then LP tokens can be minted, the balances `sync`ed and `LPRescue` would not be needed.

## Additional notes

Due to how the pair contract is coded, when minting liquidity tokens, the pre-existing reserve value will be subtracted
from the pair's balance when calculating the invariant (and amount of LP tokens). This is usually insignificant as
malicious actors send a very small amount of tokens to get the pair in this stuck state, since those tokens are lost
to them.

## Forge/NPM commands

Since the self-deployed Uniswap pair contracts have a different bytecode than the deployed version, the Uniswap V2
Library function that calculates the pair address deterministically without external calls is not working locally.

To fix this, the library is patched when the dependencies are installed with `npm i`.

```shell
$ npm i
$ forge install
$ forge test -vvv
$ ./utils/deploy_pcs_testnet.sh
$ ./utils/deploy_pcs_mainnet.sh
```
