import {
  Blockfrost,
  C,
  Constr,
  Data,
  Lucid,
  SpendingValidator,
  TxHash,
  fromText,
  toHex,
  fromHex,
  applyParamsToScript,
} from "https://deno.land/x/lucid@0.10.7/mod.ts";
import * as cbor from "https://deno.land/x/cbor@v1.4.1/index.js";

const lucid = await Lucid.new(
  new Blockfrost(
    "https://cardano-preview.blockfrost.io/api/v0",
    "previewLCPjybjup7ESDKMqSjZxGdzj5TdV7Pyd"
  ),
  "Preview"
);

lucid.selectWalletFromPrivateKey(await Deno.readTextFile("./client.sk"));

async function readValidator(): Promise<SpendingValidator> {
  const validator = JSON.parse(await Deno.readTextFile("plutus.json"))
    .validators[0];
  return {
    type: "PlutusV2",
    script: toHex(cbor.encode(fromHex(validator.compiledCode))),
  };
}

const validator = await readValidator();

const contractAddress = lucid.utils.validatorToAddress(validator);
const contractUtxos = await lucid.utxosAt(contractAddress);

const Datum = Data.Object({
  projectName: Data.Bytes,
  projectRequirements: Data.Bytes,
  clientPubKeyHash: Data.Bytes,
  contractorPubKeyHash: Data.Bytes,
  progress: Data.Integer,
  isDone: Data.Integer,
});

type Datum = Data.Static<typeof Datum>;

const clientPublicKeyHash = lucid.utils.getAddressDetails(
  await lucid.wallet.address()
).paymentCredential.hash;

const scUtxos = contractUtxos.filter((utxo) => {
  try {
    let datum = Data.from<Datum>(utxo.datum, Datum);

    return datum.clientPubKeyHash === clientPublicKeyHash;
  } catch (error) {
    console.log("filtering smart contract utxos failed: ", error);
    return false;
  }
});

if (scUtxos.length === 0) {
  console.log("No redeemable utxo found. You need to wait a little longer...");
  Deno.exit(1);
}

const scUtxo = scUtxos[0];

const prevDatum = Data.from<Datum>(scUtxo.datum, Datum);

console.log("prevDatum: ", prevDatum);

const datum = Data.to<Datum>(
  {
    ...prevDatum,
    isDone: 1n
  },
  Datum
);

const redeemer = Data.to(new Constr(0, [1n]));

const tx = await updateAndLock({
  using: redeemer,
  from: validator
});

await lucid.awaitTx(tx);

console.log(`1 tADA locked into the contract
      Tx ID: ${tx}
      Datum: ${datum}
  `);

// // --- Supporting functions

async function updateAndLock({ from, using }): Promise<TxHash> {
  try {
    const tx = await lucid
    .newTx()
    .collectFrom(scUtxos, using)
    .addSigner(await lucid.wallet.address())
    .attachSpendingValidator(from)
    .payToContract(contractAddress, { inline: datum }, { lovelace: 1000000 })
    .complete();
  const signedTx = await tx.sign().complete();
  return signedTx.submit();
  } catch (error) {
    console.log('error: ', error)
  }
 
}
// Tx ID: 6261db5964000e893157a4abe0cb04923a037ead10e3580a217c386f8709e180
// Datum: d8799f1903e8ff
