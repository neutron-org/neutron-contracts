#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

BIN="neutrond"
GAIA_BIN="gaiad"
CONTRACT="../artifacts/neutron_interchain_txs.wasm"
CHAIN_ID_1="test-1"
CHAIN_ID_2="test-2"
NEUTRON_DIR="${NEUTRON_DIR:-../../neutron}"
HOME_1="${NEUTRON_DIR}/data/test-1/"
HOME_2="${NEUTRON_DIR}/data/test-2/"
ADDRESS_1="neutron1m9l358xunhhwds0568za49mzhvuxx9ux8xafx2"
ADDRESS_2="cosmos10h9stc5v6ntgeygf5xf945njqq5h32r53uquvw"
ADMIN="neutron1m9l358xunhhwds0568za49mzhvuxx9ux8xafx2"
VAL2="cosmos1qnk2n4nlkpw9xfqntladh74w6ujtulwn7j8za9"

# Upload the txs contract
RES=$(${BIN} tx wasm store ${CONTRACT} --from ${ADDRESS_1} --gas 50000000  --chain-id ${CHAIN_ID_1} --broadcast-mode=block --gas-prices 0.0025stake  -y --output json  --keyring-backend test --home ${HOME_1} --node tcp://127.0.0.1:16657)
CONTRACT_CODE_ID=$(echo $RES | jq -r '.logs[0].events[1].attributes[0].value')
echo $RES
echo $CONTRACT_CODE_ID

# Instantiate the contract
INIT_CONTRACT='{}'
echo "Instantiate"
RES=$(${BIN} tx wasm instantiate $CONTRACT_CODE_ID "$INIT_CONTRACT" --from ${ADDRESS_1} --admin ${ADMIN} -y --chain-id ${CHAIN_ID_1} --output json --broadcast-mode=block --label "init"  --keyring-backend test --gas-prices 0.0025stake --gas auto --gas-adjustment 1.4 --home ${HOME_1} --node tcp://127.0.0.1:16657)
CONTRACT_ADDRESS=$(echo $RES | jq -r '.logs[0].events[0].attributes[0].value')
echo $CONTRACT_ADDRESS

${BIN} tx bank send demowallet1 ${CONTRACT_ADDRESS} 100000stake --chain-id ${CHAIN_ID_1} --home ${HOME_1} --node tcp://localhost:16657 --keyring-backend test -y --gas-prices 0.0025stake --broadcast-mode=block

#Register interchain account
RES=$(${BIN} tx wasm execute $CONTRACT_ADDRESS "{\"register\": {\"connection_id\": \"connection-0\", \"interchain_account_id\": \"test\"}}" --from ${ADDRESS_1}  -y --chain-id ${CHAIN_ID_1} --output json --broadcast-mode=block --gas-prices 0.0025stake --gas 1000000 --keyring-backend test --home ${HOME_1} --node tcp://127.0.0.1:16657)
echo $RES
sleep 20

RES=$(curl http://127.0.0.1:1316/wasm/contract/$CONTRACT_ADDRESS/smart/eyJpbnRlcmNoYWluX2FjY291bnRfYWRkcmVzc19mcm9tX2NvbnRyYWN0Ijp7ImludGVyY2hhaW5fYWNjb3VudF9pZCI6InRlc3QifX0\=?encoding\=base64 | jq -r ".result.smart")
echo $RES
ICA_ADDRESS=$(echo $RES | base64 --decode | jq -r ".[0]")
echo $ICA_ADDRESS

#Send some money to ICA
RES=$(${GAIA_BIN} tx bank send ${ADDRESS_2} ${ICA_ADDRESS} 10000stake --chain-id ${CHAIN_ID_2}  --broadcast-mode=block --gas-prices 0.0025stake -y --output json --keyring-backend test --home ${HOME_2} --node tcp://127.0.0.1:26657)
echo $RES

#Delegate
RES=$(${BIN} tx wasm execute $CONTRACT_ADDRESS "{\"delegate\": {\"interchain_account_id\": \"test\", \"validator\": \"${VAL2}\", \"amount\":\"5000\",\"denom\":\"stake\"}}" --from ${ADDRESS_1}  -y --chain-id ${CHAIN_ID_1} --output json --broadcast-mode=block --gas-prices 0.0025stake --gas 1000000 --keyring-backend test --home ${HOME_1} --node tcp://127.0.0.1:16657)
echo $RES

sleep 7
curl http://127.0.0.1:1317/staking/delegators/$ICA_ADDRESS/delegations