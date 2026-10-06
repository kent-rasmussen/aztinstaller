"""Stream a command to NSIS and a durable transcript, with progress heartbeats."""

import datetime
import os
import queue
import subprocess
import sys
import threading
import time
import traceback


def main():
    log_path, *command = sys.argv[1:]
    started = time.monotonic()
    # Append so a retry does not erase the evidence from an earlier run.
    with open(log_path, "a", encoding="utf-8", buffering=1) as log:
        def emit(message):
            log.write(message + "\n")
            log.flush()
            # Keep individual NSIS detail entries short; the file retains everything.
            print(message[:800], flush=True)

        emit("\n=== Bootstrap started " + datetime.datetime.now().astimezone().isoformat() + " ===")
        emit("Working directory: " + os.getcwd())
        emit("Command: " + subprocess.list2cmdline(command))
        try:
            process = subprocess.Popen(
                command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, encoding="utf-8", errors="replace",
            )
            lines = queue.Queue()

            def read_output():
                try:
                    for line in process.stdout:
                        lines.put(line.rstrip("\r\n"))
                finally:
                    lines.put(None)

            threading.Thread(target=read_output, daemon=True).start()
            while True:
                try:
                    line = lines.get(timeout=30)
                except queue.Empty:
                    emit("Bootstrap still running (%.0f seconds elapsed); waiting for command output." %
                         (time.monotonic() - started))
                    continue
                if line is None:
                    break
                emit(line)
            return_code = process.wait()
            process.stdout.close()
            emit("Bootstrap finished: exit code %s; elapsed %.1f seconds." %
                 (return_code, time.monotonic() - started))
            return return_code
        except Exception:
            emit(traceback.format_exc())
            emit("Bootstrap runner failed after %.1f seconds." % (time.monotonic() - started))
            return 1


if __name__ == "__main__":
    sys.exit(main())
