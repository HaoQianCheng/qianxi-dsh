import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const directory = mkdtempSync(join(tmpdir(), "qianxi-package-"));
assert.ok(process.env.npm_execpath, "Run through npm run verify:package");
const npm = (args) => {
  const result = spawnSync(process.execPath, [process.env.npm_execpath, ...args], {
    cwd: root, encoding: "utf8", timeout: 60000,
  });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  return result.stdout;
};
const [pack] = JSON.parse(npm(["pack", "--json", "--pack-destination", directory]));
const paths = pack.files.map((file) => file.path);
for (const required of ["bin/qianxi-dsh.mjs", "scripts/ensure-runtime.ps1", "scripts/install/install.ps1", "scripts/install/uninstall.sh", "LICENSE", "prompts/fujiang.md"]) {
  assert.ok(paths.includes(required), required);
}
assert.ok(!paths.some((path) => /^(tests|\.git|\.github)\//.test(path)));
const archive = join(directory, pack.filename);
const run = (args) => npm(["exec", "--offline", "--yes", `--package=${archive}`, "--", "qianxi-dsh", ...args]);
assert.match(run(["--help"]), /qianxi-dsh/);
const plan = JSON.parse(run(["install", "--dry-run"]));
const script = plan.args.find((arg) => /install\.(ps1|sh)$/.test(arg));
const cli = join(dirname(dirname(dirname(script))), "bin", "qianxi-dsh.mjs");
const verification = spawnSync(process.execPath, ["--test", "tests/cli.test.mjs"], {
  cwd: root, encoding: "utf8", timeout: 60000,
  env: { ...process.env, QIANXI_TEST_CLI: cli },
});
process.stdout.write(verification.stdout);
process.stderr.write(verification.stderr);
assert.equal(verification.status, 0, "Packaged CLI integration failed");
console.log(`Package smoke check passed: ${pack.entryCount} files, ${pack.size} bytes.`);
