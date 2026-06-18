-- Seed downtime reason catalogue (idempotent)
USE OTMonitoring;
GO

IF NOT EXISTS (SELECT 1 FROM downtime_reasons WHERE reason_name = 'Anyaghiány')
BEGIN
  INSERT INTO downtime_reasons (reason_name, category, department, is_planned, sort_order) VALUES
    ('Anyaghiány',                 'Anyag',     'Termelés',       0, 10),
    ('Szalag / konveyor elakad',   'Gép',       'Termelés',       0, 20),
    ('Minőségi ellenőrzés stop',   'Minőség',   'Minőség',        0, 30),
    ('Tervezett karbantartás',     'Gép',       'Karbantartás',   1, 40),
    ('Nem tervezett meghibásodás', 'Gép',       'Karbantartás',   0, 50),
    ('Szerszámcsere',              'Gép',       'Termelés',       1, 60),
    ('Operátor szünet',            'Operátor',  'Termelés',       1, 70),
    ('Programváltás / setup',      'Anyag',     'Termelés',       1, 80),
    ('IT / rendszer hiba',         'Egyéb',     'IT',             0, 90),
    ('Egyéb',                      'Egyéb',     NULL,             0, 100);
  PRINT 'Seeded 10 downtime reasons.';
END
ELSE
  PRINT 'Downtime reasons already seeded — skipping.';
GO
