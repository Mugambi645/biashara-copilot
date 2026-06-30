package db

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq" // Driver for sqlx postgres connection
)

// Pool wraps pgxpool for advanced high-performance concurrency operations
type Pool struct {
	*pgxpool.Pool
}

// DB wraps sqlx for standard relational handling and named struct scanning
type DB struct {
	*sqlx.DB
}

// NewPool initializes a high-performance pgx connection pool
func NewPool(ctx context.Context, databaseURL string) (*Pool, error) {
	cfg, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse db config: %w", err)
	}

	// Connection tuning configurations
	cfg.MaxConns = 20
	cfg.MinConns = 2
	cfg.MaxConnLifetime = 30 * time.Minute
	cfg.MaxConnIdleTime = 5 * time.Minute
	cfg.HealthCheckPeriod = 1 * time.Minute

	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("create pool: %w", err)
	}

	// Immediate health verification check
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping db: %w", err)
	}

	return &Pool{pool}, nil
}

// NewSQLX initializes an sqlx database connection handle for flexible query builder setups
func NewSQLX(databaseURL string) (*DB, error) {
	db, err := sqlx.Connect("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("connect sqlx: %w", err)
	}

	// Connection limits matching resource targets
	db.SetMaxOpenConns(20)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(30 * time.Minute)

	return &DB{db}, nil
}