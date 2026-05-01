package db

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"

	_ "embed"

	_ "modernc.org/sqlite"
)

//go:embed schema.sql
var schema string

const sqlite_options = `
pragma journal_mode = WAL;
pragma synchronous = normal;
pragma temp_store = memory;
pragma mmap_size = 30000000000;
pragma journal_size_limit = 6144000;
pragma busy_timeout = 10000;
`

func configureSQLite(ctx context.Context, driver *sql.DB) (err error) {
	_, err = driver.ExecContext(ctx, sqlite_options)

	driver.SetMaxOpenConns(1)
	driver.SetMaxIdleConns(1)
	driver.SetConnMaxLifetime(0)

	return
}

func migrateSQLite(ctx context.Context, logger *slog.Logger, driver *sql.DB) (err error) {
	tx, err := driver.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()

	res, err := tx.QueryContext(ctx, `SELECT name 
FROM sqlite_master
WHERE type='table' AND name='profile'`)
	if err != nil {
		return
	}
	defer res.Close()

	if !res.Next() {
		_, err = tx.ExecContext(ctx, schema)
		if err != nil {
			return
		}
		logger.Info("schema migrated")
		err = tx.Commit()
	}

	return
}

func OpenDB(ctx context.Context, logger *slog.Logger, db string) (driver *sql.DB, err error) {
	driver, err = sql.Open("sqlite", fmt.Sprintf("file:%s", db))
	if err != nil {
		return
	}

	err = driver.PingContext(ctx)
	if err != nil {
		return
	}

	err = configureSQLite(ctx, driver)
	if err != nil {
		return
	}
	err = migrateSQLite(ctx, logger, driver)
	if err != nil {
		return
	}

	return
}

func CloseDB(driver *sql.DB) error {
	defer driver.Close()
	_, err := driver.Exec("pragma optimize")
	return err
}
