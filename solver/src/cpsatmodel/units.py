from __future__ import annotations
from typing import TypeVar, Generic, overload, get_args, get_origin
from functools import total_ordering


TUnit = TypeVar("TUnit")


@total_ordering
class Quantity(Generic[TUnit]):
    __slots__ = ("value", "__orig_class__")

    def __init__(self, value: int) -> None:
        self.value = value

    def __add__(self, other: Quantity[TUnit]) -> Quantity[TUnit]:
        return Quantity(self.value + other.value)

    def __sub__(self, other: Quantity[TUnit]) -> Quantity[TUnit]:
        return Quantity(self.value - other.value)

    def __mul__(self, scalar: int) -> Quantity[TUnit]:
        return Quantity(self.value * scalar)

    def __rmul__(self, scalar: int) -> Quantity[TUnit]:
        return self * scalar

    def __mod__(self, other: Quantity[TUnit]) -> Quantity[TUnit]:
        return Quantity[TUnit](self.value % other.value)

    def __divmod__(
        self,
        other: Quantity[TUnit],
    ) -> tuple[int, Quantity[TUnit]]:
        q, r = divmod(self.value, other.value)
        return q, Quantity[TUnit](r)

    @overload
    def __floordiv__(self, other: int) -> Quantity[TUnit]: ...

    @overload
    def __floordiv__(self, other: Quantity[TUnit]) -> int: ...

    def __floordiv__(self, other: int | Quantity[TUnit]) -> Quantity[TUnit] | int:
        if isinstance(other, Quantity):
            return self.value // other.value
        return Quantity[TUnit](self.value // other)

    def __neg__(self) -> Quantity[TUnit]:
        return Quantity[TUnit](-self.value)

    def __pos__(self) -> Quantity[TUnit]:
        return Quantity[TUnit](+self.value)

    def __abs__(self) -> Quantity[TUnit]:
        return Quantity[TUnit](abs(self.value))

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Quantity):
            return NotImplemented
        return self.value == other.value

    def __lt__(self, other: Quantity[TUnit]) -> bool:
        return self.value < other.value

    def __int__(self) -> int:
        return self.value

    def __float__(self) -> float:
        return float(self.value)

    def __repr__(self) -> str:
        if getattr(self, "__orig_class__", None) is None:
            return f"Quantity({self.value})"
        generic_name = get_args(self.__orig_class__)[0].__name__
        return f"{generic_name}({self.value})"

    def __hash__(self) -> int:
        return self.value


class AtomicUnit: ...


class TaskUnit: ...


atomic_unit = Quantity[AtomicUnit]
task_unit = Quantity[TaskUnit]
