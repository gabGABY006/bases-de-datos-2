/*
LABORATORIO COMPLETO: COLUMNAS VIRTUALES E ÍNDICES EN ORACLE (ESQUEMA HR)
*/

-- PASO 1: Crear Columnas Virtuales en la tabla EMPLOYEES
-- Explicación: Agregamos 'full_name' (concatenación) y 'total_annual_comp' 
-- (cálculo numérico considerando comisión).

ALTER TABLE employees ADD (
    full_name VARCHAR2(100) 
        GENERATED ALWAYS AS (first_name || ' ' || last_name) VIRTUAL,
        
    total_annual_comp NUMBER(12,2) 
        GENERATED ALWAYS AS (salary * 12 * (1 + NVL(commission_pct, 0))) VIRTUAL
);

-- [VERIFICACIÓN 1.A]: Verificar en el diccionario de datos que son VIRTUAL
SELECT column_name, data_type, data_default, virtual_column
FROM user_tab_cols
WHERE table_name = 'EMPLOYEES' 
  AND column_name IN ('FULL_NAME', 'TOTAL_ANNUAL_COMP');

-- [VERIFICACIÓN 1.B]: Consultar los datos calculados en tiempo real
SELECT employee_id, full_name, salary, commission_pct, total_annual_comp
FROM employees
WHERE department_id = 80;


-- PASO 2: Probar la inmutabilidad DML (Intento de INSERT directo)
-- Explicación: Las columnas virtuales son de solo lectura. Este comando 
-- fallará intencionalmente con el error ORA-50102.
/* 
-- Descomenta este bloque para probar el error de inserción:
INSERT INTO employees (
    employee_id, first_name, last_name, email, hire_date, job_id, salary, full_name
) VALUES (
    9999, 'Laura', 'Gómez', 'LGOMEZ_TEST', SYSDATE, 'IT_PROG', 6000, 'Laura Gómez'
);
-- RESULTADO ESPERADO: ORA-50102: virtual column is not allowed here
*/


-- PASO 3: Expresiones Determinísticas vs. No Determinísticas (Caso SYSDATE)
-- Explicación: Una columna virtual NO permite funciones cambiantes como SYSDATE.

/* 
-- Descomenta esta línea para ver el error al usar SYSDATE:
ALTER TABLE employees ADD (
    anos_trabajados NUMBER GENERATED ALWAYS AS (TRUNC(MONTHS_BETWEEN(SYSDATE, hire_date)/12)) VIRTUAL
);
-- RESULTADO ESPERADO: ORA-54002: Virtual column expression is based on an expression containing SYSDATE
*/

-- SOLUCIÓN CORRECTA: Usar una función determinística basada en columnas fijas
ALTER TABLE employees ADD (
    hire_year NUMBER(4) 
        GENERATED ALWAYS AS (EXTRACT(YEAR FROM hire_date)) VIRTUAL
);


-- PASO 4: Indexación de la Columna Virtual y Análisis del Plan de Ejecución
-- Explicación: Comparamos el costo del motor antes y después de crear 
-- un índice B-tree sobre la columna virtual 'full_name'.

-- A) Generar Plan de Ejecución SIN ÍNDICE (Debe mostrar TABLE ACCESS FULL):
EXPLAIN PLAN FOR
SELECT employee_id, salary, total_annual_comp 
FROM employees 
WHERE full_name = 'Steven King';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- B) Crear el índice B-tree sobre la columna virtual:
CREATE INDEX idx_emp_full_name ON employees(full_name);

-- C) Generar Plan de Ejecución CON ÍNDICE (Debe cambiar a INDEX RANGE SCAN):
EXPLAIN PLAN FOR
SELECT employee_id, salary, total_annual_comp 
FROM employees 
WHERE full_name = 'Steven King';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);



-- PASO 5: Aplicar Restricciones de Integridad (Constraints)
-- Explicación: Agregamos una regla CHECK directamente a la columna virtual.

ALTER TABLE employees ADD CONSTRAINT chk_min_annual_comp 
    CHECK (total_annual_comp > 0);



-- PASO 6: LIMPIEZA Y RESTAURACIÓN DE LA TABLA (Teardown)
-- Explicación: Ejecuta estas sentencias al finalizar el laboratorio para 
-- dejar la tabla EMPLOYEES exactamente en su estado inicial original.

-- 1. Eliminar la restricción CHECK creada en el Paso 5:
ALTER TABLE employees DROP CONSTRAINT chk_min_annual_comp;

-- 2. Eliminar el índice B-tree creado en el Paso 4:
DROP INDEX idx_emp_full_name;

-- 3. Eliminar las tres columnas virtuales creadas en los Pasos 1 y 3:
ALTER TABLE employees DROP (full_name, total_annual_comp, hire_year);

-- [VERIFICACIÓN FINAL]: Confirmar que la tabla volvió a su estado inicial
SELECT column_name, data_type, virtual_column 
FROM user_tab_cols 
WHERE table_name = 'EMPLOYEES';