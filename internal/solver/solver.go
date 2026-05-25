package solver

import (
	"context"
	"cpsat-scheduler/internal/proto/commonpb"
	"cpsat-scheduler/internal/proto/solverpb"
	"cpsat-scheduler/internal/state"
	"cpsat-scheduler/internal/state/db"
	"log/slog"
	"net"
	"net/url"
	"os/exec"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

const socketPath = "/tmp/cpsat-scheduler.solver.sock"

type Solver struct {
	ctx    context.Context
	logger *slog.Logger
	conn   *grpc.ClientConn
	solverpb.SolverClient
}

func NewSolver(ctx context.Context, logger *slog.Logger, daemonPath string) (solver Solver, err error) {
	logger = logger.WithGroup("solver")

	cmd := exec.CommandContext(ctx, daemonPath)
	err = cmd.Start()
	if err != nil {
		return
	}

	u := &url.URL{
		Scheme: "unix",
		Path:   socketPath,
	}
	conn, err := grpc.NewClient(
		u.String(),
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithContextDialer(func(ctx context.Context, s string) (net.Conn, error) {
			return (&net.Dialer{}).DialContext(ctx, "unix", socketPath)
		}),
	)
	if err != nil {
		return
	}
	solver = Solver{
		logger:       logger,
		conn:         conn,
		SolverClient: solverpb.NewSolverClient(conn),
	}
	return
}

func (s Solver) Close() error {
	return s.conn.Close()
}

// SolveProfile loads the task state of a profile from the database, runs
// scheduling, and returns the result. (note: it will prune scheduled events)
func (s Solver) SolveProfile(c state.Context, profile db.Profile, horizon state.Horizon) (res *solverpb.SolveResponse, err error) {
	var tasks []*solverpb.Task

	s.logger.Debug("loading profile state")
	err = state.LookupProfileState(c, profile, horizon, &tasks)
	if err != nil {
		return
	}

	s.logger.Debug("loaded profile state, generating event tasks...", "tasks", len(tasks))
	_, err = state.GenerateEventTasks(c, profile, horizon, &tasks)
	if err != nil {
		return
	}

	s.logger.Debug(
		"generated event tasks, solving...",
		"tasks", len(tasks),
		"horizon_start", horizon.Start.Value,
		"horizon_end", horizon.End.Value,
	)
	res, err = s.SolverClient.Solve(c.Ctx(), &solverpb.SolveRequest{
		Tasks: tasks,
		Horizon: &commonpb.AtomicInterval{
			Start: horizon.Start,
			End:   horizon.End,
		},
	})
	if err != nil {
		return
	}

	// filter event segments out of solution
	var solution []*solverpb.SolvedTask
	for _, scheduled := range res.Solution {
		if scheduled.Id < 0 {
			continue
		}
		solution = append(solution, scheduled)
	}
	res.Solution = solution

	s.logger.Debug(
		"got solution",
		"status", res.Status,
		"score", res.Score,
		"tasks", len(res.Solution),
	)

	return
}
