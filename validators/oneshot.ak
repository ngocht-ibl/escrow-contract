use aiken/hash.{Blake2b_224, Hash}
use aiken/list.{head}
use aiken/option.{is_some}
use aiken/transaction.{
  InlineDatum, Input, Output, OutputReference, ScriptContext, Spend, Transaction,
  TransactionId, find_input, find_script_outputs,
}
use aiken/transaction/credential.{
  ScriptCredential, VerificationKey, from_verification_key,
}
use aiken/transaction/value.{from_lovelace}

type Datum {
  projectName: ByteArray,
  projectRequirements: ByteArray,
  clientPubKeyHash: VerificationKeyHash,
  contractorPubKeyHash: VerificationKeyHash,
  progress: Int,
  isDone: Int,
}

type VerificationKeyHash =
  Hash<Blake2b_224, VerificationKey>

type Redeemer {
  ClientUpdate { isDone: Int }
  ContractorUpdate { progress: Int }
  ContractorClaim
}

validator {
  fn lock(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) {
    when ctx.purpose is {
      Spend(output_ref) ->
        when redeemer is {
          ClientUpdate { isDone } -> and {
              must_be_signed_by(ctx.transaction, datum.clientPubKeyHash),
              {
                let datum_in_output =
                  get_datum_in_output(ctx.transaction, output_ref)

                if datum_in_output.projectName != datum.projectName {
                  trace @"PROJECT_NAME_MUST_BE_UNCHANGED"
                  False
                } else if datum_in_output.projectRequirements != datum.projectRequirements {
                  trace @"PROJECT_REQUIREMENTS_MUST_BE_UNCHANGED"
                  False
                } else if datum_in_output.clientPubKeyHash != datum.clientPubKeyHash {
                  trace @"CLIENT_PUB_KEY_HASH_MUST_BE_UNCHANGED"
                  False
                } else if datum_in_output.contractorPubKeyHash != datum.contractorPubKeyHash {
                  trace @"CONTRACTOR_PUB_KEY_HASH_MUST_BE_UNCHANGED"
                  False
                } else if datum_in_output.progress != datum.progress {
                  trace @"PROGRESS_MUST_BE_UNCHANGED"
                  False
                } else {
                  datum_in_output.isDone == isDone
                }
              },
              must_lock_assets(ctx.transaction, output_ref),
            }
          ContractorUpdate { progress } -> and {
              must_be_signed_by(ctx.transaction, datum.contractorPubKeyHash)?,
              {
                let datum_in_output =
                  get_datum_in_output(ctx.transaction, output_ref)

                if datum_in_output.projectName != datum.projectName {
                  trace @"PROJECT_NAME_MUST_BE_UNCHANGED"
                  False
                } else if datum_in_output.projectRequirements != datum.projectRequirements {
                  trace @"PROJECT_REQUIREMENTS_MUST_BE_UNCHANGED"
                  False
                } else if datum_in_output.clientPubKeyHash != datum.clientPubKeyHash {
                  trace @"CLIENT_PUB_KEY_HASH_MUST_BE_UNCHANGED"
                  False
                } else if datum_in_output.contractorPubKeyHash != datum.contractorPubKeyHash {
                  trace @"CONTRACTOR_PUB_KEY_HASH_MUST_BE_UNCHANGED"
                  False
                } else if datum_in_output.isDone != datum.isDone {
                  trace @"DONE_MUST_BE_UNCHANGED"
                  False
                } else {
                  datum_in_output.progress == progress
                }
              },
              must_lock_assets(ctx.transaction, output_ref),
            }
          ContractorClaim -> and {
              must_be_signed_by(ctx.transaction, datum.contractorPubKeyHash)?,
              datum.isDone == 1,
            }
        }
      _ -> False
    }
  }
}

fn must_be_signed_by(transaction: Transaction, vk: VerificationKeyHash) {
  list.has(transaction.extra_signatories, vk)
}

fn get_datum_in_output(
  transaction: Transaction,
  output_ref: OutputReference,
) -> Datum {
  let Transaction { inputs, outputs, .. } = transaction
  expect Some(input) = find_input(inputs, output_ref)
  expect ScriptCredential(addr_script_hash) =
    input.output.address.payment_credential
  let continue_outputs = find_script_outputs(outputs, addr_script_hash)
  expect Some(output) = head(continue_outputs)
  expect InlineDatum(data) = output.datum
  expect the_input_datum: Datum = data
  the_input_datum
}

fn must_lock_assets(transaction: Transaction, output_ref: OutputReference) {
  let Transaction { inputs, outputs, .. } = transaction
  expect Some(input) = find_input(inputs, output_ref)
  let is_exist =
    outputs
      |> list.find(fn(output) { and {
               output.value == input.output.value,
               output.address == input.output.address,
             } })
      |> is_some()
  if is_exist {
    True
  } else {
    trace @"LOCK_ASSETS_INVALID"
    False
  }
}

test must_lock_assets_successfully() {
  let output_reference_placeholder =
    OutputReference { transaction_id: TransactionId(""), output_index: 0 }

  let output_placeholder =
    Output {
      datum: transaction.NoDatum,
      reference_script: None,
      value: from_lovelace(1000000),
      address: from_verification_key(
        #"00000000000000000000000000000000000000000000000000000000",
      ),
    }

  let input =
    Input {
      output_reference: output_reference_placeholder,
      output: output_placeholder,
    }
  let context =
    ScriptContext {
      purpose: transaction.Spend(output_reference_placeholder),
      transaction: transaction.placeholder()
        |> fn(transaction) {
             Transaction {
               ..transaction,
               inputs: [input],
               outputs: [output_placeholder],
             }
           },
    }
  must_lock_assets(context.transaction, output_reference_placeholder)
}

test must_lock_assets_failed_invalid_lock_address() {
  let output_reference_placeholder =
    OutputReference { transaction_id: TransactionId(""), output_index: 0 }

  let output_placeholder =
    Output {
      datum: transaction.NoDatum,
      reference_script: None,
      value: from_lovelace(1000000),
      address: from_verification_key(
        #"00000000000000000000000000000000000000000000000000000000",
      ),
    }

  let input =
    Input {
      output_reference: output_reference_placeholder,
      output: Output {
        ..output_placeholder,
        address: from_verification_key(
          #"00000000000000000000000000000000000000000000000000000001",
        ),
      },
    }
  let context =
    ScriptContext {
      purpose: transaction.Spend(output_reference_placeholder),
      transaction: transaction.placeholder()
        |> fn(transaction) {
             Transaction {
               ..transaction,
               inputs: [input],
               outputs: [output_placeholder],
             }
           },
    }
  must_lock_assets(context.transaction, output_reference_placeholder)
}

test must_lock_assets_failed_invalid_lock_value() {
  let output_reference_placeholder =
    OutputReference { transaction_id: TransactionId(""), output_index: 0 }

  let output_placeholder =
    Output {
      datum: transaction.NoDatum,
      reference_script: None,
      value: from_lovelace(1000000),
      address: from_verification_key(
        #"00000000000000000000000000000000000000000000000000000000",
      ),
    }

  let input =
    Input {
      output_reference: output_reference_placeholder,
      output: Output { ..output_placeholder, value: from_lovelace(300000) },
    }
  let context =
    ScriptContext {
      purpose: transaction.Spend(output_reference_placeholder),
      transaction: transaction.placeholder()
        |> fn(transaction) {
             Transaction {
               ..transaction,
               inputs: [input],
               outputs: [output_placeholder],
             }
           },
    }
  must_lock_assets(context.transaction, output_reference_placeholder)
}
