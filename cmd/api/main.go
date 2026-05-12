package main

import (
	"context"
	"cpsat-scheduler/internal/api"
	"cpsat-scheduler/internal/state/db"
	"log/slog"
	"net"
	"os"
	"os/signal"

	"github.com/lmittmann/tint"
	"google.golang.org/grpc"
)

const socket_path = "/tmp/cpsat-scheduler.api.sock"

func listenServer(ctx context.Context, server *grpc.Server) (err error) {
	_ = os.Remove(socket_path)
	listener, err := net.Listen("unix", socket_path)
	if err != nil {
		return
	}
	err = os.Chmod(socket_path, 0600)
	if err != nil {
		return
	}
	go func() {
		server.Serve(listener)
	}()
	<-ctx.Done()
	server.GracefulStop()
	return
}

func main() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
	defer cancel()

	tintHandle := tint.NewHandler(os.Stderr, &tint.Options{Level: slog.LevelInfo})
	logger := slog.New(tintHandle)
	logger = logger.WithGroup("main")

	driver, err := db.OpenDB(ctx, logger, "state.db")
	if err != nil {
		slog.Error("open db", "err", err)
		return
	}
	defer driver.Close()

	impl := newServer(ctx, logger, driver)
	server := grpc.NewServer()
	api.RegisterAPIServer(server, impl)
	err = listenServer(ctx, server)
	if err != nil {
		slog.Error("listen", "err", err)
		return
	}
}
