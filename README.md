<div align="center">

# 🌸 Bases de Datos 2 🌸
### SQL avanzado & PL/SQL

*Donde los datos se vuelven historias (y los bloqueos se vuelven aprendizajes)* ✨

![Oracle](https://img.shields.io/badge/Oracle-F472B6?style=for-the-badge&logo=oracle&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-F9A8D4?style=for-the-badge&logo=postgresql&logoColor=white)
![PL/SQL](https://img.shields.io/badge/PL%2FSQL-EC4899?style=for-the-badge&logo=oracle&logoColor=white)
![Semestre](https://img.shields.io/badge/Quinto_semestre-FBCFE8?style=for-the-badge&logoColor=white&labelColor=F472B6)

[🌐 Ver mi portafolio](https://gabgaby006.github.io) · [💼 LinkedIn](https://www.linkedin.com/in/gabriella-michelle-castro-cuello-257283363/)

</div>

---

## 💌 Sobre este repositorio

Aquí guardo los scripts que desarrollo en la asignatura **Bases de Datos 2**.
El código vive en este repo 💻 y la historia de cada actividad (contexto,
decisiones, resultados y conclusiones) vive en mi
[portafolio](https://gabgaby006.github.io) 🎀

---

## 🗂️ Contenido

### 🌷 SQL avanzado

| Script | Qué trabajé |
|:---|:---|
| 🔗 [`JOINS.sql`](JOINS.sql) | Cada tipo de JOIN y en qué contexto usarlo |
| 🕵️‍♀️ [`EjercicioDesarrolladorMaloAgosto13.sql`](EjercicioDesarrolladorMaloAgosto13.sql) | Ejercicio de JOINS sobre el esquema HR de Oracle |
| 🧮 [`ColumnasVirtuales.sql`](ColumnasVirtuales.sql) | Laboratorio propio sobre columnas virtuales |
| 🏦 [`04_reto_corregido.sql`](04_reto_corregido.sql) | Taller Banco Andino: concurrencia, índices y SQL avanzado |

### 🌼 PL/SQL

| Script | Qué trabajé |
|:---|:---|
| 🧱 [`script1_plsql_tipos_de_datos.sql`](script1_plsql_tipos_de_datos.sql) | Bloques anónimos, `%TYPE` y `%ROWTYPE` |
| 📦 [`TALLER_PLSQL_GRUPO_8.sql`](TALLER_PLSQL_GRUPO_8.sql) | Taller integrador de inventario y ventas: procedimientos, funciones, cursores, excepciones, triggers y el paquete `PKG_VENTAS` (trabajo en equipo) |

📄 Evidencias del taller (capturas de ejecución): [`TALLER_PLSQL_GRUPO_8.pdf`](TALLER_PLSQL_GRUPO_8.pdf)

---

## 🎀 Lo que he aprendido hasta ahora

### 🌷 SQL avanzado
- 🔒 **Concurrencia:** actualizaciones perdidas, bloqueo pesimista y optimista, `SKIP LOCKED` e interbloqueos
- ⚡ **Rendimiento:** planes de ejecución, índices compuestos y consultas sargables
- 📊 **SQL avanzado:** funciones de ventana, CTEs recursivas, `MERGE` y `PIVOT`

### 🌼 PL/SQL
- 🧩 **Bloques y tipos:** estructura `DECLARE / BEGIN / EXCEPTION / END`, `%TYPE` y `%ROWTYPE`
- ⚙️ **Procedimientos y funciones:** parámetros de entrada y salida, y lógica de negocio dentro de la base de datos
- 🔁 **Cursores:** explícitos, parametrizados, `FOR UPDATE`, `SYS_REFCURSOR`, `BULK COLLECT` y `FORALL`
- 🚨 **Excepciones:** errores propios con `RAISE_APPLICATION_ERROR` y registro de errores en una tabla de log
- 🎯 **Triggers:** auditoría, validaciones, actualización automática de stock y totales, y `INSTEAD OF` sobre vistas
- 📦 **Paquetes y transacciones:** `PKG_VENTAS` y `SAVEPOINT` para deshacer una facturación si algo falla

---

## 🚀 Cómo ejecutar los scripts

1. 🔌 Conéctate a tu esquema en SQL Developer o DBeaver
2. 📣 Para PL/SQL, ejecuta primero `SET SERVEROUTPUT ON`
3. 📂 Abre el `.sql` y ejecútalo como script (`F5`)
4. 🏗️ Para el taller del Grupo 8, primero hay que crear el esquema de inventario que entrega el docente

---

<div align="center">

Hecho con 💗 y mucho café por **Gabriella Castro**
*Estudiante de Ingeniería de Sistemas · UX/UI enthusiast*

</div>
