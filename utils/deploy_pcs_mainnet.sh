#!/usr/bin/env bash

source .env

read -p "This script will deploy the contract to BSC mainnet, continue? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    forge script script/DeployPcsTestnet.s.sol:DeployPcs --rpc-url=bsctest --broadcast --verify -vvvv
fi
