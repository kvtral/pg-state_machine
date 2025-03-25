
/**************
SIMULAMOS UNA TABLA DE OBJETOS
*************/

CREATE TABLE objeto_instancia_test (
	id serial PRIMARY KEY,
	nombre text NOT NULL
);

INSERT INTO objeto_instancia_test (nombre) VALUES ('objeto_instancia_test_1');


/**************
CREAMOS LA MAQUINA DE ESTADO Y LA CONFIGURAMOS
*************/

-- Crear máquina de estado
SELECT me_maquina_estado_crear(
	p_nombre      := 'maquina_estado_test', 
	p_descripcion := 'Máquina de estado de prueba'
);

-- Crear estados
SELECT me_estado_crear(
	p_nombre         := 'estado_inicial', 
	p_descripcion    := 'Estado inicial de prueba'
);

SELECT me_estado_crear(
	p_nombre         := 'pendiente_de_pago', 
	p_descripcion    := 'Estado pendiente de pago'
);

SELECT me_estado_crear(
	p_nombre         := 'pagado', 
	p_descripcion    := 'Estado pagado'
);

SELECT me_estado_crear(
	p_nombre         := 'estado_en_curso', 
	p_descripcion    := 'Estado en curso de prueba'
);

SELECT me_estado_crear(
	p_nombre         := 'estado_final', 
	p_descripcion    := 'Estado final de prueba'
);

-- Crear transiciones
SELECT me_transicion_crear(
	p_maquina_estado := me_maquina_estado_find('maquina_estado_test'), 
	p_estado_origen  := me_estado_find('estado_inicial'), 
	p_estado_destino := me_estado_find('pendiente_de_pago')
);

SELECT me_transicion_crear(
	p_maquina_estado := me_maquina_estado_find('maquina_estado_test'), 
	p_estado_origen  := me_estado_find('pendiente_de_pago'), 
	p_estado_destino := me_estado_find('pagado')
);

SELECT me_transicion_crear(
	p_maquina_estado := me_maquina_estado_find('maquina_estado_test'), 
	p_estado_origen  := me_estado_find('pagado'), 
	p_estado_destino := me_estado_find('estado_en_curso')
);

SELECT me_transicion_crear(
	p_maquina_estado := me_maquina_estado_find('maquina_estado_test'), 
	p_estado_origen  := me_estado_find('estado_en_curso'), 
	p_estado_destino := me_estado_find('estado_final')
);

-- Asociar la clase a la máquina de estado
SELECT me_maquina_estado_asociar_clase(
	p_maquina_estado := me_maquina_estado_find('maquina_estado_test'), 
	p_clase_nombre   := 'objeto_instancia_test'
);


/**************
CREAMOS UN NUEVO OBJETO
*************/

SELECT me_objeto_obtener_estado_actual(
	p_objeto_id    := 1, 
	p_objeto_clase := 'objeto_instancia_test'
);
/*
-- Vemos que al asociar la clase a la maquina de estado, se crea el registro en la tabla de eventos para los objetos existentes
resultado:
me_objeto_obtener_estado_actual  
-----------------------------------------------
 (1,estado_inicial,"Estado inicial de prueba")
(1 row)
*/

INSERT INTO objeto_instancia_test (nombre) VALUES ('objeto_instancia_test_2');

SELECT me_objeto_obtener_estado_actual(
	p_objeto_id    := 2, 
	p_objeto_clase := 'objeto_instancia_test'
);
/*
--Nota: vemos que el trigger se ejecuta y crea el registro en la tabla de eventos
resultado:
me_objeto_obtener_estado_actual  
-----------------------------------------------
 (1,estado_inicial,"Estado inicial de prueba")
(1 row)
*/


/**************
CAMBIAMOS EL ESTADO DEL OBJETO
*************/

SELECT me_objeto_crear_evento_transicion(
	p_comando      := 'AVANZAR',
	p_objeto_clase := 'objeto_instancia_test',
	p_objeto_id    := 1,
	p_evento       := 'evento_prueba'
);
/*
NOTICE:  Cambio de estado exitoso: objeto objeto_instancia_test:  -> nuevo estado: pendiente de pago
 me_objeto_crear_evento_transicion 
--------------------------------------
 
(1 row)
*/

SELECT me_objeto_obtener_estado_actual(
	p_objeto_id    := 1, 
	p_objeto_clase := 'objeto_instancia_test'
);
/*
resultado:
maquina_estado_obtener_estado_actual_objeto  
-----------------------------------------------
 (2,pendiente_de_pago,"Estado pendiente de pago")
(1 row)
*/

SELECT me_objeto_crear_evento_transicion(
	p_comando      := 'RETROCEDER',
	p_objeto_clase := 'objeto_instancia_test',
	p_objeto_id    := 1,
	p_evento       := 'prueba_2'
);
/*
NOTICE:  Cambio de estado exitoso: objeto objeto_instancia_test:  -> nuevo estado: inicial de prueba
 me_objeto_crear_evento_transicion 
--------------------------------------
 
(1 row)
*/

SELECT me_objeto_obtener_estado_actual(
	p_objeto_id    := 1, 
	p_objeto_clase := 'objeto_instancia_test'
);
/*
resultado:
me_objeto_obtener_estado_actual  
-----------------------------------------------
 (1,estado_final,"Estado inicial de prueba")
(1 row)
*/


SELECT me_objeto_crear_evento_transicion(
	p_comando      := 'AVANZAR',
	p_objeto_clase := 'objeto_instancia_test',
	p_objeto_id    := 1,
	p_evento       := 'avanzar_nuevamente'
);
/* 
NOTICE:  Cambio de estado exitoso: objeto objeto_instancia_test:  -> nuevo estado: pendiente de pago
me_objeto_crear_evento_transicion 
-----------------------------------
 
(1 row) */

SELECT me_objeto_crear_evento_transicion(
	p_comando      := 'AVANZAR',
	p_objeto_clase := 'objeto_instancia_test',
	p_objeto_id    := 1,
	p_evento       := 'avanzar_nuevamente'
);
/* 
NOTICE:  Cambio de estado exitoso: objeto objeto_instancia_test:  -> nuevo estado: pagado
me_objeto_crear_evento_transicion 
-----------------------------------
 
(1 row) */

SELECT me_objeto_crear_evento_transicion(
	p_comando      := 'REINICIAR',
	p_objeto_clase := 'objeto_instancia_test',
	p_objeto_id    := 1,
	p_evento       := 'reiniciar_maquina'
);
/*
NOTICE:  Cambio de estado exitoso: objeto objeto_instancia_test:  -> nuevo estado: inicial de prueba
 me_objeto_crear_evento_transicion 
-----------------------------------
 
(1 row)
*/
 
SELECT me_objeto_obtener_estado_actual(
	p_objeto_id    := 1, 
	p_objeto_clase := 'objeto_instancia_test'
);
/*
resultado:
me_objeto_obtener_estado_actual        
-----------------------------------------------
 (1,estado_inicial,"Estado inicial de prueba")
(1 row) */


-- [...] Se vuelve a avanzar y se llega al estado final

SELECT me_objeto_crear_evento_transicion(
	p_comando      := 'AVANZAR',
	p_objeto_clase := 'objeto_instancia_test',
	p_objeto_id    := 1,
	p_evento       := 'prueba cambiar objeto que esta en  estado final'
);
/*
ERROR:  El estado estado_final es un estado final
CONTEXT:  PL/pgSQL function me_objeto_cambiar_estado(regclass,integer,text) line 20 at RAISE
*/


/**************
Funciones de mantención de la máquina de estado
*************/

SELECT me_limpiar_transiciones(
	p_maquina_estado   := me_maquina_estado_find('maquina_estado_test'),
	p_eliminar_eventos := true
);
/* 
 me_limpiar_transiciones 
------------------------

(1 row) 

SELECT * FROM objeto_instancia_eventos_transicion;
 id | objeto_id | objeto_clase | estado_id | evento_descripcion | fecha_evento 
----+-----------+--------------+-----------+--------------------+--------------
select * from maquina_estado_transiciones;
 id | maquina_id | estado_origen_id | estado_destino_id 
----+------------+------------------+-------------------
(0 rows)

select * from maquina_estado_estados;
 id |      nombre       |        descripcion        
----+-------------------+---------------------------
  1 | estado_inicial    | Estado inicial de prueba
  2 | pendiente_de_pago | Estado pendiente de pago
  3 | pagado            | Estado pagado
  4 | estado_en_curso   | Estado en curso de prueba
  5 | estado_final      | Estado final de prueba
(5 rows)

Esto permite generar nuevas transiciones, haremos una con sólo una transición

*/

SELECT me_transicion_crear(
	p_maquina_estado := me_maquina_estado_find('maquina_estado_test'), 
	p_estado_origen  := me_estado_find('estado_inicial'), 
	p_estado_destino := me_estado_find('estado_en_curso')
);

SELECT me_transicion_crear(
	p_maquina_estado := me_maquina_estado_find('maquina_estado_test'), 
	p_estado_origen  := me_estado_find('estado_en_curso'), 
	p_estado_destino := me_estado_find('estado_final')
);

/*
select * from maquina_estado_transiciones;
 id | maquina_id | estado_origen_id | estado_destino_id 
----+------------+------------------+-------------------
  5 |          1 |                1 |                 4
  6 |          1 |                4 |                 5
(2 rows)

*/

SELECT me_transicion_remover(
	p_maquina_estado   := me_maquina_estado_find('maquina_estado_test'),
	p_estado_origen  := me_estado_find('estado_inicial'), 
	p_estado_destino := me_estado_find('estado_en_curso')
);

/*
NOTICE:  Eliminar una transición que no sea final no está implementado
 me_transicion_remover 
-----------------------
 
(1 row) */

SELECT me_transicion_remover(
	p_maquina_estado := me_maquina_estado_find('maquina_estado_test'),
	p_estado_origen  := me_estado_find('estado_en_curso'), 
	p_estado_destino := me_estado_find('estado_final')
);

/*  me_transicion_remover 
-----------------------
 
(1 row)

select * from maquina_estado_transiciones;
 id | maquina_id | estado_origen_id | estado_destino_id 
----+------------+------------------+-------------------
  5 |          1 |                1 |                 4
(1 row) */


SELECT me_estado_remover(
	p_estado := me_estado_find('estado_en_curso')
);

/*
NOTICE:  Si el estado tiene transiciones, no se puede eliminar
 me_estado_remover 
--------------------
 
(1 row)
*/

SELECT me_maquina_estado_remover(
	p_maquina_estado := me_maquina_estado_find('maquina_estado_test')
);

/*
NOTICE:  Si la máquina de estado tiene estados asociados, se eliminaran en cascada, asi como las transiciones configuradas
 me_maquina_estado_remover 
------------------------
 
(1 row)

SELECT * FROM maquina_estado;
 id | nombre | descripcion | parent_id 
----+--------+-------------+-----------
(0 rows)

SELECT * FROM maquina_estado_transiciones;
 id | maquina_id | estado_origen_id | estado_destino_id 
----+------------+------------------+-------------------
(0 rows)

select * from maquina_estado_clase_relacion;
 id | maquina_id | clase_nombre 
----+------------+--------------
(0 rows)

SELECT * FROM maquina_estado_estados;
 id |      nombre       |        descripcion        
----+-------------------+---------------------------
  1 | estado_inicial    | Estado inicial de prueba
  2 | pendiente_de_pago | Estado pendiente de pago
  3 | pagado            | Estado pagado
  4 | estado_en_curso   | Estado en curso de prueba
  5 | estado_final      | Estado final de prueba
(5 rows)

--NOTE  Los Estados permanecen, ya que no estan asociados a la máquina de estado y pueden ser usados en otra máquina de estado


*/