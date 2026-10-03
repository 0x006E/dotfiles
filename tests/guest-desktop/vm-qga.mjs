#!/usr/bin/env node
// Run a command inside the test VM via the QEMU guest agent.
//
// This is what vmg's serial-console path cannot do: run something in the guest
// and get back its stdout, stderr and exit code, without base64-over-a-pty,
// without quoting hell, and without staging scripts over virtiofs.
//
// Output streams while the command runs: each poll prints only what arrived
// since the last one, so a long dnf install is watchable instead of a black
// box until it exits.
//
// Requires the VM booted with the guest-agent channel (vm-up.sh adds the
// virtio-serial port) and services.qemuGuest enabled in the guest (vm.nix).
// The agent starts late in boot; for early-boot debugging the serial console
// (vm-console.py) still owns.
//
// This talks to the agent DIRECTLY over its unix socket, not through QMP:
// the qemu build that run-nixos-vm uses (qemu-host-cpu-only) has no guest-*
// QMP proxy commands compiled in at all (verified: query-commands lists
// none), so QMP routing is impossible. The agent protocol is the same
// JSON framing without the greeting/capabilities handshake.
//
// Usage:
//   vm-qga.mjs [--as USER] [--timeout SECS] [--input-file F]
//              [--transcript PATH] <command> [args...]
//
//   --as USER     run as USER via runuser (guest-exec itself runs as root)
//   --timeout     give up waiting after SECS (default 120); the guest process
//                 keeps running and its pid is printed, so it can be killed
//   --input-file  feed file F to the command's stdin (base64 input-data)
//   --transcript  append a timestamped record (command, stdout, stderr, exit)
//                 to PATH, so a human can follow along in a second window with
//                 `tail -f PATH`
//
// Guest stdout goes to stdout, guest stderr to stderr, and the exit code is
// the guest command's exit code. The `+ <command>` line and the exit note go
// to stderr, so stdout stays pipeable.

import net from "node:net";
import fs from "node:fs";

const QGA = process.env.GUEST_DESKTOP_QGA || "/tmp/guest-desktop-vm/qga.sock";

// Agent session: same JSON framing as QMP, but no greeting banner and no
// qmp_capabilities -- guest-sync is the handshake instead.
function connectAgent(path) {
  return new Promise((resolve, reject) => {
    const sock = net.createConnection(path);
    let buf = "";
    const pending = [];
    sock.on("data", (chunk) => {
      buf += chunk.toString("utf8");
      let idx;
      while ((idx = buf.indexOf("\n")) >= 0) {
        const line = buf.slice(0, idx);
        buf = buf.slice(idx + 1);
        if (!line.trim()) continue;
        let msg;
        try {
          msg = JSON.parse(line);
        } catch {
          continue;
        }
        if ("event" in msg) continue;
        const next = pending.shift();
        if (next) next(msg);
      }
    });
    sock.on("error", reject);
    const cmd = (name, args = {}) =>
      new Promise((res, rej) => {
        pending.push((msg) => {
          if ("error" in msg) rej(new Error(`agent ${name} failed: ${JSON.stringify(msg.error)}`));
          else res(msg.return);
        });
        sock.write(JSON.stringify({ execute: name, arguments: args }) + "\n");
      });
    sock.on("connect", async () => {
      try {
        const id = Math.floor(Math.random() * 1e9);
        const echo = await cmd("guest-sync", { id });
        if (echo !== id) throw new Error("guest-sync mismatch");
        resolve({ cmd, close: () => sock.end() });
      } catch (e) {
        reject(e);
      }
    });
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const rest = [...process.argv.slice(2)];
  const opts = { asUser: null, timeout: 120, inputFile: null, transcript: null };
  while (rest.length && rest[0].startsWith("--")) {
    const opt = rest.shift();
    if (opt === "--as") opts.asUser = rest.shift();
    else if (opt === "--timeout") opts.timeout = parseInt(rest.shift(), 10);
    else if (opt === "--input-file") opts.inputFile = rest.shift();
    else if (opt === "--transcript") opts.transcript = rest.shift();
    else throw new Error(`unknown option ${opt}`);
  }
  if (!rest.length) {
    throw new Error(
      "usage: vm-qga.mjs [--as USER] [--timeout SECS] [--input-file F] [--transcript PATH] <command> [args...]"
    );
  }

  let argv = rest;
  // Absolute path: the agent does no PATH lookup at all. This one is
  // NixOS-specific, which is fine -- the only guest this ever talks to is.
  if (opts.asUser) argv = ["/run/current-system/sw/bin/runuser", "-u", opts.asUser, "--", ...rest];

  const execArgs = { path: argv[0], "capture-output": true };
  if (argv.length > 1) execArgs.arg = argv.slice(1);
  if (opts.inputFile) {
    execArgs["input-data"] = fs.readFileSync(opts.inputFile).toString("base64");
  }

  console.error(`+ ${argv.join(" ")}`);

  const qga = await connectAgent(QGA);
  const { pid } = await qga.cmd("guest-exec", execArgs);

  // out-data/err-data are cumulative: the last poll holds the whole streams,
  // which is also what the transcript records. Sliced after decoding, so a
  // multibyte character split across two polls still renders whole.
  let shownOut = 0;
  let shownErr = 0;
  let out = "";
  let err = "";
  let exitcode = null;

  const deadline = Date.now() + opts.timeout * 1000;
  for (;;) {
    const status = await qga.cmd("guest-exec-status", { pid });
    out = Buffer.from(status["out-data"] || "", "base64").toString("utf8");
    err = Buffer.from(status["err-data"] || "", "base64").toString("utf8");
    if (out.length > shownOut) {
      process.stdout.write(out.slice(shownOut));
      shownOut = out.length;
    }
    if (err.length > shownErr) {
      process.stderr.write(err.slice(shownErr));
      shownErr = err.length;
    }
    if (status.exited) {
      exitcode = status.exitcode ?? 1;
      if (status["out-truncated"] || status["err-truncated"]) {
        console.error("(output truncated by the agent)");
      }
      break;
    }
    if (Date.now() > deadline) {
      console.error(`timed out after ${opts.timeout}s; guest pid ${pid} still running`);
      exitcode = 124;
      break;
    }
    await sleep(500);
  }
  qga.close();

  if (opts.transcript) {
    fs.appendFileSync(
      opts.transcript,
      `=== ${new Date().toISOString()}\n$ ${argv.join(" ")}\n` +
        `--- stdout ---\n${out}\n--- stderr ---\n${err}\n--- exit: ${exitcode} ---\n\n`
    );
  }

  console.error(`(exit ${exitcode})`);
  process.exit(exitcode);
}

main().catch((e) => {
  console.error(String(e?.message || e));
  process.exit(1);
});
