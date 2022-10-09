import { resolve, join } from "path";
import { compile } from "@noir-lang/noir_wasm";
import { setup_generic_prover_and_verifier } from "@noir-lang/barretenberg/dest/client_proofs";
import { writeFileSync } from "fs";

async function generateSolVerifier() {
  // console.log(resolve(__dirname, "src/main.nr"));
  const compiled = compile(resolve(__dirname, "src/main.nr"));
  const acir = compiled.circuit;
  console.log("ACIR", acir);

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
