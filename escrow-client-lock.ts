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

const clientPublicKeyHash = lucid.utils.getAddressDetails(
  await lucid.wallet.address()
).paymentCredential.hash;

const contractorPublicKeyHash = lucid.utils.getAddressDetails(
  await Deno.readTextFile("./contractor.addr")
).paymentCredential.hash;

const Datum = Data.Object({
  projectName: Data.Bytes,
  projectRequirements: Data.Bytes,
  clientPubKeyHash: Data.Bytes,
  contractorPubKeyHash: Data.Bytes,
  progress: Data.Integer,
  isDone: Data.Integer,
});

type Datum = Data.Static<typeof Datum>;

const datum = Data.to<Datum>(
  {
    projectName: fromText("Training Aiken"),
    projectRequirements: fromText("Support a new members"),
    clientPubKeyHash: clientPublicKeyHash,
    contractorPubKeyHash: contractorPublicKeyHash,
    progress: 0n,
    isDone: 0n,
  },
  Datum
);

const txLock = await lock(10000000, { into: validator, datum: datum });

await lucid.awaitTx(txLock);

console.log(`1 tADA locked into the contract
      Tx ID: ${txLock}
      Datum: ${datum}
  `);

// --- Supporting functions

async function lock(lovelace, { into, datum }): Promise<TxHash> {
  const contractAddress = lucid.utils.validatorToAddress(into);

  const tx = await lucid
    .newTx()
    .payToContract(contractAddress, { inline: datum }, { lovelace })
    .complete();
  const signedTx = await tx.sign().complete();
  return signedTx.submit();
}
// Tx ID: 6261db5964000e893157a4abe0cb04923a037ead10e3580a217c386f8709e180
// Datum: d8799f1903e8ff
