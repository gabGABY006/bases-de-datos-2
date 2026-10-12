-- =====================================================================
-- Bases de Datos 2 · Taller integrador — Banco Andino
-- Archivo: 04_reto_corregido.sql
-- Integrantes: Julián · Gabriela · Lina
-- =====================================================================


-- =====================================================================
-- 1. Reproducción del defecto de CONCURRENCIA
-- =====================================================================

-- Dejar la cuenta en un valor conocido (ejecutar una sola vez antes de abrir la segunda conexión)
UPDATE cuenta SET saldo = 1000000, version = 0 WHERE id_cuenta = 1001;
COMMIT;

-- [CONEXIÓN A]
SELECT saldo FROM cuenta WHERE id_cuenta = 1001;         -- 1.000.000
UPDATE cuenta SET saldo = 700000 WHERE id_cuenta = 1001;  -- No confirmar todavía

-- [CONEXIÓN B] (mientras A no ha confirmado)
SELECT saldo FROM cuenta WHERE id_cuenta = 1001;         -- También lee 1.000.000
UPDATE cuenta SET saldo = 800000 WHERE id_cuenta = 1001;  -- Espera el lock de A

-- [CONEXIÓN A]
COMMIT;                                                  -- Libera el lock y destraba B

-- [CONEXIÓN B]
COMMIT;
SELECT saldo FROM cuenta WHERE id_cuenta = 1001;
-- Resultado: Queda en 800.000 (se pierden los cambios de A por concurrencia no controlada).


-- =====================================================================
-- 2. Reproducción del defecto de TRANSACCIONALIDAD
-- =====================================================================

UPDATE cuenta SET saldo = 1000000, version = 0 WHERE id_cuenta IN (1001, 1002);
UPDATE transferencia SET estado = 'REGISTRADA' WHERE id_transferencia = 950001;
COMMIT;

-- 1. Débito del origen: se ejecuta y confirma
UPDATE cuenta SET saldo = 700000 WHERE id_cuenta = 1001;
COMMIT;

-- 2. Simulación de falla: el proceso se cae antes de acreditar el destino

SELECT id_cuenta, saldo FROM cuenta WHERE id_cuenta IN (1001, 1002) ORDER BY id_cuenta;
-- Resultado: 1001 queda en 700.000 y 1002 sigue en 1.000.000 (dinero desaparecido).


-- =====================================================================
-- 3. Secuencia Corregida (Reemplaza la Pieza 1 original)
-- =====================================================================

UPDATE cuenta SET saldo = 1000000, version = 0 WHERE id_cuenta IN (1001, 1002);
UPDATE transferencia SET estado = 'REGISTRADA' WHERE id_transferencia = 950001;
COMMIT;

-- 1. Bloquear las dos cuentas ordenadas por id_cuenta para evitar interbloqueos
SELECT id_cuenta, saldo
  FROM cuenta
 WHERE id_cuenta IN (1001, 1002)
 ORDER BY id_cuenta
   FOR UPDATE;

-- 2. Débito del origen sobre el valor actual
UPDATE cuenta
   SET saldo   = saldo - 300000,
       version = version + 1
 WHERE id_cuenta = 1001;

-- 3. Crédito del destino sobre el valor actual
UPDATE cuenta
   SET saldo   = saldo + 300000,
       version = version + 1
 WHERE id_cuenta = 1002;

-- 4. Inserción de movimientos contables
INSERT INTO movimiento (id_movimiento, id_cuenta, id_transferencia, fecha_mov, tipo, valor)
VALUES (9500001, 1001, 950001, SYSDATE, 'DEBITO', 300000);

INSERT INTO movimiento (id_movimiento, id_cuenta, id_transferencia, fecha_mov, tipo, valor)
VALUES (9500002, 1002, 950001, SYSDATE, 'CREDITO', 300000);

-- 5. Cambiar el estado de la transferencia condicionado
UPDATE transferencia
   SET estado = 'APLICADA'
 WHERE id_transferencia = 950001
   AND estado = 'REGISTRADA';

-- 6. Confirmación atómica
COMMIT;

SELECT id_cuenta, saldo FROM cuenta WHERE id_cuenta IN (1001, 1002) ORDER BY id_cuenta;


-- =====================================================================
-- 4. Demostración cruzada: Dos transferencias simultáneas sin deadlock
-- =====================================================================

UPDATE cuenta SET saldo = 1000000, version = 0 WHERE id_cuenta IN (1001, 1002);
COMMIT;

-- [CONEXIÓN A — Transferencia 1001 -> 1002]
SELECT id_cuenta, saldo
  FROM cuenta
 WHERE id_cuenta IN (1001, 1002)
 ORDER BY id_cuenta
   FOR UPDATE;

UPDATE cuenta SET saldo = saldo - 50000, version = version + 1 WHERE id_cuenta = 1001;
UPDATE cuenta SET saldo = saldo + 50000, version = version + 1 WHERE id_cuenta = 1002;
COMMIT;

-- [CONEXIÓN B — Transferencia inversa 1002 -> 1001 (en paralelo)]
SELECT id_cuenta, saldo
  FROM cuenta
 WHERE id_cuenta IN (1001, 1002)
 ORDER BY id_cuenta
   FOR UPDATE;

UPDATE cuenta SET saldo = saldo - 50000, version = version + 1 WHERE id_cuenta = 1002;
UPDATE cuenta SET saldo = saldo + 50000, version = version + 1 WHERE id_cuenta = 1001;
COMMIT;

SELECT id_cuenta, saldo FROM cuenta WHERE id_cuenta IN (1001, 1002) ORDER BY id_cuenta;


-- =====================================================================
-- 5. Optimización de la consulta del tablero (Parte C)
-- =====================================================================

-- Plan ANTES (con función TO_CHAR que invalida el índice)
EXPLAIN PLAN FOR
SELECT s.ciudad,
       COUNT(DISTINCT t.id_transferencia) AS operaciones,
       ROUND(SUM(t.valor))               AS valor_total,
       ROUND(AVG(t.valor))               AS ticket
  FROM transferencia t
  JOIN cuenta        c ON c.id_cuenta   = t.cuenta_origen
  JOIN sucursal      s ON s.id_sucursal = c.id_sucursal
 WHERE TO_CHAR(t.fecha_transf, 'YYYY-MM') = '2026-03'
   AND t.estado = 'APLICADA'
 GROUP BY s.ciudad
 ORDER BY valor_total DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS'));


-- Consulta reescrita y optimizada (rango sargable para usar el índice)
SELECT s.ciudad,
       COUNT(DISTINCT t.id_transferencia) AS operaciones,
       ROUND(SUM(t.valor))               AS valor_total,
       ROUND(AVG(t.valor))               AS ticket
  FROM transferencia t
  JOIN cuenta        c ON c.id_cuenta   = t.cuenta_origen
  JOIN sucursal      s ON s.id_sucursal = c.id_sucursal
 WHERE t.fecha_transf >= DATE '2026-03-01'
   AND t.fecha_transf <  DATE '2026-04-01'
   AND t.estado        = 'APLICADA'
 GROUP BY s.ciudad
 ORDER BY valor_total DESC;


-- Plan DESPUÉS
EXPLAIN PLAN FOR
SELECT s.ciudad,
       COUNT(DISTINCT t.id_transferencia) AS operaciones,
       ROUND(SUM(t.valor))               AS valor_total,
       ROUND(AVG(t.valor))               AS ticket
  FROM transferencia t
  JOIN cuenta        c ON c.id_cuenta   = t.cuenta_origen
  JOIN sucursal      s ON s.id_sucursal = c.id_sucursal
 WHERE t.fecha_transf >= DATE '2026-03-01'
   AND t.fecha_transf <  DATE '2026-04-01'
   AND t.estado        = 'APLICADA'
 GROUP BY s.ciudad
 ORDER BY valor_total DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS'));