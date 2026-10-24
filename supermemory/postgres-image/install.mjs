import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { pathToFileURL } from "node:url";

export async function install({
  original,
  launcher,
  source,
  releases,
  release,
}) {
  if (!/^0\.0\.8-ntindle\.[1-9][0-9]*$/.test(release.version))
    throw new Error("Unknown fork release");
  const { buildBundle, verifyBundle } = await import(
    pathToFileURL(path.join(source, "bundle.mjs")).href
  );
  const { pins } = await import(
    pathToFileURL(path.join(source, "patch-binary.mjs")).href
  );
  if (
    pins.originalSha256 !== release.originalSha256 ||
    pins.patchedSha256 !== release.patchedSha256 ||
    pins.launcherSha256 !== release.launcherSha256
  )
    throw new Error("Release and source pins differ");
  const names = [
    "bundle.mjs",
    "patch-binary.mjs",
    "runtime.mjs",
    "ingestion-queue.mjs",
    "workflow-outbox.mjs",
    "pins.json",
    "launch.sh",
  ];
  const hash = createHash("sha256");
  for (const name of names)
    hash.update(name).update(fs.readFileSync(path.join(source, name)));
  const target = path.join(
    releases,
    `${release.version}-${hash.digest("hex").slice(0, 16)}`,
  );
  fs.mkdirSync(releases, { recursive: true, mode: 0o700 });
  if (!fs.existsSync(target)) {
    const staging = fs.mkdtempSync(path.join(releases, ".install-"));
    try {
      buildBundle(original, launcher, path.join(staging, "bundle"));
      fs.renameSync(path.join(staging, "bundle"), target);
    } finally {
      fs.rmSync(staging, { recursive: true, force: true });
    }
  }
  const verified = verifyBundle(target);
  if (verified.testProbe)
    throw new Error("A test initializer cannot be used for a release");
  for (const name of names.filter(
    (name) => !["bundle.mjs", "patch-binary.mjs"].includes(name),
  )) {
    if (
      !fs
        .readFileSync(path.join(source, name))
        .equals(fs.readFileSync(path.join(target, name)))
    )
      throw new Error("Installed runtime differs from the image");
  }
  return target;
}

if (import.meta.main) {
  try {
    const release = JSON.parse(
      fs.readFileSync("/opt/factory/release.json", "utf8"),
    );
    console.log(
      await install({
        original: process.argv[2],
        launcher: "/usr/local/bin/entrypoint.sh",
        source: "/opt/factory/postgres",
        releases: "/data/postgres/releases",
        release,
      }),
    );
  } catch (error) {
    console.error("[factory] Bundle installation failed: " + error.message);
    process.exitCode = 1;
  }
}
