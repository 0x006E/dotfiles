#!/usr/bin/env node
// Talk to the test VM's QMP socket: screenshots and keyboard, in node.
//
// Why this exists when vm-shot.sh already does the same thing: vm-shot.sh is
// python3, and the agent here has no python3. The harness being unusable from
// the agent is not a neutral detail -- it is why an entire class of test (drive
// the greeter, log in, read the result) went unexecuted for the whole life of
// this feature. A test harness you cannot run is not a test.
//
//   vm-key.mjs shot out.png            screendump to out.png
//   vm-key.mjs keys g,u,e,s,t          type literal characters
//   vm-key.mjs text 'hello'            type a string (uppercase handled)
//   vm-key.mjs key ctrl-alt-f3         one chord
//   vm-key.mjs key ret                 a single named key
//
// QMP screendump only writes ppm, which is what vm-shot.sh relies on too.

import net from "node:net";
import fs from "node:fs";
import { spawnSync } from "node:child_process";

const SOCK = process.env.QMP_SOCK ?? "/tmp/guest-desktop-qmp.sock";

// QMP key names for characters that are not a single letter/digit.
const NAMED = { " ": "spc", "\n": "ret", "\t": "tab" };

function charsFor(text) {
  const keys = [];
  for (const ch of text) {
    if (NAMED[ch]) {
      keys.push(NAMED[ch]);
    } else if (/[a-z0-9]/.test(ch)) {
      keys.push(ch);
    } else if (/[A-Z]/.test(ch)) {
      keys.push("shift", ch.toLowerCase());
    } else {
      // Punctuation that QMP spells differently; anything unmapped is passed
      // through and QEMU will reject it loudly rather than silently drop it.
      keys.push(
        {
          "-": "minus", "=": "equal", "[": "bracket_left",
          "]": "bracket_right", ".": "dot", ",": "comma", "/": "slash",
        }[ch] ?? ch
      );
    }
  }
  return keys;
}

class Qmp {
  constructor() {
    this.buf = "";
    this.waiters = [];
  }
  connect() {
    return new Promise((resolve, reject) => {
      this.sock = net.createConnection(SOCK);
      this.sock.once("error", reject);
      this.sock.once("connect", resolve);
      this.sock.on("data", (d) => {
        this.buf += d.toString();
        let i;
        while ((i = this.buf.indexOf("\n")) >= 0) {
          const line = this.buf.slice(0, i);
          this.buf = this.buf.slice(i + 1);
          if (!line.trim()) continue;
          const w = this.waiters.shift();
          if (w) w(line);
        }
      });
    });
  }
  recv() {
    return new Promise((resolve) => this.waiters.push(resolve));
  }
  async send(obj) {
    this.sock.write(JSON.stringify(obj) + "\r\n");
    for (;;) {
      const raw = await this.recv();
      const msg = JSON.parse(raw);
      if (msg.event) continue; // ignore async events
      if (msg.error) throw new Error(`${obj.execute}: ${msg.error.desc}`);
      return msg.return;
    }
  }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function press(q, keys) {
  // One key at a time rather than a single list: a chord list is atomic, and
  // text typed atomically would arrive in one X event, which greeters
  // (tuigreet reads keys, not pastes) do not handle.
  for (const k of Array.isArray(keys) ? keys : [keys]) {
    await q.send({ execute: "sendkey", arguments: { keys: [k] } });
    await sleep(60);
  }
}

async function main() {
  const argv = process.argv.slice(2);
  const cmd = argv[0];
  const q = new Qmp();
  await q.connect();
  await q.recv(); // greeting
  await q.send({ execute: "qmp_capabilities" });

  if (cmd === "shot") {
    const out = argv[1] ?? "screenshot.png";
    const ppm = out.replace(/\.png$/, "") + ".ppm";
    await q.send({ execute: "screendump", arguments: { filename: ppm } });
    // QMP returns before the file is fully written.
    for (let i = 0; i < 50 && !fs.existsSync(ppm); i++) await sleep(100);
    await sleep(300);
    const r = spawnSync("magick", [ppm, out], { encoding: "utf8" });
    if (r.status !== 0) {
      const r2 = spawnSync("convert", [ppm, out], { encoding: "utf8" });
      if (r2.status !== 0) {
        console.error(`no ppm->png converter (tried magick, convert); ppm kept at ${ppm}`);
        process.exit(3);
      }
    }
    console.log(ppm.replace(/\.ppm$/, ".png"));
  } else if (cmd === "keys") {
    await press(q, argv.slice(1));
  } else if (cmd === "text") {
    await press(q, charsFor(argv[1] ?? ""));
  } else if (cmd === "key") {
    await press(q, argv.slice(1).flatMap((a) => a.split("-")));
  } else {
    console.error(
      "usage: vm-key.mjs shot out.png | keys k... | text 'str' | key chord"
    );
    process.exit(2);
  }
  q.sock.end();
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});