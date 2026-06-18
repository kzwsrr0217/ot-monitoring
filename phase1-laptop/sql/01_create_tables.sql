-- OT Monitoring — table creation (idempotent)
-- Run this in SSMS against the OTMonitoring database.
-- Create DB first if it doesn't exist:
--   CREATE DATABASE OTMonitoring;

USE OTMonitoring;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'machine_telemetry')
BEGIN
  CREATE TABLE machine_telemetry (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    timestamp       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    machine_id      NVARCHAR(50)  NOT NULL,
    vlan            NVARCHAR(20),
    site            NVARCHAR(50),
    machine_on      BIT,
    production_run  BIT,
    error_state     BIT,
    prod_type       INT,
    ok_count        BIGINT,
    nok_count       BIGINT,
    cycle_time_ms   INT,
    stoppage_ms     INT,
    cycle_count     BIGINT
  );
  CREATE INDEX IX_telemetry_machine_time ON machine_telemetry (machine_id, timestamp DESC);
  PRINT 'Created table: machine_telemetry';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'cycle_events')
BEGIN
  CREATE TABLE cycle_events (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    cycle_timestamp DATETIME2 NOT NULL,
    machine_id      NVARCHAR(50) NOT NULL,
    cycle_index     BIGINT,
    cycle_time_ms   INT,
    ok              BIT,
    ingested_at     DATETIME2 DEFAULT SYSUTCDATETIME()
  );
  CREATE INDEX IX_cycle_machine_time ON cycle_events (machine_id, cycle_timestamp DESC);
  PRINT 'Created table: cycle_events';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'downtime_reasons')
BEGIN
  CREATE TABLE downtime_reasons (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    reason_name     NVARCHAR(100) NOT NULL,
    category        NVARCHAR(50),
    department      NVARCHAR(50),
    is_planned      BIT DEFAULT 0,
    is_active       BIT DEFAULT 1,
    sort_order      INT DEFAULT 100,
    created_at      DATETIME2 DEFAULT SYSUTCDATETIME()
  );
  PRINT 'Created table: downtime_reasons';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'stoppage_events')
BEGIN
  CREATE TABLE stoppage_events (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    machine_id      NVARCHAR(50)  NOT NULL,
    stop_start      DATETIME2     NOT NULL,
    stop_end        DATETIME2,
    stoppage_ms     INT,
    reason_id       INT,           -- FK -> downtime_reasons, nullable
    comment         NVARCHAR(500),
    entered_by      NVARCHAR(100),
    entered_at      DATETIME2,
    is_fault        BIT DEFAULT 0,
    CONSTRAINT FK_stoppage_reason FOREIGN KEY (reason_id)
      REFERENCES downtime_reasons(id)
  );
  CREATE INDEX IX_stoppage_machine_time ON stoppage_events (machine_id, stop_start DESC);
  CREATE INDEX IX_stoppage_reason       ON stoppage_events (reason_id, stop_start) INCLUDE (stoppage_ms, machine_id);
  PRINT 'Created table: stoppage_events';
END
GO

PRINT 'Schema ready.';
GO
