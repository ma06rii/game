// Read-only checks for a declaration on STARKNET_NETWORK (Sepolia by default).
// Run inside Varlock so the RPC URL (and, in diagnostic mode, deployer address)
// are supplied without printing them. --status exits 0 when declared, 3 when not.
const NETWORKS = {
  sepolia: { chainId: "0x534e5f5345504f4c4941", label: "Sepolia" },
  mainnet: { chainId: "0x534e5f4d41494e", label: "Mainnet" },
};
const NOT_DECLARED_STATUS = 3;
const classHash = process.argv[2];
const requireDeclared = process.argv[3] === "--require-declared";
const statusOnly = process.argv[3] === "--status";
const transactionHash = requireDeclared || statusOnly ? undefined : process.argv[3];
const rpcUrl = process.env.STARKNET_RPC_URL;
const deployerAddress = process.env.DEPLOYER_ADDRESS;
const network = NETWORKS[process.env.STARKNET_NETWORK || "sepolia"];
const usage =
  "Usage: node scripts/check-declaration.mjs 0xCLASS_HASH [0xTX_HASH|--require-declared|--status]\n";

if (!classHash || !/^0x[0-9a-f]+$/i.test(classHash) || process.argv.length > 4) {
  process.stderr.write(usage);
  process.exit(2);
}
if (!network) {
  process.stderr.write("STARKNET_NETWORK must be sepolia or mainnet\n");
  process.exit(2);
}
if (transactionHash && !/^0x[0-9a-f]+$/i.test(transactionHash)) {
  process.stderr.write("Transaction hash must be hexadecimal\n");
  process.exit(2);
}
if (!rpcUrl || (!requireDeclared && !statusOnly && !deployerAddress)) {
  process.stderr.write(
    requireDeclared || statusOnly
      ? "STARKNET_RPC_URL must be loaded through Varlock\n"
      : "STARKNET_RPC_URL and DEPLOYER_ADDRESS must be loaded through Varlock\n",
  );
  process.exit(2);
}

async function rpc(method, params = {}) {
  let response;
  try {
    response = await fetch(rpcUrl, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
    });
  } catch {
    throw new Error("RPC connection failed; check the configured endpoint");
  }
  if (!response.ok) throw new Error(`RPC returned HTTP ${response.status}`);
  const payload = await response.json();
  if (payload.error) {
    return { error: payload.error };
  }
  return { result: payload.result };
}

try {
  const chain = await rpc("starknet_chainId");
  if (chain.error || BigInt(chain.result) !== BigInt(network.chainId)) {
    throw new Error(`Configured RPC is not Starknet ${network.label}`);
  }
  const declaration = await rpc("starknet_getClass", {
    block_id: "latest",
    class_hash: classHash,
  });
  if (declaration.error && Number(declaration.error.code) !== 28) {
    throw new Error(`Class lookup failed: ${declaration.error.code} ${declaration.error.message}`);
  }
  if (!declaration.error && !declaration.result) {
    throw new Error("Class lookup returned no result");
  }
  process.stdout.write(`Class at latest: ${declaration.error ? "not declared" : "declared"}\n`);

  if (requireDeclared) {
    if (declaration.error) throw new Error(`Class ${classHash} is not declared at latest`);
  } else if (statusOnly) {
    if (declaration.error) process.exitCode = NOT_DECLARED_STATUS;
  } else {
    if (transactionHash) {
      const transaction = await rpc("starknet_getTransactionStatus", {
        transaction_hash: transactionHash,
      });
      if (transaction.error && transaction.error.code !== 29) {
        throw new Error(`Transaction lookup failed: ${transaction.error.code} ${transaction.error.message}`);
      }
      process.stdout.write(
        `Transaction: ${transaction.error ? "not found on this node" : JSON.stringify(transaction.result)}\n`,
      );
    }

    const nonce = await rpc("starknet_getNonce", {
      block_id: "latest",
      contract_address: deployerAddress,
    });
    if (nonce.error) {
      throw new Error(`Nonce lookup failed: ${nonce.error.code} ${nonce.error.message}`);
    }
    process.stdout.write(`Deployer nonce at latest: ${BigInt(nonce.result).toString()}\n`);
  }
} catch (error) {
  process.stderr.write(`Declaration check failed: ${error.message}\n`);
  process.exitCode = 1;
}
