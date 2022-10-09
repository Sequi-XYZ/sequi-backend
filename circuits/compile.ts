import { resolve, join } from "path";
import { compile, acir_to_bytes } from "@noir-lang/noir_wasm";
import { setup_generic_prover_and_verifier } from "@noir-lang/barretenberg/dest/client_proofs";
import { writeFileSync, readFileSync } from "fs";

async function generateSolVerifier() {
  // console.log(resolve(__dirname, "src/main.nr"));
  const compiled = compile(resolve(__dirname, "src/main.nr"));
  const acir = compiled.circuit;
  const buffer = readFileSync(resolve(__dirname, "src/main.nr"));
  const acirbytes = acir_to_bytes(acir)
  console.log(Buffer.from(acirbytes).toString("hex"));
  // console.log("ACIR", acir);

  const [, verifier] = await setup_generic_prover_and_verifier(acir);

  const sc = verifier.SmartContract();
  syncWriteFile("../src/verifiers/verifier.sol", sc);

  console.log("✨ done writing sol verifier ✨");
}

function syncWriteFile(filename: string, data: any) {
  writeFileSync(join(__dirname, filename), data, {
    flag: "w",
  });
}

generateSolVerifier()
  .then(() => process.exit(0))
  .catch(console.log);
