// Disposable synthetic integration test. Never accepts an existing data path.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createHash, randomBytes } from "node:crypto";
import { spawnSync } from "node:child_process";
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";

const image = process.argv[2] || "supermemory-postgres:test";
const release = JSON.parse(
  fs.readFileSync(new URL("./release.json", import.meta.url)),
);
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "factory-image-smoke-"));
const suffix = randomBytes(6).toString("hex"),
  app = `factory-image-app-${suffix}`,
  db = `factory-image-db-${suffix}`,
  network = `factory-image-${suffix}`,
  extractor = `factory-image-files-${suffix}`;
fs.chmodSync(dir, 0o700);
let started = false;
function docker(args, { input, allowFailure = false } = {}) {
  const result = spawnSync("docker", args, {
    encoding: "utf8",
    input,
    maxBuffer: 8 * 1024 * 1024,
  });
  if (result.status !== 0 && !allowFailure) {
    fs.appendFileSync(
      path.join(dir, "diagnostics-private.log"),
      result.stderr || result.stdout || "Docker failed",
      { mode: 0o600 },
    );
    throw new Error(`Docker ${args[0]} failed; diagnostics kept private`);
  }
  return result;
}
function info(name) {
  return JSON.parse(docker(["inspect", name]).stdout)[0];
}
async function waitUntil(fn, label, ms = 300000) {
  const deadline = Date.now() + ms;
  while (Date.now() < deadline) {
    if (await fn()) return;
    await Bun.sleep(500);
  }
  throw new Error(`Timed out: ${label}`);
}
function address() {
  return (
    "http://127.0.0.1:" +
    info(app).NetworkSettings.Ports["6767/tcp"][0].HostPort
  );
}
async function api(key, method, route, body, host) {
  const response = await fetch(address() + route, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(key ? { Authorization: `Bearer ${key}` } : {}),
      ...(host ? { Host: host } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
    signal: AbortSignal.timeout(10000),
  });
  const data = await response.json().catch(() => null);
  return { status: response.status, data };
}
function sql(text) {
  const result = docker(
    [
      "exec",
      "-i",
      db,
      "psql",
      "-X",
      "-v",
      "ON_ERROR_STOP=1",
      "-U",
      "postgres",
      "-d",
      "supermemory",
      "-At",
    ],
    { input: text },
  );
  return result.stdout.trim();
}
try {
  assert(
    docker(["run", "--rm", image, "--version"]).stdout.includes(
      release.version,
    ),
  );
  assert.notEqual(
    docker(["run", "--rm", image], { allowFailure: true }).status,
    0,
    "Missing connection must be refused",
  );
  const appData = path.join(dir, "data");
  fs.mkdirSync(path.join(appData, "store"), { recursive: true });
  docker(["create", "--name", extractor, image]);
  docker(["cp", `${extractor}:/opt/factory`, path.join(dir, "factory")]);
  docker(["rm", "--volumes", extractor]);
  const { storeKey } = await import(
    pathToFileURL(path.join(dir, "factory/postgres/keys.mjs")).href
  );
  fs.writeFileSync(
    path.join(appData, "store/machine-key"),
    "persist:" + randomBytes(24).toString("hex"),
    { mode: 0o600 },
  );
  const identity = createHash("sha256")
    .update(storeKey(path.join(appData, "store"), "factory-postgres-v1"))
    .digest("hex");
  const adminPassword = randomBytes(32).toString("hex"),
    appPassword = randomBytes(32).toString("hex");
  fs.writeFileSync(path.join(dir, "password"), adminPassword, { mode: 0o600 });
  const url = new URL(`postgresql://supermemory_app@${db}:5432/supermemory`);
  url.password = appPassword;
  fs.writeFileSync(path.join(appData, "store/postgres-url"), url.toString(), {
    mode: 0o600,
  });
  docker(["network", "create", network]);
  docker([
    "run",
    "-d",
    "--name",
    db,
    "--network",
    network,
    "--memory",
    "1g",
    "--shm-size",
    "256m",
    "--restart=no",
    "-v",
    `${dir}/password:/run/secrets/pg-password:ro`,
    "-e",
    "POSTGRES_PASSWORD_FILE=/run/secrets/pg-password",
    "-e",
    "POSTGRES_DB=supermemory",
    release.postgresImage,
    "-c",
    "log_min_error_statement=panic",
  ]);
  await waitUntil(
    () =>
      docker(
        ["exec", db, "pg_isready", "-q", "-h", "127.0.0.1", "-U", "postgres"],
        {
          allowFailure: true,
        },
      ).status === 0,
    "PostgreSQL readiness",
    60000,
  );
  // Synthetic bootstrap marker only: production still requires verified migration.
  // Native upstream migrations create the actual application schema during boot.
  sql(
    `CREATE EXTENSION vector; CREATE SCHEMA drizzle; CREATE TABLE drizzle.__factory_postgres_binding(singleton boolean PRIMARY KEY CHECK(singleton),identity text NOT NULL,format text NOT NULL,source_fingerprints jsonb NOT NULL,completed_at timestamptz NOT NULL DEFAULT now()); INSERT INTO drizzle.__factory_postgres_binding(singleton,identity,format,source_fingerprints) VALUES(true,'${identity}','factory-supermemory-postgres-v1','{}'); CREATE ROLE supermemory_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD '${appPassword}'; ALTER DATABASE supermemory OWNER TO supermemory_app; ALTER SCHEMA public OWNER TO supermemory_app; ALTER SCHEMA drizzle OWNER TO supermemory_app; ALTER TABLE drizzle.__factory_postgres_binding OWNER TO supermemory_app;`,
  );
  docker([
    "run",
    "-d",
    "--name",
    app,
    "--network",
    network,
    "--init",
    "--stop-timeout",
    "120",
    "--restart=no",
    "--memory",
    "3g",
    "--cpus",
    "2",
    "-p",
    "127.0.0.1::6767",
    "-v",
    `${appData}:/data`,
    "-e",
    "OPENAI_API_KEY=synthetic-image-test",
    "-e",
    "SUPERMEMORY_DISABLE_BROWSER=1",
    "-e",
    "SUPERMEMORY_EMBEDDING_RAM_LIMIT=2gb",
    image,
  ]);
  started = true;
  await waitUntil(() => {
    const state = info(app).State;
    if (!state.Running) throw new Error("Candidate exited before readiness");
    return state.Health?.Status === "healthy";
  }, "application readiness");
  const key = docker(["exec", app, "cat", "/data/store/api-key"]).stdout.trim();
  assert.equal((await api(null, "GET", "/v3/session")).status, 401);
  assert.equal(
    (await api(null, "GET", "/v3/session", undefined, "localhost")).status,
    401,
  );
  assert.equal((await api(key, "GET", "/v3/session")).status, 200);
  assert.equal(
    (await api(key, "POST", "/v3/documents/list", { page: 1, limit: 1 }))
      .status,
    200,
  );
  assert.equal(sql("SELECT count(*) FROM public.document;"), "0");
  assert.equal(
    sql("SELECT rolsuper FROM pg_roles WHERE rolname='supermemory_app';"),
    "f",
  );
  docker([
    "exec",
    app,
    "sh",
    "-c",
    "test ! -e /data/store/pages.sqlite && test ! -e /data/store/data",
  ]);
  const installed = docker([
    "exec",
    app,
    "sh",
    "-c",
    "find /data/postgres/releases -name supermemory-server-0.0.8-postgres -exec sha256sum '{}' ';'",
  ]).stdout.trim();
  assert(installed.startsWith(release.patchedSha256));
  sql(
    "CREATE TABLE public.factory_image_probe(value int PRIMARY KEY); INSERT INTO public.factory_image_probe VALUES(42);",
  );
  docker(["stop", "-t", "120", app]);
  docker(["restart", db]);
  await waitUntil(
    () =>
      docker(
        ["exec", db, "pg_isready", "-q", "-h", "127.0.0.1", "-U", "postgres"],
        {
          allowFailure: true,
        },
      ).status === 0,
    "database restart",
    60000,
  );
  docker(["start", app]);
  await waitUntil(
    () => info(app).State.Health?.Status === "healthy",
    "application restart",
  );
  assert.equal(sql("SELECT value FROM public.factory_image_probe;"), "42");
  assert.equal(
    docker(["exec", app, "cat", "/data/store/api-key"]).stdout.trim(),
    key,
  );
  assert.equal((await api(key, "GET", "/v3/session")).status, 200);
  const reused = docker([
    "exec",
    app,
    "sh",
    "-c",
    "find /data/postgres/releases -name supermemory-server-0.0.8-postgres -exec sha256sum '{}' ';'",
  ]).stdout.trim();
  assert.equal(reused, installed);
  console.log(
    JSON.stringify({
      release: release.version,
      imageStartup: true,
      upstreamDownloadAndPatchVerified: true,
      nativePostgres: true,
      nonSuperuser: true,
      hostGuard: true,
      restartPersistence: true,
      bundleReused: true,
    }),
  );
} catch (error) {
  if (started) {
    const log = docker(["logs", app], { allowFailure: true });
    fs.writeFileSync(
      path.join(dir, "app-private.log"),
      log.stdout + log.stderr,
      { mode: 0o600 },
    );
  }
  console.error(error.message.split("\n")[0]);
  console.error("Private diagnostic directory: " + dir);
  process.exitCode = 1;
} finally {
  docker(["rm", "-f", "-v", app, db, extractor], { allowFailure: true });
  docker(["network", "rm", network], { allowFailure: true });
  // Restore ownership only within the private directory this process created.
  docker(
    [
      "run",
      "--rm",
      "--network=none",
      "--entrypoint",
      "sh",
      "-v",
      `${dir}:/fixture`,
      image,
      "-c",
      `chown -R ${process.getuid()}:${process.getgid()} /fixture`,
    ],
    { allowFailure: true },
  );
  if (!process.exitCode) fs.rmSync(dir, { recursive: true, force: true });
}
