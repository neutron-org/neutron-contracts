#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

CONTRACT_PATH="../artifacts/ibc_transfer.wasm"
CHAIN_ID="test-1"
NEUTRON_DIR="${NEUTRON_DIR:-../../neutron}"
HOME="$NEUTRON_DIR/data/test-1/"
KEY="demowallet1"
ADMIN="neutron1m9l358xunhhwds0568za49mzhvuxx9ux8xafx2"
BIN="neutrond"
NODE="tcp://127.0.0.1:16657"

code_id="$("$BIN" tx wasm store "$CONTRACT_PATH"  \
    --from "$KEY" -y --chain-id "$CHAIN_ID"       \
    --gas 50000000 --gas-prices 0.0025untrn       \
    --broadcast-mode=block --keyring-backend=test \
    --output json --home "$HOME" --node "$NODE"   \
    | jq -r '.logs[0].events[] | select(.type == "store_code").attributes[] | select(.key == "code_id").value')"
echo "Code ID: $code_id"

contract_address="$("$BIN" tx wasm instantiate "$code_id" '{}' \
    --from ${KEY} --admin ${ADMIN} -y --chain-id "$CHAIN_ID"   \
    --output json --broadcast-mode=block --label "init"        \
    --keyring-backend=test --gas-prices 0.0025untrn            \
    --home "$HOME" --node "$NODE"                              \
    | jq -r '.logs[0].events[] | select(.type == "instantiate").attributes[] | select(.key == "_contract_address").value')"
echo "Contract address: $contract_address"

tx_result="$("$BIN" tx bank send demowallet1 "$contract_address" 20000untrn \
    -y --chain-id "$CHAIN_ID" --home "$HOME" --node "$NODE"                 \
    --keyring-backend=test --gas-prices 0.0025untrn --output json           \
    --broadcast-mode=block)"
code="$(echo "$tx_result" | jq '.code')"
if [[ ! "$code" -eq 0 ]]; then
  echo "Failed to send money to contract: $(echo "$tx_result" | jq '.raw_log')" && exit 1
fi
echo "Sent money to contract to pay fees"

msg='{"set_fees":{
  "denom": "untrn",
  "ack_fee": "2000",
  "recv_fee": "0",
  "timeout_fee": "2000"
}}'
tx_result="$("$BIN" tx wasm execute "$contract_address" "$msg" \
    --from "$KEY" -y --chain-id "$CHAIN_ID" --output json      \
    --broadcast-mode=block --gas-prices 0.0025untrn            \
    --gas 1000000 --keyring-backend test --home "$HOME" --node "$NODE")"
code="$(echo "$tx_result" | jq '.code')"
if [[ ! "$code" -eq 0 ]]; then
  echo "Failed to set fees: $(echo "$tx_result" | jq '.raw_log')" && exit 1
fi
echo "Set fees"

msg='{"send":{
  "to": "cosmos17dtl0mjt3t77kpuhg2edqzjpszulwhgzuj9ljs",
  "amount": "1000",
  "denom": "untrn",
  "channel": "channel-0"
}}'
tx_result="$("$BIN" tx wasm execute "$contract_address" "$msg"    \
    --from ${KEY} -y --chain-id ${CHAIN_ID} --output json         \
    --broadcast-mode=block --gas-prices 0.0025untrn --gas 1000000 \
    --keyring-backend test --home "$HOME" --node "$NODE")"
code="$(echo "$tx_result" | jq '.code')"
if [[ ! "$code" -eq 0 ]]; then
  echo "Failed to execute contract: $(echo "$tx_result" | jq '.raw_log')" && exit 1
fi
echo "Performed IBC transfer through contract"
echo "Done!"

# the message above asks contract to send 1000untrn, but this example contract
# always sends triple the amount of money, hence we advise user to expect 3000untrn
echo
echo "cosmos17dtl0mjt3t77kpuhg2edqzjpszulwhgzuj9ljs should receive 3000untrn soon"
echo -n "To check that, you can run "
echo "'gaiad query bank balances cosmos17dtl0mjt3t77kpuhg2edqzjpszulwhgzuj9ljs --node tcp://localhost:26657'"
