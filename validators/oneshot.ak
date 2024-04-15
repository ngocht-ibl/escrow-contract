use aiken/hash.{Blake2b_224, Hash}
use aiken/interval.{Finite, Interval, IntervalBound, PositiveInfinity}
use aiken/list
use aiken/transaction.{ScriptContext, Spend, Transaction, ValidityRange}
use aiken/transaction/credential.{VerificationKey}

type Datum {
  projectName: ByteArray,
  projectRequirements: ByteArray,
  clientPubKeyHash: VerificationKeyHash,
  contractorPubKeyHash: VerificationKeyHash,
  progress: Int,
  isDone: Bool
}

type VerificationKeyHash =
  Hash<Blake2b_224, VerificationKey>

validator {
  fn lockValid(datum: Datum, _redeemer: Void, ctx: ScriptContext) {
    when ctx.purpose is {
      Spend(_) -> and {
          must_be_signed_by(ctx.transaction, datum.contractorPubKeyHash),
          datum.isDone
        }
      _ -> False
    }
  }
}

fn must_be_signed_by(transaction: Transaction, vk: VerificationKeyHash) {
  list.has(transaction.extra_signatories, vk)
}