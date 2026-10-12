--INNER JOIN / JOIN (hace match con los datos en común entre las dos tablas)
SELECT E.EMPLOYEE_ID,
       E.FIRST_NAME,
       E.LAST_NAME,
       D.DEPARTMENT_NAME
FROM EMPL E
INNER JOIN DEPARTAMENTOS D
ON D.DEPARTMENT_ID = E.DEPARTMENT_ID;

-- LEFT JOIN (hace el match y trae los de la tabla izquierda aunque no tengan nada matching)
SELECT E.EMPLOYEE_ID,
       E.FIRST_NAME,
       E.LAST_NAME,
       D.DEPARTMENT_NAME
FROM EMPL E
LEFT JOIN DEPARTAMENTOS D
ON D.DEPARTMENT_ID = E.DEPARTMENT_ID;

-- ejemplo con los elementos al reves (la tabla izq se vuelven los departamentos)
SELECT E.EMPLOYEE_ID,
       E.FIRST_NAME,
       E.LAST_NAME,
       D.DEPARTMENT_NAME
FROM DEPARTAMENTOS D
LEFT JOIN EMPL E
ON D.DEPARTMENT_ID = E.DEPARTMENT_ID;

-- RIGHT JOIN (hace lo mismo que el left join con los elementos inversos, es más fácil usar el izq)
SELECT E.EMPLOYEE_ID,
       E.FIRST_NAME,
       E.LAST_NAME,
       D.DEPARTMENT_NAME
FROM EMPL E
RIGHT JOIN DEPARTAMENTOS D
ON D.DEPARTMENT_ID = E.DEPARTMENT_ID;

-- LEFT + RIGHT = TODO, osea FULL OUTER JOIN
SELECT E.EMPLOYEE_ID,
       E.FIRST_NAME,
       E.LAST_NAME,
       D.DEPARTMENT_NAME
FROM EMPL E
FULL OUTER JOIN DEPARTAMENTOS D
ON D.DEPARTMENT_ID = E.DEPARTMENT_ID;

--LEFT JOIN excluding INNER JOIN (LEFT ANTIJOIN)
SELECT E.EMPLOYEE_ID,
       E.FIRST_NAME,
       E.LAST_NAME,
       D.DEPARTMENT_NAME
FROM EMPL E
LEFT JOIN DEPARTAMENTOS D
ON D.DEPARTMENT_ID = E.DEPARTMENT_ID
WHERE D.DEPARTMENT_ID IS NULL;

--RIGHT JOIN excluding INNER JOIN (RIGHT ANTIJOIN)
SELECT E.EMPLOYEE_ID,
       E.FIRST_NAME,
       E.LAST_NAME,
       D.DEPARTMENT_NAME
FROM EMPL E
RIGHT JOIN DEPARTAMENTOS D
ON D.DEPARTMENT_ID = E.DEPARTMENT_ID
WHERE E.DEPARTMENT_ID IS NULL;

-- FULL OUTER JOIN excluding INNER JOIN
SELECT E.EMPLOYEE_ID,
       E.FIRST_NAME,
       E.LAST_NAME,
       D.DEPARTMENT_NAME
FROM EMPL E
FULL OUTER JOIN DEPARTAMENTOS D
ON D.DEPARTMENT_ID = E.DEPARTMENT_ID
WHERE E.DEPARTMENT_ID IS NULL OR D.DEPARTMENT_ID IS NULL;

-- SELF JOIN (no tiene clausula), es join a si mismo, el || ' ' || es para concatenar respuestas
SELECT E.EMPLOYEE_ID,
       E.FIRST_NAME || ' ' || E.LAST_NAME AS EMPLEADO,
       D.FIRST_NAME || ' ' || D.LAST_NAME AS JEFE
FROM EMPL E
LEFT JOIN EMPL D
ON D.EMPLOYEE_ID = E.MANAGER_ID;

-- CROSS JOIN (producto cruz / cartesiano)cruzar todos los elementos del A con el B | No importa el orden
SELECT E.FIRST_NAME,
       D.DEPARTMENT_NAME
FROM EMPL E
CROSS JOIN DEPARTAMENTOS D;

-- NATURAL JOIN (combina automáticamente dos tablas usando las columnas que tienen el mismo nombre y datos compatibles) no usa cualificadores solo el nombre de la tabla
SELECT E.EMPLOYEE_ID,
       E.FIRST_NAME,
       DEPARTMENT_ID,
       D.DEPARTMENT_NAME       
FROM EMPL E
NATURAL JOIN DEPARTAMENTOS D;

-- USING (me permite utilizar un NATURAL JOIN pero solo con cierta(s) columna(s) especifica(s))
SELECT E.EMPLOYEE_ID,E.FIRST_NAME,D.DEPARTMENT_NAME
FROM EMPL E
JOIN DEPARTAMENTOS D
USING (MANAGER_ID);

--BONUS (NO REPLICARLO POR FAVOR), (+) SIGNIFICA LEFT O RIGHT DEPENDIENDO DEL LADO DEL IGUAL QUE ESTEN
SELECT E.EMPLOYEE_ID,E.FIRST_NAME,D.DEPARTMENT_NAME
FROM EMPL E, DEPARTAMENTOS D
WHERE E.DEPARTMENT_ID = D.DEPARTMENT_ID (+); -- En este caso es left join


-- Experimento para buscar el empleado que no tiene departamento sin joins(dept = null)
SELECT * 
FROM EMPL
WHERE DEPARTMENT_ID IS NULL;


