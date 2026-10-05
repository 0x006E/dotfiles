#!/usr/bin/env node
// QMP driver for the guest-desktop test VM: the greeter-path and desktop audit
// are driven from here (keyboard, mouse, raw QMP) so the whole test pass runs
// unattended. Pairs with spicy-screenshot for frames and vm-qga.mjs for guest
// command execution; this file deliberately does neither.
//
// Usage:
//   node qmp.mjs commands [filter]   list QMP command names (filter = substring)
//   node qmp.mjs devices             list input devices + their axes
//   node qmp.mjs key QCODE [tap|down|up]     default: tap (down+up)
//   node qmp.mjs type "text"         types a string (shift for A-Z, !, …)
//   node qmp.mjs move X Y            absolute pointer move, screen fractions 0..1
//   node qmp.mjs rel DX DY           relative pointer move
//   node qmp.mjs btn left|right|middle [down|up|tap]
//   node qmp.mjs click X Y [left|right|middle]   move + tap
//   node qmp.mjs cmd '{"execute":"…"}'          raw QMP (escape hatch: device_add…)
//
// Exit codes: 0 ok, 1 QMP error (printed on stderr), 2 usage/transport.
//
// Why this exists: the audit needs real input injection at the QEMU level --
// the guest has no remote-input agent, and driving the SPICE client by hand
// would put a human back in the loop. QMP's input-send-event is the one
// supported path for scripted keyboard/mouse on this machine (the GL console
// rules out VNC; see vm-up.sh's header for that story).
import net from 'node:net';

const SOCK = process.env.QMP_SOCKET ?? '/tmp/guest-desktop-qmp.sock';

// One QMP conversation: greeting, capabilities, then request/response pairs.
// Async events (STOP, SHUTDOWN, …) are skipped; responses are matched by id.
function qmpSession() {
  return new Promise((resolve, reject) => {
    const sock = net.connect(SOCK);
    let buf = '';
    let wantGreeting = true;
    const pending = new Map();
    let nextId = 1;

    sock.on('error', (e) => {
      for (const rej of pending.values()) rej(e);
      pending.clear();
      reject(e);
    });
    sock.on('data', (chunk) => {
      buf += chunk.toString('utf8');
      let nl;
      while ((nl = buf.indexOf('\n')) >= 0) {
        const line = buf.slice(0, nl).trim();
        buf = buf.slice(nl + 1);
        if (!line) continue;
        let msg;
        try {
          msg = JSON.parse(line);
        } catch {
          continue; // partial/non-JSON noise never happens on QMP, but be safe
        }
        if (wantGreeting) {
          wantGreeting = false;
          const greet = { execute: 'qmp_capabilities' };
          sock.write(JSON.stringify(greet) + '\n');
          continue;
        }
        if (msg.event !== undefined) continue; // async notification
        const id = String(msg.id);
        const entry = pending.get(id);
        if (!entry) continue;
        pending.delete(id);
        if (msg.error) {
          entry.reject(
            Object.assign(new Error(msg.error.desc), { qmp: msg.error }),
          );
        } else {
          entry.resolve(msg.return);
        }
      }
    });

    const session = {
      execute(cmd, args) {
        const id = String(nextId++);
        const req = { execute: cmd, id };
        if (args !== undefined) req.arguments = args;
        return new Promise((res, rej) => {
          pending.set(id, { resolve: res, reject: rej });
          sock.write(JSON.stringify(req) + '\n');
        });
      },
      close() {
        sock.end();
      },
    };
    // The capability exchange completes with the first non-event message.
    const origWrite = sock.write.bind(sock);
    sock.write = (data) => origWrite(data);
    resolve(
      new Promise((res, rej) => {
        const onMsg = () => {};
        const iv = setInterval(() => {
          if (!wantGreeting) {
            clearInterval(iv);
            res(session);
          }
        }, 5);
        sock.once('error', rej);
      }),
    );
  });
}

// Tap = one event pair in a single input-send-event, so QEMU never sees the
// key half-pressed across a write boundary.
function keyEvent(qcode, mode) {
  const ev = { type: 'key', data: { down: true, key: { type: 'qcode', data: qcode } } };
  if (mode === 'down') return [ev];
  const up = { type: 'key', data: { down: false, key: { type: 'qcode', data: qcode } } };
  return mode === 'up' ? [up] : [ev, up];
}

// Passwords and app-search strings are typed literally; shift is synthesized
// for uppercase and the punctuation that needs it. QEMU wants qcodes, not
// characters, so every char maps to a qcode (+ shift flag).
const SHIFTABLE = new Set('!@#$%^&*()_+{}|:"<>?~');
function charToQcode(ch) {
  if (ch >= 'a' && ch <= 'z') return [ch, false];
  if (ch >= 'A' && ch <= 'Z') return [ch.toLowerCase(), true];
  if (ch >= '0' && ch <= '9') return [ch, false];
  const punct = {
    ' ': ['spc', false],
    '\n': ['ret', false],
    '\t': ['tab', false],
    '-': ['minus', false],
    '=': ['equal', false],
    '[': ['bracket_left', false],
    ']': ['bracket_right', false],
    '\\': ['backslash', false],
    ';': ['semicolon', false],
    "'": ['apostrophe', false],
    ',': ['comma', false],
    '.': ['dot', false],
    '/': ['slash', false],
    '`': ['grave_accent', false],
    '!': ['1', true],
    '@': ['2', true],
    '#': ['3', true],
    '$': ['4', true],
    '%': ['5', true],
    '^': ['6', true],
    '&': ['7', true],
    '*': ['8', true],
    '(': ['9', true],
    ')': ['0', true],
    '_': ['minus', true],
    '+': ['equal', true],
    '{': ['bracket_left', true],
    '}': ['bracket_right', true],
    '|': ['backslash', true],
    ':': ['semicolon', true],
    '"': ['apostrophe', true],
    '<': ['comma', true],
    '>': ['dot', true],
    '?': ['slash', true],
    '~': ['grave_accent', true],
  };
  const hit = punct[ch];
  if (!hit) throw new Error(`no qcode mapping for char ${JSON.stringify(ch)}`);
  if (!hit[1] && SHIFTABLE.has(ch)) throw new Error(`unshifted ${ch}?`);
  return hit;
}

function typeEvents(text) {
  const events = [];
  for (const ch of text) {
    const [qcode, shift] = charToQcode(ch);
    if (shift) events.push(...keyEvent('shift', 'down'));
    events.push(...keyEvent(qcode, 'tap'));
    if (shift) events.push(...keyEvent('shift', 'up'));
  }
  return events;
}

const BTN_AXES = { left: 'btn-left', right: 'btn-right', middle: 'btn-middle' };

async function main() {
  const [cmd, ...rest] = process.argv.slice(2);
  if (!cmd) {
    console.error('usage: qmp.mjs commands|devices|key|type|move|rel|btn|click|cmd …');
    process.exit(2);
  }
  const s = await qmpSession();
  try {
    switch (cmd) {
      case 'commands': {
        const filter = rest[0] ?? '';
        const list = await s.execute('query-commands');
        for (const c of list) {
          if (c.name.includes(filter)) console.log(c.name);
        }
        break;
      }
      case 'devices': {
        const list = await s.execute('query-input-devices');
        console.log(JSON.stringify(list, null, 2));
        break;
      }
      case 'key': {
        const [qcode, mode = 'tap'] = rest;
        if (!qcode) throw new Error('key: missing qcode');
        await s.execute('input-send-event', { events: keyEvent(qcode, mode) });
        console.log(`key ${mode} ${qcode}`);
        break;
      }
      case 'type': {
        const text = rest.join(' ');
        await s.execute('input-send-event', { events: typeEvents(text) });
        console.log(`typed ${JSON.stringify(text)}`);
        break;
      }
      case 'move': {
        // Fractions in; QMP abs axes are integers 0..0x7fff on both axes
        // (documented range, verified against dash-hover tooltips on this
        // 1280x800 screen). This only holds because vm.nix turns vmport off:
        // with the pc machine's fake VMware mouse present, input-send-event
        // (no routing config) broadcasts to every pointer device and the
        // guest blends mismatched coordinate ranges -- moves and clicks land
        // in different places. See vm.nix for that story.
        const [x, y] = rest.map(Number);
        if (Number.isNaN(x) || Number.isNaN(y)) throw new Error('move: X Y fractions');
        const clamp = (v) => Math.round(Math.min(Math.max(v, 0), 1) * 0x7fff);
        await s.execute('input-send-event', {
          events: [
            { type: 'abs', data: { axis: 'x', value: clamp(x) } },
            { type: 'abs', data: { axis: 'y', value: clamp(y) } },
          ],
        });
        console.log(`move ${x} ${y}`);
        break;
      }
      case 'rel': {
        const [dx, dy] = rest.map(Number);
        if (Number.isNaN(dx) || Number.isNaN(dy)) throw new Error('rel: DX DY');
        await s.execute('input-send-event', {
          events: [
            { type: 'rel', data: { axis: 'x', value: dx } },
            { type: 'rel', data: { axis: 'y', value: dy } },
          ],
        });
        console.log(`rel ${dx} ${dy}`);
        break;
      }
      case 'btn': {
        const [which, mode = 'tap'] = rest;
        const axis = BTN_AXES[which];
        if (!axis) throw new Error(`btn: one of ${Object.keys(BTN_AXES)}`);
        const ev = { type: 'btn', data: { button: which, down: true } };
        const events = mode === 'down' ? [ev] : mode === 'up' ? [{ ...ev, data: { button: which, down: false } }] : [ev, { ...ev, data: { button: which, down: false } }];
        await s.execute('input-send-event', { events });
        console.log(`btn ${mode} ${which}`);
        break;
      }
      case 'click': {
        const [x, y, which = 'left'] = rest;
        const axis = BTN_AXES[which];
        if (!axis) throw new Error(`click: one of ${Object.keys(BTN_AXES)}`);
        const fx = Number(x);
        const fy = Number(y);
        if (Number.isNaN(fx) || Number.isNaN(fy)) throw new Error('click: X Y fractions');
        // Same axis encoding as `move` (see there); fractions in. Three steps
        // with gaps: position settles in one QMP call, then press, then
        // release. Batching abs+press in one call works only sometimes -- the
        // press is judged against the pointer's previous position -- and a
        // batched press+release is delivered in one frame and dropped whole
        // (the dash hover worked, the click silently didn't). Slow beats
        // clever: every audit click lands on the intended widget this way.
        const clamp = (v) => Math.round(Math.min(Math.max(v, 0), 1) * 0x7fff);
        const cx = clamp(fx);
        const cy = clamp(fy);
        const wait = (ms) => new Promise((r) => setTimeout(r, ms));
        await s.execute('input-send-event', {
          events: [
            { type: 'abs', data: { axis: 'x', value: cx } },
            { type: 'abs', data: { axis: 'y', value: cy } },
          ],
        });
        await wait(400);
        await s.execute('input-send-event', {
          events: [{ type: 'btn', data: { button: which, down: true } }],
        });
        await wait(300);
        await s.execute('input-send-event', {
          events: [{ type: 'btn', data: { button: which, down: false } }],
        });
        console.log(`click ${which} @ ${fx},${fy}`);
        break;
      }
      case 'cmd': {
        const req = JSON.parse(rest.join(' '));
        const ret = await s.execute(req.execute, req.arguments);
        console.log(JSON.stringify(ret, null, 2));
        break;
      }
      default:
        console.error(`unknown command: ${cmd}`);
        process.exit(2);
    }
  } catch (e) {
    if (e.qmp) {
      console.error(`QMP error: ${e.message}`);
      console.error(JSON.stringify(e.qmp));
      process.exit(1);
    }
    console.error(String(e.message ?? e));
    process.exit(2);
  } finally {
    s.close();
  }
}

main();
