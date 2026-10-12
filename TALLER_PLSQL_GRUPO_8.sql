--------------------------------------------------------------------------------
-- UNIVERSIDAD EL BOSQUE — INGENIERIA DE SISTEMAS
-- Asignatura: Bases de Datos 2
-- Docente: Ing., Esp., M.Ed. Christian Felipe Duarte
--
-- TALLER PL/SQL — PLANTILLA DE ENTREGA
--
-- GRUPO No.: 8
-- INTEGRANTES: 1) Gabriella Castro
--              2) Julián Rodríguez
--              3) Lina Patiño
-- FECHA DE ENTREGA: 3 de octubre de 2026
--------------------------------------------------------------------------------
--
-- COMO TRABAJAR
--   1. Ejecute primero, completo, el script 01_esquema_inventario.sql
--   2. Desarrolle cada punto en la seccion correspondiente de este archivo
--   3. No borre los encabezados de cada ejercicio ni cambie los nombres de los
--      objetos solicitados. La revision los busca por nombre: un objeto correcto
--      con otro nombre se califica como no entregado.
--   4. Los esqueletos de la Parte 5 no incluyen la clausula de disparo. Definirla
--      hace parte del ejercicio, de modo que esos bloques no compilan tal como se
--      entregan.
--
-- DISTRIBUCION DEL PUNTAJE                                     Total: 50 puntos
--   Parte 1  Procedimientos almacenados .................  8 puntos
--   Parte 2  Funciones ...................................  8 puntos
--   Parte 3  Cursores .................................... 10 puntos
--   Parte 4  Manejo de excepciones .......................  9 puntos
--   Parte 5  Disparadores ................................ 10 puntos
--   Parte 6  Caso integrador .............................  5 puntos
--
-- CRITERIOS DE EVALUACION
--   Correccion tecnica ....... 40%   El objeto compila y cumple el enunciado
--   Justificacion ............ 40%   Las decisiones de diseno estan argumentadas
--   Analisis operacional ..... 20%   Se anticipa el comportamiento ante
--                                    concurrencia, volumen y error
--
--   Cada objeto debe incluir su justificacion en el espacio marcado. Un ejercicio
--   sin justificacion obtiene como maximo el 40% de su puntaje aunque funcione.
--   Una justificacion que confunde la causa con el efecto no obtiene puntaje.
--   Describir lo que hace el codigo, sin argumentar por que se eligio esa
--   construccion y no otra, equivale a no justificar.
--
-- ENTREGA
--   Este archivo renombrado como TALLER_PLSQL_GRUPO_<n>.sql, junto con un
--   documento que contenga las salidas de DBMS_OUTPUT de cada bloque ejecutado.
--   Ambos archivos deben incluir los nombres de los tres integrantes.
--
-- SUSTENTACION
--   20 minutos por grupo. Los tres integrantes deben poder explicar cualquier
--   parte del codigo, no solamente la que desarrollaron.
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED

--==============================================================================
-- PARTE 1 — PROCEDIMIENTOS ALMACENADOS                        (8 puntos / 75 min)
--==============================================================================

------------------------------------------------------------------- 1.1 (2 pts)
-- SP_REGISTRAR_PRODUCTO
-- Registra un producto nuevo. Debe asignar el identificador desde SEQ_PRODUCTO,
-- validar que el precio de venta supere el costo unitario, verificar que la
-- categoria exista y manejar el caso de codigo duplicado. Devuelve el
-- identificador generado.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Gabriella Castro
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Procedimiento para registrar un nuevo producto validando costos,
--              existencia de categoría y controlando códigos duplicados.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Se usa SEQ_PRODUCTO.NEXTVAL porque el identificador debe generarse desde la
-- secuencia definida por el esquema y asi se evita depender de un MAX(id).
-- La validacion precio > costo se hace antes del INSERT para rechazar datos que
-- violen la regla del negocio con un mensaje claro. La categoria se consulta
-- explicitamente para distinguir una categoria inexistente de otros errores.
-- Finalmente, DUP_VAL_ON_INDEX permite convertir un codigo duplicado en un
-- error de negocio controlado, aprovechando que CODIGO tiene restriccion UNIQUE.
CREATE OR REPLACE PROCEDURE SP_REGISTRAR_PRODUCTO (
    p_codigo        IN  VARCHAR2,
    p_nombre        IN  VARCHAR2,
    p_id_categoria  IN  NUMBER,
    p_precio        IN  NUMBER,
    p_costo         IN  NUMBER,
    p_stock_minimo  IN  NUMBER DEFAULT 0,
    p_id_producto   OUT NUMBER
) IS
    V_categoria NUMBER;
BEGIN
    IF p_precio <= p_costo THEN
        RAISE_APPLICATION_ERROR(-20001,
            'El precio de venta debe ser mayor que el costo unitario');
    END IF;

    BEGIN
        SELECT id_categoria
        INTO V_categoria
        FROM CATEGORIA
        WHERE id_categoria = p_id_categoria;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002,
                'La categoria indicada no existe');
    END;

    p_id_producto := SEQ_PRODUCTO.NEXTVAL;

    INSERT INTO PRODUCTO (
        id_producto, codigo, nombre, id_categoria,
        precio_unitario, costo_unitario, stock_minimo, activo
    ) VALUES (
        p_id_producto, p_codigo, p_nombre, p_id_categoria,
        p_precio, p_costo, p_stock_minimo, 'S'
    );
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20003,
            'El codigo de producto ya existe');
END SP_REGISTRAR_PRODUCTO;
/

------------------------------------------------------------------- 1.2 (3 pts)
-- SP_AJUSTAR_STOCK
-- Registra una ENTRADA, SALIDA o AJUSTE de inventario sobre una bodega.
-- Debe actualizar EXISTENCIA e insertar el registro en MOVIMIENTO_INVENTARIO,
-- devolviendo el saldo resultante.
--   * Si la combinacion bodega-producto no existe y el tipo es ENTRADA, crearla
--   * Si el tipo es SALIDA y no existe la combinacion, rechazar la operacion
--   * Una SALIDA nunca puede dejar la existencia en negativo
-- Proteja la lectura de la existencia frente a modificaciones concurrentes.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Gabriella Castro
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Procedimiento para ajustar el stock de inventario por bodega
--              registrando entradas, salidas o ajustes de forma concurrente y segura.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
-- La existencia se consulta con FOR UPDATE para bloquear la fila mientras se
-- calcula y actualiza el nuevo saldo; esto evita que dos sesiones concurrentes
-- lean el mismo saldo y terminen sobrescribiendo cambios. ENTRADA puede crear la
-- combinacion faltante, mientras SALIDA la rechaza porque no existe stock que
-- descontar. La SALIDA se valida antes de restar para garantizar que nunca se
-- produzca una existencia negativa. El movimiento se registra en la misma
-- transaccion que la actualizacion de EXISTENCIA para mantener consistencia.
CREATE OR REPLACE PROCEDURE SP_AJUSTAR_STOCK (
    p_id_producto  IN  NUMBER,
    p_id_bodega    IN  NUMBER,
    p_tipo         IN  VARCHAR2,
    p_cantidad     IN  NUMBER,
    p_observacion  IN  VARCHAR2 DEFAULT NULL,
    p_saldo_final  OUT NUMBER
) IS
    V_cantidad EXISTENCIA.cantidad%TYPE;
    VV_tipo    VARCHAR2(10) := UPPER(TRIM(p_tipo));
BEGIN
    IF p_cantidad <= 0 THEN
        RAISE_APPLICATION_ERROR(-20004,
            'La cantidad debe ser mayor que cero');
    END IF;

    IF VV_tipo NOT IN ('ENTRADA', 'SALIDA', 'AJUSTE') THEN
        RAISE_APPLICATION_ERROR(-20005,
            'El tipo debe ser ENTRADA, SALIDA o AJUSTE');
    END IF;

    BEGIN
        SELECT cantidad
        INTO V_cantidad
        FROM EXISTENCIA
        WHERE id_bodega = p_id_bodega
          AND id_producto = p_id_producto
        FOR UPDATE;

        IF VV_tipo = 'ENTRADA' THEN
            V_cantidad := V_cantidad + p_cantidad;
        ELSIF VV_tipo = 'SALIDA' THEN
            IF V_cantidad < p_cantidad THEN
                RAISE_APPLICATION_ERROR(-20006,
                    'La SALIDA supera la existencia disponible');
            END IF;
            V_cantidad := V_cantidad - p_cantidad;
        ELSE
            V_cantidad := V_cantidad + p_cantidad;
        END IF;

        UPDATE EXISTENCIA
        SET cantidad = V_cantidad
        WHERE id_bodega = p_id_bodega
          AND id_producto = p_id_producto;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            IF VV_tipo = 'ENTRADA' THEN
                INSERT INTO EXISTENCIA (id_bodega, id_producto, cantidad)
                VALUES (p_id_bodega, p_id_producto, p_cantidad);
                V_cantidad := p_cantidad;
            ELSE
                RAISE_APPLICATION_ERROR(-20007,
                    'No existe la combinacion bodega-producto');
            END IF;
    END;

    INSERT INTO MOVIMIENTO_INVENTARIO (
        id_movimiento, id_producto, id_bodega, tipo, cantidad,
        fecha_mov, id_pedido, observacion
    ) VALUES (
        SEQ_MOVIMIENTO.NEXTVAL, p_id_producto, p_id_bodega, VV_tipo,
        p_cantidad, SYSDATE, NULL, p_observacion
    );

    p_saldo_final := V_cantidad;
END SP_AJUSTAR_STOCK;
/

------------------------------------------------------------------- 1.3 (3 pts)
-- SP_CREAR_PEDIDO
-- Crea la cabecera de un pedido en estado BORRADOR y devuelve el identificador
-- generado. Debe rechazar clientes inactivos y clientes sin cupo de credito
-- disponible, con mensajes distinguibles entre si.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Gabriella Castro
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Procedimiento para crear la cabecera de un pedido en estado BORRADOR
--              validando el estado y el cupo de crédito disponible del cliente.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Primero se consulta el cliente para conocer su estado. Un cliente inactivo se
-- rechaza antes de crear el pedido. Para el cupo se reutiliza FN_CUPO_DISPONIBLE,
-- evitando duplicar la formula del credito y dejando una sola fuente de verdad.
-- El pedido se crea como BORRADOR porque en este punto solo se registra la
-- cabecera; la facturacion/confirmacion pertenece al proceso posterior. Los
-- mensajes usan errores distintos para que el consumidor pueda identificar la
-- causa del rechazo.
CREATE OR REPLACE PROCEDURE SP_CREAR_PEDIDO (
    p_id_cliente  IN  NUMBER,
    p_id_pedido   OUT NUMBER
) IS
    VC_activo CLIENTE.activo%TYPE;
    V_cupo    NUMBER;
BEGIN
    BEGIN
        SELECT activo
        INTO VC_activo
        FROM CLIENTE
        WHERE id_cliente = p_id_cliente;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20010,
                'El cliente no existe');
    END;

    IF VC_activo <> 'S' THEN
        RAISE_APPLICATION_ERROR(-20008,
            'El cliente esta inactivo');
    END IF;

    V_cupo := FN_CUPO_DISPONIBLE(p_id_cliente);

    IF V_cupo <= 0 THEN
        RAISE_APPLICATION_ERROR(-20009,
            'El cliente no tiene cupo de credito disponible');
    END IF;

    p_id_pedido := SEQ_PEDIDO.NEXTVAL;

    INSERT INTO PEDIDO (
        id_pedido, id_cliente, fecha_pedido, estado, total
    ) VALUES (
        p_id_pedido, p_id_cliente, SYSDATE, 'BORRADOR', 0
    );
END SP_CREAR_PEDIDO;
/


--==============================================================================
-- PARTE 2 — FUNCIONES                                         (8 puntos / 75 min)
--==============================================================================

------------------------------------------------------------------- 2.1 (2 pts)
-- FN_STOCK_DISPONIBLE
-- Retorna la cantidad disponible de un producto. Si se indica bodega, devuelve
-- el saldo de esa bodega; si p_id_bodega llega nulo, el consolidado de todas.
-- Un producto inexistente debe retornar cero y no una excepcion.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Gabriella Castro
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Función para consultar la existencia disponible de un producto
--              por bodega específica o de forma consolidada.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
-- SUM permite obtener tanto el saldo de una bodega concreta como el consolidado
-- cuando no se especifica bodega. NVL convierte el resultado NULL de un SUM sin
-- filas en cero, por lo que un producto inexistente no genera NO_DATA_FOUND ni
-- otra excepcion. La condicion de bodega se formula con una expresion OR para
-- conservar una sola funcion con ambos comportamientos.
CREATE OR REPLACE FUNCTION FN_STOCK_DISPONIBLE (
    p_id_producto IN NUMBER,
    p_id_bodega   IN NUMBER DEFAULT NULL
) RETURN NUMBER IS
    V_stock NUMBER;
BEGIN
    SELECT NVL(SUM(cantidad), 0)
    INTO V_stock
    FROM EXISTENCIA
    WHERE id_producto = p_id_producto
      AND (p_id_bodega IS NULL OR id_bodega = p_id_bodega);

    RETURN V_stock;
END FN_STOCK_DISPONIBLE;
/

------------------------------------------------------------------- 2.2 (2 pts)
-- FN_CUPO_DISPONIBLE
-- Retorna el cupo de credito disponible del cliente, entendido como cupo menos
-- saldo pendiente. Un cliente inactivo retorna cero y el resultado nunca puede
-- ser negativo.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Gabriella Castro
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Función que calcula el cupo de crédito disponible de un cliente
--              restando el saldo pendiente de su cupo total autorizado.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
-- El cupo disponible representa la diferencia entre el limite de credito y el
-- saldo pendiente. Se consulta tambien el estado porque un cliente inactivo no
-- debe conservar capacidad de compra. GREATEST(...,0) garantiza que nunca se
-- entregue un valor negativo cuando el saldo pendiente supera el cupo. Si el
-- cliente no existe, se retorna cero para que la funcion sea segura para su uso
-- en consultas y en otras rutinas del taller.
CREATE OR REPLACE FUNCTION FN_CUPO_DISPONIBLE (
    p_id_cliente IN NUMBER
) RETURN NUMBER IS
    V_cupo    CLIENTE.cupo_credito%TYPE;
    V_saldo   CLIENTE.saldo_pendiente%TYPE;
    VC_activo CLIENTE.activo%TYPE;
BEGIN
    BEGIN
        SELECT cupo_credito, saldo_pendiente, activo
        INTO V_cupo, V_saldo, VC_activo
        FROM CLIENTE
        WHERE id_cliente = p_id_cliente;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0;
    END;

    IF VC_activo <> 'S' THEN
        RETURN 0;
    END IF;

    RETURN GREATEST(V_cupo - V_saldo, 0);
END FN_CUPO_DISPONIBLE;
/

------------------------------------------------------------------- 2.3 (3 pts)
-- FN_CALCULAR_DESCUENTO
-- Retorna el VALOR en pesos del descuento aplicable, segun estas reglas
-- acumulables:
--     Monto mayor o igual a 2.000.000 ................. 8%
--     Monto entre 800.000 y 1.999.999 ................. 5%
--     Monto menor a 800.000 ........................... 0%
--     Adicional si el cliente no tiene saldo pendiente . 2%
--     Tope maximo acumulado ........................... 10%
-- La funcion retorna el valor del descuento, no el porcentaje.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Gabriella Castro
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Función que calcula el valor monetario del descuento aplicable
--              basado en reglas acumulables por monto y estado del saldo del cliente.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Primero se determina el porcentaje base segun el monto y despues se suma el
-- beneficio de 2% cuando el cliente no tiene saldo pendiente. LEAST limita el
-- porcentaje acumulado a 10%, y al final se multiplica por el monto para retornar
-- dinero, no el porcentaje. La consulta del cliente se maneja con NO_DATA_FOUND
-- para que un cliente inexistente no produzca una excepcion inesperada en la
-- funcion.
CREATE OR REPLACE FUNCTION FN_CALCULAR_DESCUENTO (
    p_id_cliente IN NUMBER,
    p_monto      IN NUMBER
) RETURN NUMBER IS
    V_porcentaje NUMBER := 0;
    V_saldo      CLIENTE.saldo_pendiente%TYPE;
BEGIN
    IF p_monto IS NULL OR p_monto <= 0 THEN
        RETURN 0;
    END IF;

    IF p_monto >= 2000000 THEN
        V_porcentaje := 8;
    ELSIF p_monto >= 800000 THEN
        V_porcentaje := 5;
    ELSE
        V_porcentaje := 0;
    END IF;

    BEGIN
        SELECT saldo_pendiente
        INTO V_saldo
        FROM CLIENTE
        WHERE id_cliente = p_id_cliente;

        IF V_saldo = 0 THEN
            V_porcentaje := V_porcentaje + 2;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
    END;

    V_porcentaje := LEAST(V_porcentaje, 10);

    RETURN ROUND(p_monto * V_porcentaje / 100, 2);
END FN_CALCULAR_DESCUENTO;
/

------------------------------------------------------------------- 2.4 (1 pt)
-- Escriba una consulta que liste los clientes activos con su cupo disponible,
-- usando la funcion del punto 2.2, ordenados de mayor a menor.
-- Explique por que una funcion definida por el usuario puede invocarse desde
-- una sentencia SQL y que restriccion debe cumplir para poder hacerlo.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Gabriella Castro
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Consulta SQL para listar clientes activos con su respectivo cupo
--              disponible calculado mediante la función FN_CUPO_DISPONIBLE.
--------------------------------------------------------------------------------
-- RESPUESTA:
--
SELECT id_cliente, documento, nombre, ciudad, FN_CUPO_DISPONIBLE(id_cliente) AS cupo_disponible
FROM CLIENTE
WHERE activo = 'S'
ORDER BY cupo_disponible DESC;

-- EXPLICACIÓN:
-- 1. ¿Por qué puede invocarse desde una sentencia SQL?: 
--    Oracle permite integrar funciones definidas por el usuario dentro de sentencias SQL 
--    (en cláusulas como SELECT, WHERE u ORDER BY) para extender las capacidades nativas 
--    del lenguaje y procesar lógica de negocio o cálculos directamente sobre filas de tablas.
-- 2. Restricciones que debe cumplir: 
--    Para poder ser llamada desde una consulta SQL, la función no puede violar la consistencia 
--    de lectura ni alterar el estado de la base de datos durante la ejecución de la consulta. 
--    Específicamente, tiene prohibido ejecutar sentencias de manipulación de datos (DML como 
--    INSERT, UPDATE, DELETE), operaciones DDL (como CREATE o DROP) ni comandos de control 
--    de transacciones (COMMIT o ROLLBACK).


--==============================================================================
-- PARTE 3 — CURSORES                                         (10 puntos / 90 min)
--==============================================================================

------------------------------------------------------------------- 3.1 (2 pts)
-- Bloque anonimo que recorra, con un CURSOR EXPLICITO, los productos cuyo stock
-- consolidado este por debajo del stock minimo, e imprima un reporte con codigo,
-- nombre, stock actual, stock minimo y unidades faltantes, mas el total de
-- productos en esa condicion.
-- Debe usar OPEN, FETCH y CLOSE de forma explicita. El ciclo FOR implicito no se
-- acepta en este punto.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Julián Rodríguez
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Bloque anónimo con cursor explícito para listar productos 
--              con stock consolidado por debajo del mínimo.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
--   Use un cursor explicito con OPEN, FETCH y CLOSE, como pide el punto.
--   Uni PRODUCTO con EXISTENCIA con LEFT JOIN porque hay productos sin existencias
--   (como el 1015) y con un JOIN normal no saldrian en el reporte.
--   El filtro va en HAVING porque el stock total es un SUM, y eso solo se puede
--   filtrar despues del GROUP BY.
--   Inclui los inactivos y los marque, para no esconder informacion.
--   Si algo falla, el bloque cierra el cursor y vuelve a lanzar el error.
--   Es solo lectura, no bloquea a nadie.
SET SERVEROUTPUT ON;
DECLARE
    CURSOR c_bajo_stock IS
        SELECT p.codigo,
               p.nombre,
               NVL(SUM(e.cantidad), 0) AS stock_actual,
               p.stock_minimo,
               p.activo
        FROM   PRODUCTO p
               LEFT JOIN EXISTENCIA e ON e.id_producto = p.id_producto
        GROUP BY p.id_producto, p.codigo, p.nombre, p.stock_minimo, p.activo
        HAVING NVL(SUM(e.cantidad), 0) < p.stock_minimo
        ORDER BY p.codigo;
 
    VV_codigo PRODUCTO.codigo%TYPE;
    VV_nombre PRODUCTO.nombre%TYPE;
    V_stock   NUMBER;
    V_minimo  PRODUCTO.stock_minimo%TYPE;
    VC_activo PRODUCTO.activo%TYPE;
    V_total   PLS_INTEGER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('REPORTE: PRODUCTOS POR DEBAJO DEL STOCK MINIMO');
    DBMS_OUTPUT.PUT_LINE(RPAD('CODIGO', 10) || RPAD('NOMBRE', 34) ||
                         LPAD('ACTUAL', 8) || LPAD('MINIMO', 8) || LPAD('FALTAN', 10));
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 70, '-'));
 
    OPEN c_bajo_stock;
    LOOP
        FETCH c_bajo_stock INTO VV_codigo, VV_nombre, V_stock, V_minimo, VC_activo;
        EXIT WHEN c_bajo_stock%NOTFOUND;
 
        DBMS_OUTPUT.PUT_LINE(RPAD(VV_codigo, 10) || RPAD(VV_nombre, 34) ||
                             LPAD(V_stock, 8) || LPAD(V_minimo, 8) ||
                             LPAD(V_minimo - V_stock, 10) ||
                             CASE WHEN VC_activo = 'N' THEN '   (INACTIVO)' END);
    END LOOP;
    V_total := c_bajo_stock%ROWCOUNT;   -- se lee antes del CLOSE
    CLOSE c_bajo_stock;
 
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 70, '-'));
    DBMS_OUTPUT.PUT_LINE('Total de productos bajo el stock minimo: ' || V_total);
EXCEPTION
    WHEN OTHERS THEN
        IF c_bajo_stock%ISOPEN THEN
            CLOSE c_bajo_stock;
        END IF;
        RAISE;
END;
/

------------------------------------------------------------------- 3.2 (2 pts)
-- Bloque anonimo con un CURSOR PARAMETRIZADO que reciba identificador de cliente
-- y un rango de fechas, y muestre los pedidos CONFIRMADOS de ese cliente en ese
-- rango, con su total y la cantidad de lineas de cada pedido.
-- Pruebelo con el cliente 501 entre 2026-01-01 y 2026-12-31.
-- Los parametros deben declararse en el cursor, no tomarse del alcance del bloque.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Julián Rodríguez
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Bloque anónimo con cursor parametrizado para mostrar pedidos 
--              confirmados de un cliente en un rango de fechas.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
--   Los parametros (cliente, desde, hasta) estan declarados en el cursor, asi se
--   puede reutilizar con otro cliente o con otras fechas.
--   El filtro usa fecha < hasta + 1 para que entre todo el dia 31, aunque tenga hora.
--   Solo cuenta los pedidos CONFIRMADO, por eso el pedido 6 no sale.
--   Las lineas se cuentan con LEFT JOIN y COUNT.
--   Es solo lectura. Si hubiera muchos pedidos ayudaria un indice en
--   PEDIDO(id_cliente, fecha_pedido).
DECLARE
    CURSOR c_pedidos (p_id_cliente NUMBER, p_desde DATE, p_hasta DATE) IS
        SELECT pe.id_pedido,
               pe.fecha_pedido,
               pe.total,
               COUNT(d.linea) AS num_lineas
        FROM   PEDIDO pe
               LEFT JOIN DETALLE_PEDIDO d ON d.id_pedido = pe.id_pedido
        WHERE  pe.id_cliente   = p_id_cliente
        AND    pe.estado       = 'CONFIRMADO'
        AND    pe.fecha_pedido >= p_desde
        AND    pe.fecha_pedido <  p_hasta + 1
        GROUP BY pe.id_pedido, pe.fecha_pedido, pe.total
        ORDER BY pe.fecha_pedido, pe.id_pedido;
 
    V_cuenta PLS_INTEGER := 0;
    V_suma   NUMBER      := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('PEDIDOS CONFIRMADOS DEL CLIENTE 501 EN 2026');
    DBMS_OUTPUT.PUT_LINE(RPAD('PEDIDO', 10) || RPAD('FECHA', 14) ||
                         LPAD('TOTAL', 14) || LPAD('LINEAS', 8));
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 46, '-'));
 
    FOR r IN c_pedidos(501, DATE '2026-01-01', DATE '2026-12-31') LOOP
        V_cuenta := V_cuenta + 1;
        V_suma   := V_suma + r.total;
        DBMS_OUTPUT.PUT_LINE(RPAD(r.id_pedido, 10) ||
                             RPAD(TO_CHAR(r.fecha_pedido, 'YYYY-MM-DD'), 14) ||
                             LPAD(TO_CHAR(r.total, 'FM999G999G999G990'), 14) ||
                             LPAD(r.num_lineas, 8));
    END LOOP;
 
    IF V_cuenta = 0 THEN
        DBMS_OUTPUT.PUT_LINE('El cliente no tiene pedidos confirmados en ese rango.');
    ELSE
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 46, '-'));
        DBMS_OUTPUT.PUT_LINE('Pedidos: ' || V_cuenta ||
                             '     Suma de totales: ' || TO_CHAR(V_suma, 'FM999G999G999G990'));
    END IF;
END;
/

------------------------------------------------------------------- 3.3 (3 pts)
-- Bloque anonimo con un CURSOR FOR UPDATE que recorra los productos de una
-- categoria y ajuste su precio un porcentaje dado, usando WHERE CURRENT OF.
--   * No debe modificar productos inactivos
--   * El precio resultante no puede quedar por debajo del costo mas el margen
--     minimo de la categoria
-- Explique que bloqueo genera FOR UPDATE, cuanto dura, y por que WHERE CURRENT OF
-- es preferible a un UPDATE por clave primaria.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Julián Rodríguez
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Bloque anónimo con cursor FOR UPDATE para ajustar precios 
--              de productos de una categoría usando WHERE CURRENT OF.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
--   FOR UPDATE bloquea las filas de PRODUCTO que trae el cursor (bloqueo de fila),
--   desde el OPEN hasta el COMMIT o ROLLBACK. Otras sesiones pueden leerlas pero
--   no modificarlas. Puse OF precio_unitario para no bloquear tambien CATEGORIA.
--   WHERE CURRENT OF es mejor que un UPDATE por clave primaria porque modifica la
--   fila que el cursor ya leyo y bloqueo, sin buscarla otra vez.
--   Los inactivos se filtran en el cursor, asi ni se tocan ni se bloquean.
--   El margen se valida antes del UPDATE (costo * (1 + margen/100)) para omitir el
--   producto con un mensaje, y no dejar que el trigger de error y pare todo.
--   No hice COMMIT dentro del ciclo porque libera los bloqueos y el cursor falla.
--   Con WAIT 5 no se queda esperando para siempre si otra sesion tiene la fila.
--   Termina con ROLLBACK para no cambiar los datos de prueba.
DECLARE
    V_id_categoria NUMBER := 1;       -- 1 = Herramienta manual (margen 25%)
    V_pct          NUMBER := -22;     -- variacion porcentual a aplicar
 
    CURSOR c_prod (p_id_categoria NUMBER) IS
        SELECT p.id_producto,
               p.codigo,
               p.precio_unitario,
               p.costo_unitario,
               c.margen_minimo
        FROM   PRODUCTO p
               JOIN CATEGORIA c ON c.id_categoria = p.id_categoria
        WHERE  p.id_categoria = p_id_categoria
        AND    p.activo = 'S'
        ORDER BY p.id_producto
        FOR UPDATE OF p.precio_unitario WAIT 5;
 
    e_recurso_ocupado EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_recurso_ocupado, -30006);
 
    V_nuevo        NUMBER;
    V_precio_min   NUMBER;
    V_actualizados PLS_INTEGER := 0;
    V_omitidos     PLS_INTEGER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('AJUSTE DE PRECIOS CATEGORIA ' || V_id_categoria ||
                         ' (' || V_pct || '%)');
 
    FOR r IN c_prod(V_id_categoria) LOOP
        V_nuevo      := ROUND(r.precio_unitario * (1 + V_pct / 100), 2);
        V_precio_min := r.costo_unitario * (1 + r.margen_minimo / 100);
 
        IF V_nuevo < V_precio_min THEN
            V_omitidos := V_omitidos + 1;
            DBMS_OUTPUT.PUT_LINE(RPAD(r.codigo, 10) || 'OMITIDO: ' || V_nuevo ||
                                 ' quedaria bajo el minimo ' || V_precio_min);
        ELSE
            UPDATE PRODUCTO
            SET    precio_unitario = V_nuevo
            WHERE CURRENT OF c_prod;
            V_actualizados := V_actualizados + 1;
            DBMS_OUTPUT.PUT_LINE(RPAD(r.codigo, 10) || 'ACTUALIZADO: ' ||
                                 r.precio_unitario || ' -> ' || V_nuevo);
        END IF;
    END LOOP;
 
    DBMS_OUTPUT.PUT_LINE('Actualizados: ' || V_actualizados ||
                         '     Omitidos por margen: ' || V_omitidos ||
                         '     (los inactivos no se leen)');
 
    ROLLBACK;   -- deja los datos de prueba como estaban; en uso real: COMMIT
EXCEPTION
    WHEN e_recurso_ocupado THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Filas bloqueadas por otra sesion (ORA-30006). Reintente mas tarde.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

------------------------------------------------------------------- 3.4 (2 pts)
-- SP_LISTAR_MOVIMIENTOS
-- Procedimiento que reciba un identificador de producto y devuelva un
-- SYS_REFCURSOR con los movimientos de inventario de ese producto, ordenados
-- por fecha. Incluya un bloque anonimo que consuma el cursor devuelto y lo cierre.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Julián Rodríguez
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Procedimiento que retorna un SYS_REFCURSOR con los movimientos
--              de inventario de un producto ordenados por fecha.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
--   Use un SYS_REFCURSOR con OPEN ... FOR para que quien llame lea los datos con
--   FETCH, sin que el procedimiento cargue todo en memoria.
--   Ordene por fecha_mov y id_movimiento para que el orden sea siempre el mismo
--   cuando hay varios movimientos el mismo dia.
--   El bloque que recibe el cursor es quien lo cierra; si no se cierra, queda
--   abierto en la sesion.
--   Si el producto no existe, el cursor simplemente no devuelve filas.
CREATE OR REPLACE PROCEDURE SP_LISTAR_MOVIMIENTOS (
    p_id_producto IN  NUMBER,
    p_cursor      OUT SYS_REFCURSOR
) IS
BEGIN
    OPEN p_cursor FOR
        SELECT id_movimiento,
               id_bodega,
               tipo,
               cantidad,
               fecha_mov,
               id_pedido,
               observacion
        FROM   MOVIMIENTO_INVENTARIO
        WHERE  id_producto = p_id_producto
        ORDER BY fecha_mov, id_movimiento;
END SP_LISTAR_MOVIMIENTOS;
/
 
-- Bloque consumidor:
DECLARE
    V_cursor     SYS_REFCURSOR;
    V_id_mov     MOVIMIENTO_INVENTARIO.id_movimiento%TYPE;
    V_bodega     MOVIMIENTO_INVENTARIO.id_bodega%TYPE;
    VV_tipo      MOVIMIENTO_INVENTARIO.tipo%TYPE;
    V_cantidad   MOVIMIENTO_INVENTARIO.cantidad%TYPE;
    VD_fecha     MOVIMIENTO_INVENTARIO.fecha_mov%TYPE;
    V_pedido     MOVIMIENTO_INVENTARIO.id_pedido%TYPE;
    VV_obs       MOVIMIENTO_INVENTARIO.observacion%TYPE;
    V_total      PLS_INTEGER := 0;
BEGIN
    SP_LISTAR_MOVIMIENTOS(1001, V_cursor);
 
    DBMS_OUTPUT.PUT_LINE('MOVIMIENTOS DEL PRODUCTO 1001');
    DBMS_OUTPUT.PUT_LINE(RPAD('MOV', 6) || RPAD('FECHA', 12) || RPAD('TIPO', 10) ||
                         LPAD('BODEGA', 8) || LPAD('CANT', 8) || LPAD('PEDIDO', 8) ||
                         '  OBSERVACION');
    LOOP
        FETCH V_cursor INTO V_id_mov, V_bodega, VV_tipo, V_cantidad, VD_fecha, V_pedido, VV_obs;
        EXIT WHEN V_cursor%NOTFOUND;
        V_total := V_total + 1;
        DBMS_OUTPUT.PUT_LINE(RPAD(V_id_mov, 6) ||
                             RPAD(TO_CHAR(VD_fecha, 'YYYY-MM-DD'), 12) ||
                             RPAD(VV_tipo, 10) || LPAD(V_bodega, 8) ||
                             LPAD(V_cantidad, 8) || LPAD(NVL(TO_CHAR(V_pedido), '-'), 8) ||
                             '  ' || VV_obs);
    END LOOP;
    CLOSE V_cursor;   -- el consumidor es quien cierra el cursor
 
    DBMS_OUTPUT.PUT_LINE('Total de movimientos: ' || V_total);
EXCEPTION
    WHEN OTHERS THEN
        IF V_cursor%ISOPEN THEN
            CLOSE V_cursor;
        END IF;
        RAISE;
END;
/

------------------------------------------------------------------- 3.5 (1 pt)
-- Bloque anonimo que cargue con BULK COLLECT los productos de una categoria en
-- una coleccion y use FORALL para actualizar su stock minimo.
-- Explique que costo concreto elimina esta tecnica y a partir de que volumen
-- empieza a notarse.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Julián Rodríguez
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Bloque anónimo con BULK COLLECT y FORALL para actualizar 
--              el stock mínimo de los productos de una categoría.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
--   BULK COLLECT trae todas las filas de una vez y FORALL envia todos los UPDATE
--   juntos. Asi se evita el cambio de contexto entre PL/SQL y SQL que ocurre en
--   cada vuelta de un ciclo normal; se nota desde unos miles de filas.
--   Con tablas muy grandes se usaria LIMIT para no llenar la memoria.
--   Termina con ROLLBACK para no cambiar los datos de prueba.
DECLARE
    TYPE t_ids    IS TABLE OF PRODUCTO.id_producto%TYPE;
    TYPE t_minimo IS TABLE OF PRODUCTO.stock_minimo%TYPE;
 
    V_id_categoria NUMBER := 3;       -- 3 = Material electrico
    V_factor       NUMBER := 1.10;    -- aumento del 10%
    V_ids          t_ids;
    V_nuevos       t_minimo;
BEGIN
    SELECT id_producto,
           CEIL(stock_minimo * V_factor)
    BULK COLLECT INTO V_ids, V_nuevos
    FROM   PRODUCTO
    WHERE  id_categoria = V_id_categoria
    AND    activo = 'S'
    ORDER BY id_producto;
 
    DBMS_OUTPUT.PUT_LINE('Productos cargados en la coleccion: ' || V_ids.COUNT);
 
    IF V_ids.COUNT > 0 THEN
        FORALL i IN 1 .. V_ids.COUNT
            UPDATE PRODUCTO
            SET    stock_minimo = V_nuevos(i)
            WHERE  id_producto  = V_ids(i);
 
        FOR i IN 1 .. V_ids.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('Producto ' || V_ids(i) ||
                                 ' -> nuevo stock minimo ' || V_nuevos(i) ||
                                 ' (filas: ' || SQL%BULK_ROWCOUNT(i) || ')');
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('Filas actualizadas en total: ' || SQL%ROWCOUNT);
    END IF;
 
    ROLLBACK;   -- deja los datos de prueba como estaban; en uso real: COMMIT
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/


--==============================================================================
-- PARTE 4 — MANEJO DE EXCEPCIONES                             (9 puntos / 75 min)
--==============================================================================

------------------------------------------------------------------- 4.1 (2 pts)
-- FN_PRECIO_PRODUCTO
-- Funcion que reciba el CODIGO de un producto y retorne su precio, manejando
-- explicitamente NO_DATA_FOUND y TOO_MANY_ROWS, con retorno de -1 y -2
-- respectivamente, e imprimiendo un mensaje descriptivo en cada caso.
-- Explique en que situacion real se produciria TOO_MANY_ROWS sobre esta tabla,
-- considerando las restricciones que hoy tiene.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Julián Rodríguez
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Función que retorna el precio de un producto por código, 
--              manejando NO_DATA_FOUND y TOO_MANY_ROWS.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
--   Use dos excepciones separadas porque son casos distintos: no existe (-1) o
--   esta repetido (-2).
--   Los valores -1 y -2 no se confunden con un precio porque el precio siempre es
--   mayor a 0 (CHECK ck_producto_precio).
--   TOO_MANY_ROWS: hoy no puede pasar porque codigo es UNIQUE (uk_producto_codigo).
--   Pasaria si se quita o deshabilita esa restriccion y se cargan codigos
--   repetidos, o si se buscara por una columna que no es unica, como el nombre.
CREATE OR REPLACE FUNCTION FN_PRECIO_PRODUCTO (
    p_codigo IN VARCHAR2
) RETURN NUMBER IS
    V_precio PRODUCTO.precio_unitario%TYPE;
BEGIN
    SELECT precio_unitario
    INTO   V_precio
    FROM   PRODUCTO
    WHERE  codigo = p_codigo;
 
    RETURN V_precio;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('FN_PRECIO_PRODUCTO: no existe un producto con codigo ' ||
                             NVL(p_codigo, 'NULL'));
        RETURN -1;
    WHEN TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE('FN_PRECIO_PRODUCTO: hay mas de un producto con codigo ' ||
                             p_codigo);
        RETURN -2;
END FN_PRECIO_PRODUCTO;
/

------------------------------------------------------------------- 4.2 (2 pts)
-- SP_VALIDAR_DESPACHO
-- Procedimiento que verifique si puede despacharse una cantidad de un producto
-- desde una bodega. Debe declarar una EXCEPCION PROPIA, levantarla con RAISE
-- cuando la cantidad solicitada supere el disponible, y capturarla en el bloque
-- EXCEPTION.
-- Argumente por que conviene nombrar esa condicion en lugar de resolverla con un
-- condicional.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Julián Rodríguez
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Procedimiento para validar si hay stock suficiente para un despacho 
--              utilizando una excepción personalizada.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
--   Declare excepciones propias con nombre para que el error se lea claro y quede
--   separado del camino normal, en vez de un IF suelto con un mensaje.
--   Si no hay fila en esa bodega, el disponible es 0.
--   Limitacion: como el procedimiento solo imprime, quien lo llama no se entera
--   del rechazo. Tampoco bloquea: entre validar y despachar otra sesion puede
--   gastar el stock.
CREATE OR REPLACE PROCEDURE SP_VALIDAR_DESPACHO (
    p_id_producto IN NUMBER,
    p_id_bodega   IN NUMBER,
    p_cantidad    IN NUMBER
) IS
    e_stock_insuficiente EXCEPTION;
    e_cantidad_invalida  EXCEPTION;
    V_disponible EXISTENCIA.cantidad%TYPE;
BEGIN
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE e_cantidad_invalida;
    END IF;
 
    BEGIN
        SELECT cantidad
        INTO   V_disponible
        FROM   EXISTENCIA
        WHERE  id_producto = p_id_producto
        AND    id_bodega   = p_id_bodega;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            V_disponible := 0;   -- sin fila en esa bodega: no hay unidades
    END;
 
    IF p_cantidad > V_disponible THEN
        RAISE e_stock_insuficiente;
    END IF;
 
    DBMS_OUTPUT.PUT_LINE('DESPACHO VALIDO: producto ' || p_id_producto ||
                         ', bodega ' || p_id_bodega || ', cantidad ' || p_cantidad ||
                         ' (disponible ' || V_disponible || ')');
EXCEPTION
    WHEN e_cantidad_invalida THEN
        DBMS_OUTPUT.PUT_LINE('DESPACHO RECHAZADO: la cantidad debe ser mayor que cero.');
    WHEN e_stock_insuficiente THEN
        DBMS_OUTPUT.PUT_LINE('DESPACHO RECHAZADO: producto ' || p_id_producto ||
                             ', bodega ' || p_id_bodega || ': solicitado ' ||
                             p_cantidad || ', disponible ' || V_disponible);
END SP_VALIDAR_DESPACHO;
/

------------------------------------------------------------------- 4.3 (2 pts)
-- SP_ANULAR_PEDIDO
-- Procedimiento que anule un pedido, usando RAISE_APPLICATION_ERROR con estos
-- codigos:
--     -20010  el pedido no existe
--     -20011  el pedido ya esta anulado
--     -20012  el pedido tiene mas de 30 dias
-- Explique la diferencia entre RAISE y RAISE_APPLICATION_ERROR, y en que caso el
-- cliente de la base de datos puede distinguirlos.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Julián Rodríguez
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Procedimiento para anular un pedido validando existencia, 
--              estado actual y antigüedad máxima permitida.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
--   Use RAISE_APPLICATION_ERROR porque entrega un codigo y un mensaje propios que
--   el cliente recibe y puede distinguir (SQLCODE -20010, -20011, -20012).
--   RAISE solo levanta una excepcion que ya existe; una propia sin atrapar llega
--   como ORA-06510, sin detalle. Por eso aqui se usa RAISE_APPLICATION_ERROR.
--   SELECT ... FOR UPDATE para que nadie anule o facture el pedido al mismo tiempo.
--   No hago COMMIT: lo decide quien llama al procedimiento.
--   Solo cambia el estado; no devuelve stock ni saldo del cliente porque el
--   enunciado no lo pide.
CREATE OR REPLACE PROCEDURE SP_ANULAR_PEDIDO (
    p_id_pedido IN NUMBER
) IS
    VC_estado PEDIDO.estado%TYPE;
    VD_fecha  PEDIDO.fecha_pedido%TYPE;
BEGIN
    BEGIN
        SELECT estado, fecha_pedido
        INTO   VC_estado, VD_fecha
        FROM   PEDIDO
        WHERE  id_pedido = p_id_pedido
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20010, 'El pedido ' || p_id_pedido || ' no existe');
    END;
 
    IF VC_estado = 'ANULADO' THEN
        RAISE_APPLICATION_ERROR(-20011, 'El pedido ' || p_id_pedido || ' ya esta anulado');
    END IF;
 
    IF SYSDATE - VD_fecha > 30 THEN
        RAISE_APPLICATION_ERROR(-20012, 'El pedido ' || p_id_pedido ||
                                ' tiene mas de 30 dias y no puede anularse');
    END IF;
 
    UPDATE PEDIDO
    SET    estado = 'ANULADO'
    WHERE  id_pedido = p_id_pedido;
 
    DBMS_OUTPUT.PUT_LINE('Pedido ' || p_id_pedido || ' anulado.');
END SP_ANULAR_PEDIDO;
/

------------------------------------------------------------------- 4.4 (2 pts)
-- Bloque anonimo que intente insertar un producto con una categoria inexistente
-- y capture el error de integridad referencial asociando ORA-02291 a una
-- excepcion con nombre.
-- Explique que aporta esa asociacion frente a atrapar el error en un manejador
-- generico.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Lina Patiño
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Bloque anónimo para capturar el error de integridad referencial
--              ORA-02291 asociándolo a una excepción con nombre mediante PRAGMA EXCEPTION_INIT.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Se utiliza PRAGMA EXCEPTION_INIT para asociar el error ORA-02291 con una excepcion de nombre e_categoria_inexistente. De esta forma, cuando se intenta
-- insertar el producto con una categoria que no existe, Oracle identifica el error y deja manejarlo directamente con WHEN e_categoria_inexistente.
-- Esta asociacion hace que podamos diferenciar especificamente un error de integridad referencial causado por una categoria que no existe, en lugar de capturar
-- cualquier error que pueda ocurrir durante el INSERT. Si se utilizara un manejador generico como WHEN OTHERS, no se podria identificar de forma
-- directa que el problema fue la categoria y se tendria que revisar SQLCODE o SQLERRM para saber que ocurrio. Por eso, la excepcion con nombre hace que el manejo del error sea mas claro
-- y deja mostrar un mensaje especifico mostrando que la categoria no existe. El INSERT falla y el producto no queda registrado en la tabla PRODUCTO.

DECLARE
    e_categoria_inexistente EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_categoria_inexistente, -2291);

    V_id_categoria CONSTANT NUMBER := 999;       -- no existe en CATEGORIA (solo hay 1 a 5)
    V_id_producto  CONSTANT NUMBER := 999999;     -- id explicito, libre (ver justificacion)
BEGIN
    DBMS_OUTPUT.PUT_LINE('4.4 Insertando un producto con la categoria ' ||
                         V_id_categoria || ' (inexistente)...');

    INSERT INTO PRODUCTO (
        id_producto, codigo, nombre, id_categoria,
        precio_unitario, costo_unitario, stock_minimo, activo
    ) VALUES (
        V_id_producto, 'PRB-4401', 'Producto de prueba 4.4', V_id_categoria,
        150000, 100000, 5, 'S'
    );

    -- Solo se llega aqui si la categoria si existia
    DBMS_OUTPUT.PUT_LINE('INSERT exitoso (no deberia ocurrir con esta categoria)');
    ROLLBACK;
EXCEPTION
    WHEN e_categoria_inexistente THEN
        DBMS_OUTPUT.PUT_LINE('ERROR CONTROLADO: la categoria ' || V_id_categoria ||
                             ' no existe en CATEGORIA; el producto no fue registrado.');
        DBMS_OUTPUT.PUT_LINE('Detalle de Oracle: ' || SQLERRM);
END;
/
 
------------------------------------------------------------------- 4.5 (1 pt)
-- SP_REGISTRAR_ERROR
-- Procedimiento que reciba el origen y registre en LOG_ERRORES el SQLCODE y el
-- SQLERRM actuales. El registro debe persistir aunque la transaccion principal
-- termine en ROLLBACK.
-- Explique por que se requiere esa independencia transaccional y describa un
-- escenario en el que esa misma independencia oculte informacion en lugar de
-- preservarla.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Gabriella Castro
-- Fecha: 3 de octubre de 2026
-- Versión: 1.1
-- Descripción: Procedimiento autónomo para registrar errores de ejecución en la
--              tabla LOG_ERRORES asegurando persistencia ante un ROLLBACK global.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Se usa PRAGMA AUTONOMOUS_TRANSACTION para separar el INSERT de LOG_ERRORES de
-- la transaccion que produjo el fallo. Asi, si la operacion principal termina en
-- ROLLBACK, el registro de diagnostico ya fue confirmado y no desaparece. El
-- COMMIT pertenece a la transaccion autonoma, no a la transaccion del llamador,
-- por lo que este procedimiento no decide ni confirma el trabajo principal.
-- La misma independencia puede ocultar informacion si se registra un error y se
-- confirma el log antes de que la transaccion principal complete correctamente:
-- el log podria describir un intento fallido que finalmente fue manejado o
-- revertido de forma esperada. Por eso el origen y detalle deben ser claros.
CREATE OR REPLACE PROCEDURE SP_REGISTRAR_ERROR (
    p_origen  IN VARCHAR2,
    p_detalle IN VARCHAR2 DEFAULT NULL
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    V_sqlcode NUMBER;
    VV_sqlerrm VARCHAR2(500);
BEGIN
    V_sqlcode := SQLCODE;
    VV_sqlerrm := SUBSTR(SQLERRM, 1, 500);

    INSERT INTO LOG_ERRORES (
        id_log, origen, codigo_error, mensaje, detalle,
        usuario_bd, fecha_log
    ) VALUES (
        SEQ_LOG.NEXTVAL,
        p_origen,
        V_sqlcode,
        VV_sqlerrm,
        SUBSTR(p_detalle, 1, 500),
        USER,
        SYSTIMESTAMP
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
END SP_REGISTRAR_ERROR;
/


--==============================================================================
-- PARTE 5 — DISPARADORES                                     (10 puntos / 90 min)
--==============================================================================
-- Los esqueletos de esta parte no incluyen la clausula de disparo. Definirla
-- hace parte del ejercicio.
--==============================================================================

------------------------------------------------------------------- 5.1 (2 pts)
-- TRG_CLIENTE_BI
-- Al insertar un cliente debe asignar el identificador desde SEQ_CLIENTE si
-- llega nulo, convertir el nombre a mayusculas sin espacios sobrantes y forzar
-- el estado activo a 'S' si no se indica.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Lina Patiño
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Disparador BEFORE INSERT para asignar identificador secuencial,
--              capitalizar y limpiar el nombre, y asegurar el estado activo por defecto.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Este trigger permite asignar automaticamente el identificador del cliente usando SEQ_CLIENTE
-- si este llega nulo, convierte el nombre a mayusculas sin espacios sobrantes usando UPPER y TRIM,
-- y fuerza el estado activo a 'S' si no se indica mediante NVL.
CREATE OR REPLACE TRIGGER TRG_CLIENTE_BI
BEFORE INSERT ON CLIENTE
FOR EACH ROW
BEGIN
    IF :NEW.id_cliente IS NULL THEN
        :NEW.id_cliente := SEQ_CLIENTE.NEXTVAL;
    END IF;
    
    :NEW.nombre := UPPER(TRIM(:NEW.nombre));
    :NEW.activo := NVL(:NEW.activo, 'S');
END;
/

------------------------------------------------------------------- 5.2 (2 pts)
-- TRG_PRODUCTO_AU_PRECIO
-- Debe registrar en AUDITORIA_PRECIO todo cambio de precio, calculando la
-- variacion porcentual, y dispararse unicamente cuando el precio efectivamente
-- cambie, resolviendo esa condicion con la clausula WHEN y no dentro del cuerpo.
-- Explique la diferencia entre ambas formas.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Lina Patiño
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Disparador AFTER UPDATE para auditar cambios de precio en productos
--              utilizando la cláusula WHEN para optimización condicional por fila.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Se utilizo AFTER UPDATE porque la auditoria solo tiene que guardar los cambios que ya fueron aceptados.
-- Se pone FOR EACH ROW porque necesita :OLD y :NEW. Se usa WHEN porque Oracle revisa la condicion
-- antes de ejecutar el disparador, ya que si el precio no cambio, el cuerpo ni se
-- ejecuta. Con un IF dentro del cuerpo se ejecutaria en todas las filas y
-- adentro se descartaria. UPDATE OF solo mira si la columna se nombra en
-- el UPDATE, no si su valor realmente cambio.
CREATE OR REPLACE TRIGGER TRG_PRODUCTO_AU_PRECIO
AFTER UPDATE OF precio_unitario ON PRODUCTO
FOR EACH ROW
WHEN (NEW.precio_unitario <> OLD.precio_unitario)
BEGIN
    INSERT INTO AUDITORIA_PRECIO (
        id_auditoria, id_producto, precio_anterior, precio_nuevo,
        variacion_pct, usuario_bd, fecha_cambio
    ) VALUES (
        SEQ_AUDITORIA.NEXTVAL,
        :NEW.id_producto,
        :OLD.precio_unitario,
        :NEW.precio_unitario,
        ROUND((:NEW.precio_unitario - :OLD.precio_unitario)
              / :OLD.precio_unitario * 100, 2),
        USER,
        SYSDATE
    );
END;
/
 

------------------------------------------------------------------- 5.3 (2 pts)
-- TRG_PRODUCTO_BIU_MARGEN
-- Debe impedir que se guarde un producto cuyo precio no alcance el margen minimo
-- de su categoria, segun la formula precio >= costo * (1 + margen/100),
-- rechazando la operacion con el error -20020.
-- Considere que debe ocurrir cuando la categoria indicada no existe, y justifique
-- su decision.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Lina Patiño
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Disparador BEFORE INSERT OR UPDATE para validar que el precio 
--              del producto cumpla con el margen mínimo configurado en su categoría.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Utilizamos BEFORE porque es una validacion, ya que se rechaza antes de escribir la fila, y un
-- solo disparador cubre INSERT y UPDATE. Si la categoria no existe, no se
-- rechaza con -20020, ya que esto significa que no hay margen suficiente.
-- La llave foranea responde con ORA-02291, y el punto 4.4 necesita ver ese error, porque el
-- BEFORE se ejecuta antes de revisar la llave foranea.
CREATE OR REPLACE TRIGGER TRG_PRODUCTO_BIU_MARGEN
BEFORE INSERT OR UPDATE ON PRODUCTO
FOR EACH ROW
DECLARE
    V_margen       CATEGORIA.margen_minimo%TYPE;
    V_precio_minimo NUMBER;
BEGIN
    BEGIN
        SELECT margen_minimo
        INTO   V_margen
        FROM   CATEGORIA
        WHERE  id_categoria = :NEW.id_categoria;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            V_margen := NULL;   
    END;
 
    IF V_margen IS NOT NULL THEN
        V_precio_minimo := :NEW.costo_unitario * (1 + V_margen / 100);
 
        IF :NEW.precio_unitario < V_precio_minimo THEN
            RAISE_APPLICATION_ERROR(-20020,
                'Precio ' || :NEW.precio_unitario ||
                ' por debajo del minimo permitido ' || ROUND(V_precio_minimo, 2) ||
                ' (costo ' || :NEW.costo_unitario || ' + margen ' || V_margen || '%)');
        END IF;
    END IF;
END;
/

------------------------------------------------------------------- 5.4 (2 pts)
-- TRG_DETALLE_AI_STOCK
-- Al insertar una linea de pedido debe descontar el stock de la bodega indicada
-- y registrar el movimiento de SALIDA correspondiente. Si no hay stock suficiente
-- debe abortar la operacion con el error -20030.
-- Explique por que el momento de disparo que eligio es el correcto y que dejaria
-- de funcionar con el contrario.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Lina Patiño
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Disparador AFTER INSERT para descontar el stock de inventario 
--              y registrar el movimiento de salida al agregar líneas a un pedido.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Se utiliza AFTER INSERT porque la linea ya paso sus restricciones y solo se toca el inventario por una linea valida.
-- Con BEFORE se descontaria sobre una fila que todavia puede ser rechazada. 
-- La existencia se lee con FOR UPDATE para bloquear la fila y que dos ventas simultaneas no lean
-- el mismo saldo. Si no hay stock se aborta con -20030 y se cancela el INSERT completo.
CREATE OR REPLACE TRIGGER TRG_DETALLE_AI_STOCK
AFTER INSERT ON DETALLE_PEDIDO
FOR EACH ROW
DECLARE
    V_cantidad EXISTENCIA.cantidad%TYPE;
BEGIN
    BEGIN
        SELECT cantidad
        INTO   V_cantidad
        FROM   EXISTENCIA
        WHERE  id_bodega   = :NEW.id_bodega
        AND    id_producto = :NEW.id_producto
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            V_cantidad := 0;
    END;
 
    IF V_cantidad < :NEW.cantidad THEN
        RAISE_APPLICATION_ERROR(-20030,
            'Stock insuficiente del producto ' || :NEW.id_producto ||
            ' en la bodega ' || :NEW.id_bodega ||
            ': disponible ' || V_cantidad || ', solicitado ' || :NEW.cantidad);
    END IF;
 
    UPDATE EXISTENCIA
    SET    cantidad    = cantidad - :NEW.cantidad
    WHERE  id_bodega   = :NEW.id_bodega
    AND    id_producto = :NEW.id_producto;
 
    INSERT INTO MOVIMIENTO_INVENTARIO (
        id_movimiento, id_producto, id_bodega, tipo, cantidad,
        fecha_mov, id_pedido, observacion
    ) VALUES (
        SEQ_MOVIMIENTO.NEXTVAL, :NEW.id_producto, :NEW.id_bodega, 'SALIDA',
        :NEW.cantidad, SYSDATE, :NEW.id_pedido, 'Despacho de pedido'
    );
END;
/

------------------------------------------------------------------- 5.5 (1 pt)
-- TRG_DETALLE_TOTAL
-- Debe recalcular el total de la cabecera del pedido despues de cualquier
-- insercion, actualizacion o borrado de sus lineas.
-- Documente el error que obtiene en su primer intento, en que momento aparece,
-- y como lo resuelve la construccion que finalmente utilizo.
-- Este punto no se califica sin esa explicacion.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Lina Patiño
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Disparador compuesto (Compound Trigger) para recalcular automáticamente
--              el total de la cabecera del pedido evitando errores de tabla mutante.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
-- PRIMER INTENTO: hice un trigger AFTER INSERT OR UPDATE OR DELETE por fila que
-- sumaba los subtotales con un SELECT SUM(subtotal) FROM DETALLE_PEDIDO adentro.
-- El trigger se crea bien, pero cuando hice un UPDATE sobre DETALLE_PEDIDO me
-- salio este error: ORA-04091: la tabla de mutación está produciendo un bucle.
-- TABLA MUTANTE: pasa cuando un trigger trata de leer la misma tabla que se esta
-- modificando en ese momento. Como la tabla todavia esta cambiando, Oracle no
-- deja que el trigger la lea, porque veria los datos a medias.
-- SOLUCION: use un COMPOUND TRIGGER. Mientras se modifica cada fila, solo guarda
-- el id del pedido que cambio, sin leer la tabla. Cuando la sentencia termina, ahi
-- si suma los subtotales y actualiza el total del PEDIDO, y asi ya no sale el error.
CREATE OR REPLACE TRIGGER TRG_DETALLE_TOTAL
FOR INSERT OR UPDATE OR DELETE ON DETALLE_PEDIDO
COMPOUND TRIGGER
 
    TYPE t_pedidos IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    V_afectados t_pedidos;               
 
    AFTER EACH ROW IS
    BEGIN
        IF INSERTING OR UPDATING THEN
            V_afectados(:NEW.id_pedido) := 1;  
        END IF;
        IF DELETING OR UPDATING THEN
            V_afectados(:OLD.id_pedido) := 1;   
        END IF;
    END AFTER EACH ROW;
 
    AFTER STATEMENT IS
        V_idx   PLS_INTEGER;
        V_total NUMBER;
    BEGIN
        V_idx := V_afectados.FIRST;
        WHILE V_idx IS NOT NULL LOOP
            SELECT NVL(SUM(subtotal), 0)
            INTO   V_total
            FROM   DETALLE_PEDIDO
            WHERE  id_pedido = V_idx;
 
            UPDATE PEDIDO
            SET    total = V_total
            WHERE  id_pedido = V_idx;
 
            V_idx := V_afectados.NEXT(V_idx);
        END LOOP;
    END AFTER STATEMENT;
 
END TRG_DETALLE_TOTAL;
/

------------------------------------------------------------------- 5.6 (1 pt)
-- TRG_V_STOCK_IO
-- Debe permitir actualizar el precio y el stock minimo del producto a traves de
-- la vista V_STOCK_CONSOLIDADO.
-- Explique por que esa vista no es actualizable de forma directa.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Lina Patiño
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Disparador INSTEAD OF UPDATE para permitir modificaciones de precio 
--              y stock mínimo a través de la vista V_STOCK_CONSOLIDADO.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
-- La vista no es actualizable porque une informacion de tres tablas y ademas hace un calculo del stock total.
-- Por eso, Oracle no sabe exactamente en que registro de las tablas orignales debe hacer el cambio.
-- Por esta razon utilizamos INSTEAD OF, que deja que cuando se haga un UPDATE sobre la vista, en realidad 
-- se actualice directamente la tabla PRODUCTO. En este caso solo se modifican el precio y el stock mínimo del producto.
CREATE OR REPLACE TRIGGER TRG_V_STOCK_IO
INSTEAD OF UPDATE ON V_STOCK_CONSOLIDADO
FOR EACH ROW
BEGIN
    UPDATE PRODUCTO
    SET    precio_unitario = :NEW.precio_unitario,
           stock_minimo    = :NEW.stock_minimo
    WHERE  id_producto     = :OLD.id_producto;
END;
/


--==============================================================================
-- PARTE 6 — CASO INTEGRADOR                                   (5 puntos / 45 min)
--==============================================================================

-------------------------------------------------------------------------------
-- PKG_VENTAS
-- Construya un PAQUETE que exponga el procedimiento SP_FACTURAR_PEDIDO, el cual,
-- para un pedido en estado BORRADOR, debe:
--
--   1. Validar que el pedido exista y este en BORRADOR
--   2. Recorrer sus lineas con un cursor y acumular el subtotal
--   3. Calcular el descuento con FN_CALCULAR_DESCUENTO
--   4. Validar contra FN_CUPO_DISPONIBLE que el cliente tenga cupo suficiente
--   5. Actualizar el total del pedido y cambiar su estado a CONFIRMADO
--   6. Incrementar el saldo pendiente del cliente
--   7. Usar SAVEPOINT y revertir parcialmente ante cualquier fallo, registrando
--      el error con SP_REGISTRAR_ERROR
--   8. Devolver por parametros OUT el total facturado y el descuento aplicado
--
-- Firma esperada:
--   PKG_VENTAS.SP_FACTURAR_PEDIDO(p_id_pedido IN NUMBER,
--                                 p_total     OUT NUMBER,
--                                 p_descuento OUT NUMBER)
--
-- Se evalua la integracion. El procedimiento debe apoyarse en los objetos de las
-- partes 1 a 5 y no reimplementar su logica: uno que vuelva a codificar el
-- calculo del descuento pierde la mitad del puntaje de esta parte.
-- Defina explicitamente el alcance transaccional y justifique donde decidio
-- ubicar la confirmacion de la transaccion.
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Autor: Lina Patiño
-- Fecha: 3 de octubre de 2026
-- Versión: 1.0
-- Descripción: Paquete PKG_VENTAS con el procedimiento SP_FACTURAR_PEDIDO para 
--              consolidar y facturar pedidos en borrador de manera íntegra y segura.
--------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Se crea un paquete para tener en un mismo lugar la logica relacionada con la facturacion de los pedidos. Primero se verifica que el pedido exista y que
-- este en estado BORRADOR, para que no se facture un pedido que ya fue confirmado. Para calcular el valor del pedido se recorren sus lineas con un cursor y se
-- suma cada subtotal. Luego se utilizan las funciones FN_CALCULAR_DESCUENTO y FN_CUPO_DISPONIBLE.
-- Se usa FOR UPDATE al consultar el pedido y el cliente para evitar que dos procesos los modifiquen al mismo tiempo. Tambien se usa SAVEPOINT para
-- que si ocurre un error, se pueda hacer ROLLBACK TO SAVEPOINT y deshacer solamente los cambios hechos por este procedimiento.
-- No se hace COMMIT dentro de SP_FACTURAR_PEDIDO, porque la confirmacion de la transaccion queda a cargo de quien llama al procedimiento. Si ocurre un error,
-- se registra con SP_REGISTRAR_ERROR y luego se vuelve a lanzar la excepcion para informar que la facturacion fallo. El COMMIT del registro del error queda dentro de SP_REGISTRAR_ERROR.
-- Los errores propios que se manejan son:
-- -20050: el pedido no existe
-- -20051: el pedido no esta en estado BORRADOR
-- -20052: el pedido no tiene lineas
-- -20053: el cliente no tiene cupo suficiente

CREATE OR REPLACE PACKAGE PKG_VENTAS IS

    PROCEDURE SP_FACTURAR_PEDIDO (
        p_id_pedido IN  NUMBER,
        p_total     OUT NUMBER,
        p_descuento OUT NUMBER
    );

END PKG_VENTAS;
/
SHOW ERRORS PACKAGE PKG_VENTAS

-- CUERPO DEL PAQUETE

CREATE OR REPLACE PACKAGE BODY PKG_VENTAS IS

    CURSOR c_lineas (p_pedido NUMBER) IS
        SELECT linea, subtotal
        FROM   DETALLE_PEDIDO
        WHERE  id_pedido = p_pedido
        ORDER BY linea;

    PROCEDURE SP_FACTURAR_PEDIDO (
        p_id_pedido IN  NUMBER,
        p_total     OUT NUMBER,
        p_descuento OUT NUMBER
    ) IS

        V_id_cliente PEDIDO.id_cliente%TYPE;
        VC_estado    PEDIDO.estado%TYPE;
        V_bloqueo    CLIENTE.id_cliente%TYPE;

        V_subtotal   NUMBER      := 0;
        V_lineas     PLS_INTEGER := 0;
        V_descuento  NUMBER;
        V_total      NUMBER;

        VV_detalle   VARCHAR2(500);

    BEGIN
        SAVEPOINT sp_facturar;

-- 1. VALIDAR QUE EL PEDIDO EXISTA Y ESTE EN BORRADOR
 
        BEGIN
            SELECT id_cliente, estado
            INTO   V_id_cliente, VC_estado
            FROM   PEDIDO
            WHERE  id_pedido = p_id_pedido
            FOR UPDATE;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20050,
                    'El pedido ' || p_id_pedido || ' no existe'
                );
        END;


        IF VC_estado <> 'BORRADOR' THEN
            RAISE_APPLICATION_ERROR(
                -20051,
                'El pedido ' || p_id_pedido ||
                ' esta en estado ' || VC_estado ||
                ' y solo se puede facturar un BORRADOR'
            );
        END IF;


        SELECT id_cliente
        INTO   V_bloqueo
        FROM   CLIENTE
        WHERE  id_cliente = V_id_cliente
        FOR UPDATE;

-- 2. RECORRER LAS LINEAS Y CALCULAR EL SUBTOTAL

        FOR r IN c_lineas(p_id_pedido) LOOP

            V_subtotal := V_subtotal + r.subtotal;
            V_lineas   := V_lineas + 1;

        END LOOP;

        IF V_lineas = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20052,
                'El pedido ' || p_id_pedido ||
                ' no tiene lineas para facturar'
            );
        END IF;

 -- 3. CALCULAR EL DESCUENTO
        V_descuento := FN_CALCULAR_DESCUENTO(
            V_id_cliente,
            V_subtotal
        );

        V_total := V_subtotal - V_descuento;

-- 4. VALIDAR EL CUPO DISPONIBLE DEL CLIENTE

        IF FN_CUPO_DISPONIBLE(V_id_cliente) < V_total THEN

            RAISE_APPLICATION_ERROR(
                -20053,
                'Cupo de credito insuficiente: se requieren ' ||
                V_total ||
                ' y el cliente tiene ' ||
                FN_CUPO_DISPONIBLE(V_id_cliente)
            );

        END IF;
        
-- 5. ACTUALIZAR EL TOTAL Y CAMBIAR EL ESTADO DEL PEDIDO
        UPDATE PEDIDO
        SET    total  = V_total,
               estado = 'CONFIRMADO'
        WHERE  id_pedido = p_id_pedido;
        
-- 6. ACTUALIZAR EL SALDO PENDIENTE DEL CLIENTE

        UPDATE CLIENTE
        SET    saldo_pendiente = saldo_pendiente + V_total
        WHERE  id_cliente = V_id_cliente;

-- 8. DEVOLVER LOS RESULTADOS POR PARAMETROS OUT

        p_total     := V_total;
        p_descuento := V_descuento;

    EXCEPTION

-- 7. MANEJO DE ERRORES

        WHEN OTHERS THEN
            VV_detalle := SUBSTR(
                'Pedido ' || p_id_pedido ||
                ' | SQLCODE ' || SQLCODE ||
                ' | ' || SQLERRM,
                1,
                500
            );
            ROLLBACK TO SAVEPOINT sp_facturar;

            SP_REGISTRAR_ERROR(
                'PKG_VENTAS.SP_FACTURAR_PEDIDO',
                VV_detalle
            );

            RAISE;

    END SP_FACTURAR_PEDIDO;

END PKG_VENTAS;
/
SHOW ERRORS PACKAGE PKG_VENTAS

COMMIT;



--==============================================================================
-- FIN DE LA PLANTILLA
--==============================================================================