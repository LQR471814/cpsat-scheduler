package db

import (
	"context"
	"database/sql"
	"log/slog"
	"net/url"
	"path/filepath"

	_ "embed"

	_ "modernc.org/sqlite"
)

//go:embed schema.sql
var schema string

var sqlite_options = url.Values{
	"_pragma": {
		"journal_mode(WAL)",
		"synchronous(normal)",
		"temp_store(memory)",
		"mmap_size(30000000000)",
		"journal_size_limit(6144000)",
		"busy_timeout(10000)",
	},
}

func configureSQLite(driver *sql.DB) (err error) {
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

func OpenDB(ctx context.Context, logger *slog.Logger, file string) (driver *sql.DB, err error) {
	abspath, err := filepath.Abs(file)
	if err != nil {
		return
	}
	var openUrl string
	if file == ":memory:" {
		openUrl = file
	} else {
		link := &url.URL{
			Scheme:   "file",
			Path:     abspath,
			RawQuery: sqlite_options.Encode(),
		}
		openUrl = link.String()
	}
	driver, err = sql.Open("sqlite", openUrl)
	if err != nil {
		return
	}

	err = driver.PingContext(ctx)
	if err != nil {
		return
	}

	err = configureSQLite(driver)
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
