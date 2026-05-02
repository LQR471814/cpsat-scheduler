import logging
import time
from concurrent import futures

import grpc
from google.protobuf.internal import containers as _containers

from cpsatmodel.config import (
    CostInterval,
    Model,
)
from cpsatmodel.config_builder import ConfigBuilder, Task
import model.daemonpb.service_pb2 as pb
import model.daemonpb.service_pb2_grpc as grpcpb
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
        builder = ConfigBuilder()

        task_map: dict[int, pb.Task] = {}
        for solved in request.tasks:
            task_map[solved.id] = solved

        def __convert_cost_intv(
            intervals: _containers.RepeatedCompositeFieldContainer[pb.CostInterval],
        ) -> list[CostInterval]:
            return [
                CostInterval(interval=(intv.start, intv.end), cost=intv.cost)
                for intv in intervals
            ]

        id_task_map: dict[int, pb.Task] = {}

        def __ensure_task(id: int):
            task = task_map[id]
            if id in builder.tasks:
                return builder.tasks[id]

            start: int | None = None
            if task.HasField("start"):
                start = task.start
            end: int | None = None
            if task.HasField("end"):
                end = task.end

            for id in task.prereqs:
                __ensure_task(id)

            t = Task(builder=builder, unit=task.unit, start=start, end=end)
            id_task_map[t.id] = task

            for cfg in task.dur_cfgs:
                t.add_cost_config_duration(
                    __convert_cost_intv(cfg.intervals), cfg.duration
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
            task = id_task_map[solved.task_id]

            obj = pb.SolvedTask(
                id=task.id,
                start=solved.start,
                end=solved.real_end,
                cost=solved.real_cost,
                duration=solved.real_duration,
            )
            if solved.config >= len(task.dur_cfgs):
                obj.children_id = solved.config - len(task.dur_cfgs)
            else:
                obj.dur_id = solved.config

            solution_conv.append(obj)

        return pb.SolveResponse(
            status=status_map[status],
            score=round(score),
            solution=solution_conv,
        )


def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    grpcpb.add_SolverServicer_to_server(SolverServicer(), server)
    server.add_insecure_port("[::]:50051")
    server.start()
    try:
        _ONE_DAY_IN_SECONDS = 60 * 60 * 24
        while True:
            time.sleep(_ONE_DAY_IN_SECONDS)
    except KeyboardInterrupt:
        server.stop(0)


if __name__ == "__main__":
    logging.basicConfig()
    serve()
