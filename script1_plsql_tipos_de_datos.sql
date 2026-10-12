/* =====================================================================
   PL/SQL — Tipos de datos y bloques anónimos
   Script 1

   Autor: Gabriella Castro
   Fecha: 22/09/2026
   Descripción: primer script de práctica en PL/SQL. Cubre la sintaxis
   básica de un bloque, DBMS_OUTPUT, variables declaradas a mano,
   el estándar de tipos de datos del curso, atributos de tipo (%TYPE)
   y filas completas (%ROWTYPE).

   v.1 - 23/09/2026  Cambio el mensaje de salida
   v.2
   ===================================================================== */

/*
Clausulas obligatorias en PL/SQL:
  BEGIN
  .
  .
  END;
para iniciar y terminar código.

Clausula opcional: DECLARE
Todo lo que va entre el DECLARE y el BEGIN es para declarar variables,
constantes, etc.

En medio del código también podemos poner EXCEPTION.

Importante: DBMS_OUTPUT.PUT_LINE('Hola mundo') -> tiene que ser con
comillas simples (es como el System.out.println de Java).

SET SERVEROUTPUT ON  -> habilita la impresión en consola.
*/

SET SERVEROUTPUT ON;


-- =====================================================================
-- 1. La clásica de "Hola Mundo"
-- =====================================================================
BEGIN
  DBMS_OUTPUT.PUT_LINE('Hola mundo');
END;
/


-- =====================================================================
-- 2. Variables
--    Convención del curso: vv (varchar), vd (fecha), vn (número),
--    vb (booleano), vc (char) — en CamelCase (ej: vvPrimerNombre).
-- =====================================================================
DECLARE
  vvTexto VARCHAR2(50);
BEGIN
  vvTexto := 'Hola soy yo';
  DBMS_OUTPUT.PUT_LINE(vvTexto);
END;
/


-- =====================================================================
-- 3. Estándar de tipos de datos del curso
--    Un ejemplo de cada prefijo, con el tipo de dato real de Oracle
--    que le corresponde.
-- =====================================================================
DECLARE
  -- vv -> VARCHAR2: texto de longitud variable (hasta el máximo declarado)
  vvNombre    VARCHAR2(50) := 'Gabriela';

  -- vc -> CHAR: texto de longitud FIJA (se rellena con espacios a la derecha)
  vcGenero    CHAR(1)      := 'F';

  -- vn -> NUMBER: números, con o sin decimales. NUMBER(precisión, escala)
  vnEdad      NUMBER(3)    := 21;
  vnPromedio  NUMBER(4,2)  := 4.35;

  -- vd -> DATE: fecha y hora (día, mes, año, hora, minuto, segundo)
  vdHoy       DATE         := SYSDATE;

  -- vb -> BOOLEAN: TRUE, FALSE o NULL. No se puede seleccionar en una
  --       consulta SQL ni imprimir directo con DBMS_OUTPUT, solo se usa
  --       dentro de la lógica PL/SQL (IF, WHILE, etc.)
  vbActivo    BOOLEAN      := TRUE;
BEGIN
  DBMS_OUTPUT.PUT_LINE('vv (VARCHAR2) -> ' || vvNombre);
  DBMS_OUTPUT.PUT_LINE('vc (CHAR)     -> ' || vcGenero);
  DBMS_OUTPUT.PUT_LINE('vn (NUMBER)   -> edad: ' || TO_CHAR(vnEdad) ||
                        ', promedio: ' || TO_CHAR(vnPromedio));
  DBMS_OUTPUT.PUT_LINE('vd (DATE)     -> ' || TO_CHAR(vdHoy, 'DD-MM-YYYY HH24:MI:SS'));

  -- Un BOOLEAN no se puede concatenar ni imprimir directamente:
  -- hay que convertirlo con un IF, porque no existe TO_CHAR(BOOLEAN).
  IF vbActivo THEN
    DBMS_OUTPUT.PUT_LINE('vb (BOOLEAN)  -> TRUE');
  ELSE
    DBMS_OUTPUT.PUT_LINE('vb (BOOLEAN)  -> FALSE');
  END IF;
END;
/


-- =====================================================================
-- 4. Atributos de tipo (%TYPE)
--    En vez de declarar el tipo "a mano", se hereda el tipo exacto
--    de la columna real de la tabla — así si la columna cambia de
--    tipo algún día, la variable se actualiza sola.
-- =====================================================================
DECLARE
  -- vvNombre   VARCHAR2(50);
  vvNombre     EMPLOYEES.FIRST_NAME%TYPE;
  -- vvApellido VARCHAR2(50);
  vvApellido   EMPLOYEES.LAST_NAME%TYPE;
  -- vnSalario  NUMBER;
  vnSalario    EMPLOYEES.SALARY%TYPE;
  -- vdFecha    DATE;
  vdFecha      EMPLOYEES.HIRE_DATE%TYPE;
BEGIN
  SELECT FIRST_NAME,
         LAST_NAME,
         SALARY,
         HIRE_DATE
    INTO vvNombre,
         vvApellido,
         vnSalario,
         vdFecha
    FROM EMPLOYEES
   WHERE EMPLOYEE_ID = 100;

  DBMS_OUTPUT.PUT_LINE('El empleado se llama ' || vvNombre || ' ' || vvApellido ||
    ' ,tiene un salario de ' || TO_CHAR(vnSalario) || ' y fue contratado en: ' ||
    TO_CHAR(vdFecha, 'DD-MM-YYYY'));
END;
/


-- =====================================================================
-- 5. %ROWTYPE
--    Escoge la fila completa de la tabla en vez de declarar los
--    atributos uno por uno.
-- =====================================================================
DECLARE
  vrEmpleado EMPLOYEES%ROWTYPE;
BEGIN
  SELECT *
    INTO vrEmpleado
    FROM EMPLOYEES
   WHERE EMPLOYEE_ID = 100;

  DBMS_OUTPUT.PUT_LINE('El empleado es: ' || vrEmpleado.first_name);
END;
/


/*
Nota:
  DBMS_OUTPUT.PUT_LINE
  DBMS_OUTPUT -> Package
  PUT_LINE    -> procedimiento almacenado (dentro del package)
*/


-- =====================================================================
-- Pendientes (autonota)
-- =====================================================================
-- TAREA 1: revisar todos los paquetes (packages) de PL/SQL.
-- TAREA 2: revisar la documentación de PL/SQL para practicar más.
