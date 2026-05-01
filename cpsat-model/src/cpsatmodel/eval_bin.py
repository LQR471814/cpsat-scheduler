from cpsatmodel.config import (
    Config,
    Model,
    CostInterval,
    CostConfig,
    ParentCond,
    ScheduledTask,
)
from cpsatmodel.config_builder import Task, ConfigBuilder
from cpsatmodel.print import ProtoPrinter

from sys import stdin

buf = bytearray()

while True:
    # read one character at a time until null
    b = stdin.buffer.read(1)
    if not b:
        break
    if b != b"\x00":
        continue
    eval(buf.decode("utf8"), globals(), {})
