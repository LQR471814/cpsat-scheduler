from commonpb import types_pb2 as _types_pb2
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
    start: _types_pb2.AtomicUnit
    end: _types_pb2.AtomicUnit
    cost: int
    def __init__(self, start: _Optional[_Union[_types_pb2.AtomicUnit, _Mapping]] = ..., end: _Optional[_Union[_types_pb2.AtomicUnit, _Mapping]] = ..., cost: _Optional[int] = ...) -> None: ...

class DurConfig(_message.Message):
    __slots__ = ("intervals", "duration")
    INTERVALS_FIELD_NUMBER: _ClassVar[int]
    DURATION_FIELD_NUMBER: _ClassVar[int]
    intervals: _containers.RepeatedCompositeFieldContainer[CostInterval]
    duration: _types_pb2.AtomicUnit
    def __init__(self, intervals: _Optional[_Iterable[_Union[CostInterval, _Mapping]]] = ..., duration: _Optional[_Union[_types_pb2.AtomicUnit, _Mapping]] = ...) -> None: ...

class ChildrenConfig(_message.Message):
    __slots__ = ("intervals", "children")
    INTERVALS_FIELD_NUMBER: _ClassVar[int]
    CHILDREN_FIELD_NUMBER: _ClassVar[int]
    intervals: _containers.RepeatedCompositeFieldContainer[CostInterval]
    children: _containers.RepeatedScalarFieldContainer[int]
    def __init__(self, intervals: _Optional[_Iterable[_Union[CostInterval, _Mapping]]] = ..., children: _Optional[_Iterable[int]] = ...) -> None: ...

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
    unit: _types_pb2.AtomicUnit
    start: _types_pb2.TaskUnit
    end: _types_pb2.TaskUnit
    prereqs: _containers.RepeatedScalarFieldContainer[int]
    dur_cfgs: _containers.RepeatedCompositeFieldContainer[DurConfig]
    children_cfgs: _containers.RepeatedCompositeFieldContainer[ChildrenConfig]
    def __init__(self, id: _Optional[int] = ..., unit: _Optional[_Union[_types_pb2.AtomicUnit, _Mapping]] = ..., start: _Optional[_Union[_types_pb2.TaskUnit, _Mapping]] = ..., end: _Optional[_Union[_types_pb2.TaskUnit, _Mapping]] = ..., prereqs: _Optional[_Iterable[int]] = ..., dur_cfgs: _Optional[_Iterable[_Union[DurConfig, _Mapping]]] = ..., children_cfgs: _Optional[_Iterable[_Union[ChildrenConfig, _Mapping]]] = ...) -> None: ...

class SolvedTask(_message.Message):
    __slots__ = ("id", "start", "dur_idx", "children_idx", "cost", "duration", "end")
    ID_FIELD_NUMBER: _ClassVar[int]
    START_FIELD_NUMBER: _ClassVar[int]
    DUR_IDX_FIELD_NUMBER: _ClassVar[int]
    CHILDREN_IDX_FIELD_NUMBER: _ClassVar[int]
    COST_FIELD_NUMBER: _ClassVar[int]
    DURATION_FIELD_NUMBER: _ClassVar[int]
    END_FIELD_NUMBER: _ClassVar[int]
    id: int
    start: _types_pb2.TaskUnit
    dur_idx: int
    children_idx: int
    cost: int
    duration: _types_pb2.AtomicUnit
    end: _types_pb2.AtomicUnit
    def __init__(self, id: _Optional[int] = ..., start: _Optional[_Union[_types_pb2.TaskUnit, _Mapping]] = ..., dur_idx: _Optional[int] = ..., children_idx: _Optional[int] = ..., cost: _Optional[int] = ..., duration: _Optional[_Union[_types_pb2.AtomicUnit, _Mapping]] = ..., end: _Optional[_Union[_types_pb2.AtomicUnit, _Mapping]] = ...) -> None: ...

class SolveRequest(_message.Message):
    __slots__ = ("horizon", "tasks")
    HORIZON_FIELD_NUMBER: _ClassVar[int]
    TASKS_FIELD_NUMBER: _ClassVar[int]
    horizon: _types_pb2.AtomicInterval
    tasks: _containers.RepeatedCompositeFieldContainer[Task]
    def __init__(self, horizon: _Optional[_Union[_types_pb2.AtomicInterval, _Mapping]] = ..., tasks: _Optional[_Iterable[_Union[Task, _Mapping]]] = ...) -> None: ...

class SolveResponse(_message.Message):
    __slots__ = ("status", "score", "solution")
    STATUS_FIELD_NUMBER: _ClassVar[int]
    SCORE_FIELD_NUMBER: _ClassVar[int]
    SOLUTION_FIELD_NUMBER: _ClassVar[int]
    status: SolveStatus
    score: int
    solution: _containers.RepeatedCompositeFieldContainer[SolvedTask]
    def __init__(self, status: _Optional[_Union[SolveStatus, str]] = ..., score: _Optional[int] = ..., solution: _Optional[_Iterable[_Union[SolvedTask, _Mapping]]] = ...) -> None: ...
