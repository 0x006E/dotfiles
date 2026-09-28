#!/usr/bin/env python3
"""Give the test VM's serial console a pty the host can talk to.

The QEMU runner execs qemu with -nographic, so the guest's serial port *is*
qemu's stdin/stdout. Redirecting that to a file gives a boot log but no way to
answer a prompt, and a guest session is not something you debug by squinting at
VGA screenshots.

So: run qemu on the far side of a pty, keep the master side here.

  vm-console.py serve --log FILE --port N -- command...   # wraps qemu
  vm-console.py --port N --send 'text\\n'                 # type at the guest
  vm-console.py --port N --watch                         # follow the console
"""

import argparse
import os
import pty
import select
import signal
import socket
import sys
import threading
import time

PORT = 6010


def serve(args):
    primary, secondary = pty.openpty()
    name = os.ttyname(secondary)

    pid = os.fork()
    if pid == 0:
        os.setsid()
        # The pty has to be the child's controlling terminal, or agetty will
        # not treat it as a console and the login prompt never appears.
        import fcntl
        import termios

        fcntl.ioctl(secondary, termios.TIOCSCTTY, 0)
        os.dup2(secondary, 0)
        os.dup2(secondary, 1)
        os.dup2(secondary, 2)
        if secondary > 2:
            os.close(secondary)
        os.close(primary)
        os.environ["TERM"] = "linux"
        os.execvp(args.command[0], args.command)
        os._exit(127)

    os.close(secondary)

    log = open(args.log, "ab", buffering=0)
    clients = []
    lock = threading.Lock()

    def pump():
        while True:
            try:
                data = os.read(primary, 65536)
            except OSError:
                break
            if not data:
                break
            log.write(data)
            with lock:
                for c in list(clients):
                    try:
                        c.sendall(data)
                    except OSError:
                        clients.remove(c)

    threading.Thread(target=pump, daemon=True).start()

    server = socket.socket()
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", args.port))
    server.listen(4)
    print(f"console pty {name}, host port {args.port}, log {args.log}", file=sys.stderr)

    def forward():
        while True:
            try:
                conn, _ = server.accept()
            except OSError:
                return
            with lock:
                clients.append(conn)

            # Anything a client sends is typing at the guest's serial console,
            # i.e. bytes into the pty master.
            def typing(c):
                while True:
                    try:
                        data = c.recv(4096)
                    except OSError:
                        data = b""
                    if not data:
                        with lock:
                            if c in clients:
                                clients.remove(c)
                        return
                    os.write(primary, data)

            threading.Thread(target=typing, args=(conn,), daemon=True).start()

    threading.Thread(target=forward, daemon=True).start()

    def reap(*_):
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        os._exit(0)

    signal.signal(signal.SIGTERM, reap)
    signal.signal(signal.SIGINT, reap)

    while True:
        try:
            done, _ = os.waitpid(pid, os.WNOHANG)
        except ChildProcessError:
            break
        if done == pid:
            break
        time.sleep(0.2)
    time.sleep(0.3)
    os._exit(0)


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="mode", required=True)
    p = sub.add_parser("serve")
    p.add_argument("--log", default="/tmp/guest-box-vm.log")
    p.add_argument("--port", type=int, default=PORT)
    p.add_argument("command", nargs=argparse.REMAINDER)

    c = sub.add_parser("console")
    c.add_argument("--port", type=int, default=PORT)
    c.add_argument("--send")
    c.add_argument("--watch", action="store_true")

    args = parser.parse_args()
    if args.mode == "serve":
        if args.command and args.command[0] == "--":
            args.command = args.command[1:]
        serve(args)
        return

    if args.send is not None:
        s = socket.create_connection(("127.0.0.1", args.port), timeout=5)
        # A send submits a line, full stop. The guest's console is a real
        # terminal with a line editor: text without a trailing newline is typed
        # but never executed, and then it merges with whatever is sent next.
        # Every forgotten Enter so far has been this exact bug.
        payload = args.send.encode().decode("unicode_escape")
        if not payload.endswith("\n"):
            payload += "\n"
        s.sendall(payload.encode())
        time.sleep(0.4)
        s.close()
        return

    if args.watch:
        s = socket.create_connection(("127.0.0.1", args.port), timeout=5)
        s.settimeout(None)
        while True:
            try:
                data = s.recv(65536)
            except OSError:
                return
            if not data:
                return
            sys.stdout.write(data.decode("utf-8", "replace"))
            sys.stdout.flush()


if __name__ == "__main__":
    main()
