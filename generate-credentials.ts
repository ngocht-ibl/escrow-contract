import { Lucid } from "https://deno.land/x/lucid@0.8.3/mod.ts";
 
const lucid = await Lucid.new(undefined, "Preview");
 
const clientPrivateKey = lucid.utils.generatePrivateKey();
await Deno.writeTextFile("client.sk", clientPrivateKey);
 
const clientAddress = await lucid
  .selectWalletFromPrivateKey(clientPrivateKey)
  .wallet.address();
await Deno.writeTextFile("client.addr", clientAddress);
 
const contractorPrivateKey = lucid.utils.generatePrivateKey();
await Deno.writeTextFile("contractor.sk", contractorPrivateKey);
 
const contractorAddress = await lucid
  .selectWalletFromPrivateKey(contractorPrivateKey)
  .wallet.address();
await Deno.writeTextFile("contractor.addr", contractorAddress);
