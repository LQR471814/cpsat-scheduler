package solver

import (
	"context"
	"cpsat-scheduler/internal/solver/solverpb"
	"cpsat-scheduler/internal/state"
	"cpsat-scheduler/internal/state/db"
	"database/sql"
	"log/slog"
	"os"
	"testing"
	"time"

	"google.golang.org/grpc"
)

type mockSolverClient struct {
	tasks []*solverpb.Task
	err   error
}

func (m *mockSolverClient) Solve(ctx context.Context, in *solverpb.SolveRequest, opts ...grpc.CallOption) (*solverpb.SolveResponse, error) {
	m.tasks = in.Tasks
	if m.err != nil {
		return nil, m.err
	}
	return &solverpb.SolveResponse{
		Status: solverpb.SolveStatus_OPTIMAL,
	}, nil
}

func TestSolveProfile(t *testing.T) {
	ctx := context.Background()
	logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelDebug}))

	driver, err := db.OpenDB(ctx, logger, ":memory:")
	if err != nil {
		t.Fatalf("failed to open DB: %v", err)
	}
	defer driver.Close()

	c := state.NewContext(ctx, logger, driver)

	queries := db.New(driver)
	profileID, err := queries.CreateProfile(ctx, db.CreateProfileParams{
		Name:                    "test_profile",
		AtomicTimescaleDuration: int64(time.Hour),
		UniverseStart:           time.Now(),
		PertGenChoices:          sql.NullInt64{Valid: true, Int64: 4},
	})
	if err != nil {
		t.Fatalf("failed to create profile: %v", err)
	}

	taskID, err := queries.CreateTask(ctx, db.CreateTaskParams{
		Profile: profileID,
		Unit:    1,
		Name:    "Test Task",
		Desc:    "A test task",
	})
	if err != nil {
		t.Fatalf("failed to create task: %v", err)
	}

	err = queries.CreateDurConfig(ctx, db.CreateDurConfigParams{
		Task: taskID,
		Pes:  int64(time.Hour),
		Exp:  int64(2 * time.Hour),
		Opt:  int64(3 * time.Hour),
	})
	if err != nil {
		t.Fatalf("failed to create dur config: %v", err)
	}

	mockClient := &mockSolverClient{}
	s := Solver{
		SolverClient: mockClient,
	}

	res, err := s.SolveProfile(c, profileID)
	if err != nil {
		t.Fatalf("SolveProfile failed: %v", err)
	}

	if res == nil {
		t.Fatal("response is nil")
	}

	if res.Status != solverpb.SolveStatus_OPTIMAL {
		t.Errorf("expected SolveStatus_OPTIMAL, got %v", res.Status)
	}

	if len(mockClient.tasks) != 1 {
		t.Fatalf("expected 1 task passed to Solve, got %d", len(mockClient.tasks))
	}

	gotTask := mockClient.tasks[0]
	if gotTask.Id != taskID {
		t.Errorf("expected task ID %d, got %d", taskID, gotTask.Id)
	}
}
