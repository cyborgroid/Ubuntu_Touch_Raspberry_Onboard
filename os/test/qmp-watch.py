#!/usr/bin/env python3
"""Follows the test VM's serial log and takes a QMP screenshot at each @@SHOT marker."""
import json
import socket
import sys
import time

qmp_path, log_path, out_dir, timeout = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])


def connect():
    for _ in range(60):
        try:
            s = socket.socket(socket.AF_UNIX)
            s.connect(qmp_path)
            return s.makefile("rw")
        except OSError:
            time.sleep(1)
    raise SystemExit("QMP socket never appeared")


qmp = connect()
qmp.readline()


def command(name, **args):
    qmp.write(json.dumps({"execute": name, "arguments": args}) + "\n")
    qmp.flush()
    while True:
        reply = json.loads(qmp.readline())
        if "return" in reply or "error" in reply:
            return reply


command("qmp_capabilities")
deadline = time.time() + timeout
offset = 0
partial = ""
while time.time() < deadline:
    with open(log_path, errors="replace") as f:
        f.seek(offset)
        chunk = f.read()
        offset = f.tell()
    lines = (partial + chunk).split("\n")
    partial = lines.pop()
    for line in lines:
        line = line.strip()
        if line.startswith("@@SHOT "):
            name = line.split()[1]
            print("screenshot:", name, command("screendump", filename=f"{out_dir}/{name}.ppm"), flush=True)
        elif line == "@@DONE":
            print("probe finished", flush=True)
            sys.exit(0)
    time.sleep(2)
print("timed out waiting for the probe", flush=True)
sys.exit(1)
