CREATE SCHEMA IF NOT EXISTS app;

CREATE TABLE IF NOT EXISTS app.health_check (
    id SERIAL PRIMARY KEY,
    status TEXT NOT NULL,
    checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO app.health_check (status)
VALUES ('PostgreSQL initialized successfully');