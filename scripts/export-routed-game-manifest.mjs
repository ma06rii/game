import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

// The Cairo build is the source of truth for the old typed signatures. Clients
// use this snapshot only to encode/decode arguments; every actual call goes to
// HelloStarknet.route at the single game address.
const facets = [
  'RoundActions', 'RoundViews', 'HideActions', 'HideViews',
  'FinderValidation', 'FinderActions', 'FinderViews', 'UsdcClaims',
  'RozClaims', 'SettingsActions', 'SettingsViews', 'Treasury',
  'AdminUpgrade', 'AdminActions',
];

export function routedGameManifest(directory = 'target/release') {
  const types = new Map();
  const interfaces = [];
  const methods = {};
  for (const [facet, name] of facets.entries()) {
    const file = path.join(directory, `project_name_Game${name}Facet.contract_class.json`);
    const abi = JSON.parse(readFileSync(file, 'utf8')).abi;
    for (const entry of abi) {
      if (entry.type === 'struct' || entry.type === 'enum') {
        const previous = types.get(entry.name);
        if (previous && JSON.stringify(previous) !== JSON.stringify(entry)) {
          throw new Error(`incompatible ABI type ${entry.name}`);
        }
        types.set(entry.name, entry);
      }
      if (entry.type !== 'interface') continue;
      const functions = entry.items.filter(item => item.type === 'function');
      if (!functions.length) continue;
      interfaces.push(entry);
      for (const fn of functions) {
        if (methods[fn.name]) throw new Error(`duplicate routed method ${fn.name}`);
        methods[fn.name] = { facet, view: fn.state_mutability === 'view' };
      }
    }
  }
  if (Object.keys(methods).length !== 79) {
    throw new Error(`expected 79 routed methods, found ${Object.keys(methods).length}`);
  }
  return { version: 1, facetNames: facets.map(name => `Game${name}Facet`), methods, abi: [...types.values(), ...interfaces] };
}

if (process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href) {
  const output = process.argv[2] ?? 'integrations/routed-game-manifest.json';
  const manifest = routedGameManifest();
  writeFileSync(output, `${JSON.stringify(manifest, null, 2)}\n`);
  console.log(`Wrote ${Object.keys(manifest.methods).length} routed methods to ${output}`);
}
