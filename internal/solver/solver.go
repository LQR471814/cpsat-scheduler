package solver

import (
	"context"
	"cpsat-scheduler/internal/solver/solverpb"
	"cpsat-scheduler/internal/state"
	"cpsat-scheduler/internal/state/db"
	"net"
	"net/url"
	"os/exec"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

const socketPath = "/tmp/cpsat-scheduler.solver.sock"

type Solver struct {
	conn *grpc.ClientConn
	solverpb.SolverClient
}

func NewSolver(daemonPath string) (solver Solver, err error) {
	cmd := exec.Command(daemonPath)
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
func (s Solver) SolveProfile(c state.Context, profile db.Profile) (res *solverpb.SolveResponse, err error) {
	var tasks []*solverpb.Task

	err = state.LookupProfileState(c, profile, &tasks)
	if err != nil {
		return
	}
	events, err := state.GenerateEventTasks(c, profile, &tasks)
	if err != nil {
		return
	}

	res, err = s.Solve(c.Ctx(), &solverpb.SolveRequest{
		Tasks: tasks,
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

	// add (full) events back into solution
	id := int64(-1)
	for _, ev := range events {
		start := int64(ev.Start.Sub(profile.UniverseStart)) / int64(profile.AtomicTimescaleDuration)
		end := int64(ev.End.Sub(profile.UniverseStart)) / int64(profile.AtomicTimescaleDuration)
		solution = append(solution, &solverpb.SolvedTask{
			Id:       id,
			Start:    start,
			End:      end,
			Cost:     0,
			Duration: end - start,
			Config: &solverpb.SolvedTask_DurIdx{
				DurIdx: 0,
			},
		})
		id--
	}
	res.Solution = solution

	return
}
