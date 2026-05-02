package solver

import (
	"context"
	"cpsat-scheduler/internal/solver/solverpb"
	"net"
	"net/url"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

const socketPath = "/tmp/cpsat-scheduler.solver.sock"

type Solver struct {
	conn   *grpc.ClientConn
	client solverpb.SolverClient
}

func NewSolver() (rpc Solver, err error) {
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
	rpc = Solver{
		conn:   conn,
		client: solverpb.NewSolverClient(conn),
	}
	return
}

func (c Solver) Solve(ctx context.Context, profileID int64) {
}

func (c Solver) Close() {
	c.Close()
}
