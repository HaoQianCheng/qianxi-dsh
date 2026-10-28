import assert from "node:assert/strict";
import { test } from "node:test";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, chmodSync, readdirSync } from "node:fs";
import { join, delimiter } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";

const cli = process.env.QIANXI_TEST_CLI || fileURLToPath(new URL("../bin/qianxi-dsh.mjs", import.meta.url));
const invoke = (args, env = {}) => spawnSync(process.execPath, [cli, ...args], {
  encoding: "utf8", timeout: 30000, env: { ...process.env, DSH_HOME: "", DSH_PROFILE: "", ...env },
});

test("install, update and uninstall preserve unrelated profiles and shared files", { timeout: 60000 }, () => {
  const workspace = mkdtempSync(join(tmpdir(), "qianxi-install-"));
  const home = join(workspace, "DSH user's home");
  const fakeBin = join(workspace, "fake-bin");
  mkdirSync(fakeBin, { recursive: true });
  // Only the package-manager boundary is stubbed; file copies, registration,
  // migration, links, backup and removal run through the real installers.
  const pnpm = join(fakeBin, process.platform === "win32" ? "pnpm.cmd" : "pnpm");
  writeFileSync(pnpm, process.platform === "win32"
    ? '@echo off\r\nif "%~1"=="--version" echo 10.0.0\r\nexit /b 0\r\n'
    : '#!/bin/sh\nif [ "$1" = "--version" ]; then echo 10.0.0; fi\nexit 0\n');
  chmodSync(pnpm, 0o755);
  const env = {
    PATH: fakeBin + delimiter + process.env.PATH,
    LOCALAPPDATA: join(workspace, "local-app-data"), APPDATA: join(workspace, "app-data"),
    USERPROFILE: workspace, HOME: workspace, DSH_BASE: "",
  };
  const pkgPath = (name) => join(home, "profiles", name, "package.json");
  for (const name of ["web", "custom"]) {
    mkdirSync(join(home, "profiles", name), { recursive: true });
    writeFileSync(pkgPath(name), JSON.stringify({ name: `fixture-${name}`, private: true, dependencies: {}, dsh: { profile: { bundles: ["keep-this-bundle"] } } }));
    writeFileSync(join(home, "profiles", name, "cordis.patch.yml"), "- id: unrelated-plugin\n  config:\n    enabled: true\n");
  }
  const readPkg = (name) => JSON.parse(readFileSync(pkgPath(name), "utf8"));
  const unrelatedBefore = readFileSync(pkgPath("custom"), "utf8");
  const customPatch = join(home, "profiles", "custom", "cordis.patch.yml");
  const patchBefore = readFileSync(customPatch, "utf8");
  const run = (command, profile) => {
    const result = invoke([command, "--home", home, "--profile", profile], env);
    assert.equal(result.status, 0, result.stdout + result.stderr);
  };
  run("install", "web");
  run("install", "web");
  const backups = readdirSync(join(home, "profiles", "web"));
  assert.ok(backups.some((name) => name.startsWith("package.json.bak-")));
  assert.ok(backups.some((name) => name.startsWith("cordis.patch.yml.bak-")));
  assert.equal(readPkg("web").dependencies["fujiang-armor"], "file:../../plugins/fujiang-armor");
  assert.deepEqual(readPkg("web").dsh.profile.bundles, ["keep-this-bundle"]);
  assert.equal(readFileSync(pkgPath("custom"), "utf8"), unrelatedBefore);
  assert.equal(readFileSync(customPatch, "utf8"), patchBefore);
  const installed = join(home, "plugins", "fujiang-armor");
  for (const file of ["index.js", "client.js", "LICENSE", "scripts/install/uninstall.ps1", "bin/qianxi-dsh.mjs"]) {
    assert.equal(existsSync(join(installed, file)), true, file);
  }
  assert.equal(existsSync(join(installed, ".git")), false);
  assert.equal(existsSync(join(installed, "tests")), false);
  run("install", "custom");
  run("uninstall", "web");
  assert.equal(readPkg("web").dependencies["fujiang-armor"], undefined);
  assert.equal(existsSync(installed), true, "custom still uses the shared plugin");
  run("uninstall", "custom");
  assert.equal(existsSync(installed), false);
  assert.match(readFileSync(customPatch, "utf8"), /unrelated-plugin/);
  assert.doesNotMatch(readFileSync(customPatch, "utf8"), /id: fujiang-armor/);
});

test("CLI help, version and invalid input do not start installation", () => {
  assert.match(invoke(["--help"]).stdout, /install\|uninstall/);
  assert.equal(invoke(["--version"]).stdout.trim(), "0.4.3");
  for (const args of [["unknown"], ["install", "--home"], ["install", "--profile", "../default"], ["install", "--unknown"]]) {
    assert.equal(invoke(args).status, 1, JSON.stringify(args));
  }
});

test("dry run preserves spaces and selects install/uninstall without shell interpolation", () => {
  const home = join(tmpdir(), "qianxi test ' home");
  for (const command of ["install", "uninstall"]) {
    const result = invoke([command, "--home", home, "--profile", "custom", "--dry-run"]);
    assert.equal(result.status, 0, result.stderr);
    const plan = JSON.parse(result.stdout);
    assert.equal(plan.home, home);
    assert.equal(plan.profile, "custom");
    assert.ok(plan.args.some((arg) => arg.endsWith(`${command}.${process.platform === "win32" ? "ps1" : "sh"}`)));
  }
});

test("missing explicit profile fails before modifying another profile", () => {
  const home = mkdtempSync(join(tmpdir(), "qianxi-missing-profile-"));
  mkdirSync(join(home, "profiles", "web"), { recursive: true });
  const pkgPath = join(home, "profiles", "web", "package.json");
  const bytes = '{"name":"fixture","private":true}\n';
  writeFileSync(pkgPath, bytes);
  for (const command of ["install", "uninstall"]) {
    const result = invoke([command, "--home", home, "--profile", "missing"]);
    assert.equal(result.status, 1, result.stdout + result.stderr);
    assert.match(result.stdout + result.stderr, /missing/);
    assert.doesNotMatch(result.stdout + result.stderr, /ParserError/);
    assert.equal(readFileSync(pkgPath, "utf8"), bytes);
    assert.equal(existsSync(join(home, "plugins")), false);
  }
});
