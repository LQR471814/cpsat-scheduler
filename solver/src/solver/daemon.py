import logging
import time
from concurrent import futures
import os
import traceback

import grpc
from google.protobuf.internal import containers as _containers

from cpsatmodel.config import (
    CostInterval,
    Model,
)
from cpsatmodel.config import atomic_unit, task_unit
from cpsatmodel.config_builder import ConfigBuilder, Task
import solverpb.service_pb2 as pb
import solverpb.service_pb2_grpc as grpcpb
import commonpb.types_pb2 as commonpb
from ortools.sat.python import cp_model


status_map: dict[cp_model.CpSolverStatus, pb.SolveStatus] = {
    cp_model.FEASIBLE: pb.SolveStatus.FEASIBLE,
    cp_model.INFEASIBLE: pb.SolveStatus.INFEASIBLE,
    cp_model.MODEL_INVALID: pb.SolveStatus.MODEL_INVALID,
    cp_model.OPTIMAL: pb.SolveStatus.OPTIMAL,
    cp_model.UNKNOWN: pb.SolveStatus.UNKNOWN,
}


class SolverServicer(grpcpb.SolverServicer):
    def Solve(self, request: pb.SolveRequest, context):
        try:
            horizon = (
                atomic_unit(request.horizon.start.value),
                atomic_unit(request.horizon.end.value),
            )
            builder = ConfigBuilder(horizon)

            task_map: dict[int, pb.Task] = {}
            for t in request.tasks:
                task_map[t.id] = t

            def __convert_cost_intv(
                intervals: _containers.RepeatedCompositeFieldContainer[pb.CostInterval],
            ) -> list[CostInterval]:
                return [
                    CostInterval(
                        interval=(
                            atomic_unit(intv.start.value),
                            atomic_unit(intv.end.value),
                        ),
                        cost=intv.cost,
                    )
                    for intv in intervals
                ]

            id_task_map: dict[int, pb.Task] = {}

            def __ensure_task(id: int):
                task = task_map[id]
                if id in builder.tasks:
                    return builder.tasks[id]

                start: task_unit | None = None
                if task.HasField("start"):
                    start = task_unit(task.start.value)

                end: task_unit | None = None
                if task.HasField("end"):
                    end = task_unit(task.end.value)

                for id in task.prereqs:
                    __ensure_task(id)

                t = Task(
                    builder=builder,
                    unit=atomic_unit(task.unit.value),
                    start=start,
                    end=end,
                )
                id_task_map[t.id] = task

                for cfg in task.dur_cfgs:
                    t.add_cost_config_duration(
                        __convert_cost_intv(cfg.intervals),
                        atomic_unit(cfg.duration.value),
                    )
                for cfg in task.children_cfgs:
                    t.add_cost_config_children(
                        __convert_cost_intv(cfg.intervals),
                        [__ensure_task(child) for child in cfg.children],
                    )

                return t

            for solved in request.tasks:
                __ensure_task(solved.id)

            model = Model(builder.build())
            status, score, solution = model.solve()

            solution_conv: list[pb.SolvedTask] = []
            for solved in solution:
                if solved.task_id in builder.temp_tasks:
                    continue

                task = id_task_map[solved.task_id]

                obj = pb.SolvedTask(
                    id=task.id,
                    start=commonpb.TaskUnit(value=solved.start),
                    end=commonpb.AtomicUnit(value=solved.real_end),
                    cost=solved.real_cost,
                    duration=commonpb.AtomicUnit(value=solved.real_duration),
                )
                if solved.config >= len(task.dur_cfgs):
                    obj.children_idx = solved.config - len(task.dur_cfgs)
                else:
                    obj.dur_idx = solved.config

                solution_conv.append(obj)

            return pb.SolveResponse(
                status=status_map[status],
                score=round(score),
                solution=solution_conv,
            )
        except Exception as err:
            traceback.print_exc()
            context.abort(grpc.StatusCode.INTERNAL, f"internal error: {err}")


def serve(sock_path: str):
    try:
        os.remove(sock_path)  # stale file → bind fail
    except FileNotFoundError:
        pass

    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    grpcpb.add_SolverServicer_to_server(SolverServicer(), server)
    server.add_insecure_port(f"unix:{sock_path}")
    server.start()

    print("listening...")
    try:
        _ONE_DAY_IN_SECONDS = 60 * 60 * 24
        while True:
            time.sleep(_ONE_DAY_IN_SECONDS)
    except KeyboardInterrupt:
        server.stop(0)


if __name__ == "__main__":
    logging.basicConfig()
    serve("/tmp/cpsat-scheduler.solver.sock")
