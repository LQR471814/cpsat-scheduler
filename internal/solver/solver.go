package solver

import (
	"context"
	"cpsat-scheduler/internal/solver/solverpb"
	"cpsat-scheduler/internal/state"
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

// SolveProfile loads the task state of a profile from the database, runs scheduling, and returns the result.
func (s Solver) SolveProfile(c state.Context, profileID int64) (*solverpb.SolveResponse, error) {
	tasks, err := state.LookupProfileState(c, profileID)
	if err != nil {
		return nil, err
	}
	return s.Solve(c.Ctx(), &solverpb.SolveRequest{
		Tasks: tasks,
	})
}

