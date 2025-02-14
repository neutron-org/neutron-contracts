// import all helpers from v045 package
// to make it available from v047 package (kinda proxy) since they work with Cosmos SDK 0.47 as usual
pub use crate::interchain_queries::v045::register_queries::*;

use crate::interchain_queries::helpers::decode_and_convert;
use crate::interchain_queries::types::QueryType;
use crate::interchain_queries::v045::helpers::{create_delegation_key, create_validator_key};
use crate::interchain_queries::v045::types::STAKING_STORE_KEY;
use crate::interchain_queries::v047::types::STAKING_PARAMS_KEY;
use crate::NeutronResult;
use cosmwasm_std::{Addr, CosmosMsg};
use neutron_std::types::neutron::interchainqueries::{KvKey, MsgRegisterInterchainQuery};

/// Creates a message to register an Interchain Query to get delegations of particular delegator on remote chain.
///
/// * **connection_id** is an IBC connection identifier between Neutron and remote chain;
/// * **delegator** is an address of an account on remote chain for which you want to get list of delegations;
/// * **validators** is a list of validators addresses for which you want to get delegations from particular **delegator**;
/// * **update_period** is used to say how often the query must be updated.
pub fn new_register_delegator_delegations_query_msg(
    contract: Addr,
    connection_id: String,
    delegator: String,
    validators: Vec<String>,
    update_period: u64,
) -> NeutronResult<CosmosMsg> {
    let delegator_addr = decode_and_convert(&delegator)?;

    // Allocate memory for such KV keys as:
    // * staking module params to get staking denomination
    // * validators structures to calculate amount of delegated tokens
    // * delegations structures to get info about delegations itself
    let mut keys: Vec<KvKey> = Vec::with_capacity(validators.len() * 2 + 1);

    // create KV key to get Staking Params from staking module
    keys.push(KvKey {
        path: STAKING_STORE_KEY.to_string(),
        key: vec![STAKING_PARAMS_KEY],
    });

    for v in validators {
        let val_addr = decode_and_convert(&v)?;

        // create delegation key to get delegation structure
        keys.push(KvKey {
            path: STAKING_STORE_KEY.to_string(),
            key: create_delegation_key(&delegator_addr, &val_addr)?,
        });

        // create validator key to get validator structure
        keys.push(KvKey {
            path: STAKING_STORE_KEY.to_string(),
            key: create_validator_key(&val_addr)?,
        })
    }

    Ok(MsgRegisterInterchainQuery {
        query_type: QueryType::KV.into(),
        keys,
        transactions_filter: "".to_string(),
        connection_id,
        update_period,
        sender: contract.to_string(),
    }
    .into())
}
