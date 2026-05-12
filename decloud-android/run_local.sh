#!/bin/bash
# Run on emulator against local Hardhat node
# Fill in your deployed contract addresses below after: npx hardhat run scripts/deploy.js --network localhost

LOCAL_DCLD="0xYOUR_DCLD_ADDRESS"
LOCAL_ESCROW="0xYOUR_ESCROW_ADDRESS"

flutter run \
  --dart-define=NETWORK=local \
  --dart-define=LOCAL_RPC=http://10.0.2.2:8545 \
  --dart-define=LOCAL_DCLD=$LOCAL_DCLD \
  --dart-define=LOCAL_ESCROW=$LOCAL_ESCROW
