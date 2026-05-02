from google.protobuf.internal import containers as _containers
from google.protobuf.internal import enum_type_wrapper as _enum_type_wrapper
from google.protobuf import descriptor as _descriptor
from google.protobuf import message as _message
from collections.abc import Iterable as _Iterable, Mapping as _Mapping
from typing import ClassVar as _ClassVar, Optional as _Optional, Union as _Union

DESCRIPTOR: _descriptor.FileDescriptor

class SolveStatus(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    FEASIBLE: _ClassVar[SolveStatus]
    INFEASIBLE: _ClassVar[SolveStatus]
    MODEL_INVALID: _ClassVar[SolveStatus]
    OPTIMAL: _ClassVar[SolveStatus]
    UNKNOWN: _ClassVar[SolveStatus]
FEASIBLE: SolveStatus
INFEASIBLE: SolveStatus
MODEL_INVALID: SolveStatus
OPTIMAL: SolveStatus
UNKNOWN: SolveStatus

class CostInterval(_message.Message):
    __slots__ = ("start", "end", "cost")
    START_FIELD_NUMBER: _ClassVar[int]
    END_FIELD_NUMBER: _ClassVar[int]
    COST_FIELD_NUMBER: _ClassVar[int]
    start: int
    end: int
    cost: int
    def __init__(self, start: _Optional[int] = ..., end: _Optional[int] = ..., cost: _Optional[int] = ...) -> None: ...

class DurConfig(_message.Message):
    __slots__ = ("id", "intervals", "duration")
    ID_FIELD_NUMBER: _ClassVar[int]
    INTERVALS_FIELD_NUMBER: _ClassVar[int]
    DURATION_FIELD_NUMBER: _ClassVar[int]
    id: int
    intervals: _containers.RepeatedCompositeFieldContainer[CostInterval]
    duration: int
    def __init__(self, id: _Optional[int] = ..., intervals: _Optional[_Iterable[_Union[CostInterval, _Mapping]]] = ..., duration: _Optional[int] = ...) -> None: ...

class ChildrenConfig(_message.Message):
    __slots__ = ("id", "intervals", "children")
    ID_FIELD_NUMBER: _ClassVar[int]
    INTERVALS_FIELD_NUMBER: _ClassVar[int]
    CHILDREN_FIELD_NUMBER: _ClassVar[int]
    id: int
    intervals: _containers.RepeatedCompositeFieldContainer[CostInterval]
    children: _containers.RepeatedScalarFieldContainer[int]
    def __init__(self, id: _Optional[int] = ..., intervals: _Optional[_Iterable[_Union[CostInterval, _Mapping]]] = ..., children: _Optional[_Iterable[int]] = ...) -> None: ...

class Task(_message.Message):
    __slots__ = ("id", "unit", "start", "end", "prereqs", "dur_cfgs", "children_cfgs")
    ID_FIELD_NUMBER: _ClassVar[int]
    UNIT_FIELD_NUMBER: _ClassVar[int]
    START_FIELD_NUMBER: _ClassVar[int]
    END_FIELD_NUMBER: _ClassVar[int]
    PREREQS_FIELD_NUMBER: _ClassVar[int]
    DUR_CFGS_FIELD_NUMBER: _ClassVar[int]
    CHILDREN_CFGS_FIELD_NUMBER: _ClassVar[int]
    id: int
    unit: int
    start: int
    end: int
    prereqs: _containers.RepeatedScalarFieldContainer[int]
    dur_cfgs: _containers.RepeatedCompositeFieldContainer[DurConfig]
    children_cfgs: _containers.RepeatedCompositeFieldContainer[ChildrenConfig]
    def __init__(self, id: _Optional[int] = ..., unit: _Optional[int] = ..., start: _Optional[int] = ..., end: _Optional[int] = ..., prereqs: _Optional[_Iterable[int]] = ..., dur_cfgs: _Optional[_Iterable[_Union[DurConfig, _Mapping]]] = ..., children_cfgs: _Optional[_Iterable[_Union[ChildrenConfig, _Mapping]]] = ...) -> None: ...

class SolvedTask(_message.Message):
    __slots__ = ("id", "start", "dur_id", "children_id", "cost", "duration", "end")
    ID_FIELD_NUMBER: _ClassVar[int]
    START_FIELD_NUMBER: _ClassVar[int]
    DUR_ID_FIELD_NUMBER: _ClassVar[int]
    CHILDREN_ID_FIELD_NUMBER: _ClassVar[int]
    COST_FIELD_NUMBER: _ClassVar[int]
    DURATION_FIELD_NUMBER: _ClassVar[int]
    END_FIELD_NUMBER: _ClassVar[int]
    id: int
    start: int
    dur_id: int
    children_id: int
    cost: int
    duration: int
    end: int
    def __init__(self, id: _Optional[int] = ..., start: _Optional[int] = ..., dur_id: _Optional[int] = ..., children_id: _Optional[int] = ..., cost: _Optional[int] = ..., duration: _Optional[int] = ..., end: _Optional[int] = ...) -> None: ...

class SolveRequest(_message.Message):
    __slots__ = ("tasks",)
    TASKS_FIELD_NUMBER: _ClassVar[int]
    tasks: _containers.RepeatedCompositeFieldContainer[Task]
    def __init__(self, tasks: _Optional[_Iterable[_Union[Task, _Mapping]]] = ...) -> None: ...

class SolveResponse(_message.Message):
    __slots__ = ("status", "score", "solution")
    STATUS_FIELD_NUMBER: _ClassVar[int]
    SCORE_FIELD_NUMBER: _ClassVar[int]
    SOLUTION_FIELD_NUMBER: _ClassVar[int]
    status: SolveStatus
    score: int
    solution: _containers.RepeatedCompositeFieldContainer[SolvedTask]
    def __init__(self, status: _Optional[_Union[SolveStatus, str]] = ..., score: _Optional[int] = ..., solution: _Optional[_Iterable[_Union[SolvedTask, _Mapping]]] = ...) -> None: ...
