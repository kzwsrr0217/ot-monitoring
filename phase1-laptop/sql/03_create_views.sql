-- OT Monitoring — pre-built views for OEE, MTBF, Pareto, micro-stoppages (idempotent)
USE OTMonitoring;
GO

-- OEE components by shift (8h windows)
IF OBJECT_ID('dbo.vw_oee_by_shift', 'V') IS NOT NULL DROP VIEW dbo.vw_oee_by_shift;
GO
CREATE VIEW dbo.vw_oee_by_shift AS
WITH shift_data AS (
  SELECT
    machine_id,
    CAST(timestamp AS DATE)              AS shift_date,
    DATEPART(HOUR, timestamp) / 8        AS shift_num,
    SUM(CASE WHEN production_run = 1 THEN 1.0 ELSE 0 END) / COUNT(*) AS availability,
    (MAX(ok_count) - MIN(ok_count))      AS parts_produced,
    (MAX(nok_count) - MIN(nok_count))    AS parts_nok,
    AVG(CASE WHEN cycle_time_ms > 0 THEN CAST(cycle_time_ms AS FLOAT) END) AS avg_cycle_ms
  FROM machine_telemetry
  GROUP BY machine_id, CAST(timestamp AS DATE), DATEPART(HOUR, timestamp) / 8
)
SELECT
  machine_id,
  shift_date,
  shift_num,
  availability,
  parts_produced,
  parts_nok,
  CASE WHEN parts_produced + parts_nok > 0
    THEN parts_produced * 1.0 / (parts_produced + parts_nok)
  END AS quality,
  avg_cycle_ms,
  -- OEE = Availability × Performance × Quality
  -- 900.0 = ideal cycle time ms (line1 baseline — adjust per machine in production)
  availability
    * ISNULL(900.0 / NULLIF(avg_cycle_ms, 0), 0)
    * CASE WHEN parts_produced + parts_nok > 0
        THEN parts_produced * 1.0 / (parts_produced + parts_nok)
        ELSE 0
      END AS oee
FROM shift_data;
GO

-- MTBF / MTTR (last 24h)
IF OBJECT_ID('dbo.vw_mtbf_mttr_24h', 'V') IS NOT NULL DROP VIEW dbo.vw_mtbf_mttr_24h;
GO
CREATE VIEW dbo.vw_mtbf_mttr_24h AS
SELECT
  s.machine_id,
  COUNT(*)                                       AS fault_count,
  AVG(CAST(s.stoppage_ms AS FLOAT)) / 1000.0    AS mttr_seconds,
  CASE WHEN COUNT(*) > 0
    THEN (
      SELECT SUM(CASE WHEN production_run = 1 THEN 1 ELSE 0 END)
      FROM machine_telemetry mt2
      WHERE mt2.machine_id = s.machine_id
        AND mt2.timestamp >= DATEADD(HOUR, -24, SYSUTCDATETIME())
    ) * 1.0 / COUNT(*) / 3600.0
  END AS mtbf_hours
FROM stoppage_events s
WHERE s.stop_start >= DATEADD(HOUR, -24, SYSUTCDATETIME())
GROUP BY s.machine_id;
GO

-- Pareto — stoppage cause ranking
IF OBJECT_ID('dbo.vw_stoppage_pareto', 'V') IS NOT NULL DROP VIEW dbo.vw_stoppage_pareto;
GO
CREATE VIEW dbo.vw_stoppage_pareto AS
SELECT
  r.reason_name,
  r.category,
  r.department,
  COUNT(*)                       AS occurrence_count,
  SUM(s.stoppage_ms) / 60000.0  AS total_minutes,
  SUM(SUM(s.stoppage_ms)) OVER (ORDER BY SUM(s.stoppage_ms) DESC ROWS UNBOUNDED PRECEDING)
    * 100.0 / SUM(SUM(s.stoppage_ms)) OVER () AS cumulative_pct
FROM stoppage_events s
JOIN downtime_reasons r ON s.reason_id = r.id
GROUP BY r.reason_name, r.category, r.department;
GO

-- Micro-stoppage audit (2–30 second stoppages)
IF OBJECT_ID('dbo.vw_micro_stoppages', 'V') IS NOT NULL DROP VIEW dbo.vw_micro_stoppages;
GO
CREATE VIEW dbo.vw_micro_stoppages AS
SELECT
  machine_id,
  stop_start,
  stop_end,
  stoppage_ms,
  stoppage_ms / 1000.0 AS stoppage_sec
FROM stoppage_events
WHERE stoppage_ms BETWEEN 2000 AND 30000;
GO

PRINT 'Views created: vw_oee_by_shift, vw_mtbf_mttr_24h, vw_stoppage_pareto, vw_micro_stoppages';
GO
