from typing import Callable

enabled = True


def wrap(fn: Callable[[str], str]):
    def wrap(s: str) -> str:
        if enabled:
            return fn(s)
        return s

    return wrap


@wrap
def grey(s: str) -> str:
    return f"\033[90m{s}\033[0m"


@wrap
def red(s: str) -> str:
    return f"\033[31m{s}\033[0m"


@wrap
def blue(s: str) -> str:
    return f"\033[34m{s}\033[0m"
