
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

SELECT maquina_estado_crear(
	p_nombre      := 'maquina_estado_test', 
	p_descripcion := 'Máquina de estado de prueba'
);

SELECT maquina_estado_crear_estado(
	p_nombre         := 'estado_inicial', 
	p_descripcion    := 'Estado inicial de prueba'
);

SELECT maquina_estado_crear_estado(
	p_nombre         := 'estado_en_curso', 
	p_descripcion    := 'Estado en curso de prueba'
);

SELECT maquina_estado_crear_estado(
	p_nombre         := 'estado_final', 
	p_descripcion    := 'Estado final de prueba'
);

SELECT maquina_estado_crear_transicion(
	p_maquina_estado := maquina_estado_find('maquina_estado_test'), 
	p_estado_origen  := maquina_estado_find_estado('estado_inicial'), 
	p_estado_destino := maquina_estado_find_estado('estado_en_curso')
);

SELECT maquina_estado_crear_transicion(
	p_maquina_estado := maquina_estado_find('maquina_estado_test'), 
	p_estado_origen  := maquina_estado_find_estado('estado_en_curso'), 
	p_estado_destino := maquina_estado_find_estado('estado_final')
);

SELECT maquina_estado_asociar_clase(
	p_maquina_estado := maquina_estado_find('maquina_estado_test'), 
	p_clase_nombre   := 'objeto_instancia_test'
);



/**************
CREAMOS UN NUEVO OBJETO
*************/

SELECT maquina_estado_obtener_estado_actual_objeto(
	p_objeto_id    := 1, 
	p_objeto_clase := 'objeto_instancia_test'
);
/*
-- Vemos que al asociar la clase a la maquina de estado, se crea el registro en la tabla de eventos para los objetos existentes
resultado:
maquina_estado_obtener_estado_actual_objeto  
-----------------------------------------------
 (1,estado_inicial,"Estado inicial de prueba")
(1 row)
*/

INSERT INTO objeto_instancia_test (nombre) VALUES ('objeto_instancia_test_2');

SELECT maquina_estado_obtener_estado_actual_objeto(
	p_objeto_id    := 2, 
	p_objeto_clase := 'objeto_instancia_test'
);
/*
--Nota: vemos que el trigger se ejecuta y crea el registro en la tabla de eventos
resultado:
maquina_estado_obtener_estado_actual_objeto  
-----------------------------------------------
 (1,estado_inicial,"Estado inicial de prueba")
(1 row)
*/


/**************
CAMBIAMOS EL ESTADO DEL OBJETO
*************/

SELECT maquina_estado_cambiar_estado_objeto(
	p_objeto_clase := 'objeto_instancia_test',
	p_objeto_id    := 1,
	p_evento       := 'evento_prueba'
);
/*
NOTICE:  Cambio de estado exitoso: objeto objeto_instancia_test:1 -> nuevo estado (2,estado_en_curso,"Estado en curso de prueba")
 maquina_estado_cambiar_estado_objeto 
--------------------------------------
 
(1 row)
*/

SELECT maquina_estado_obtener_estado_actual_objeto(
	p_objeto_id    := 1, 
	p_objeto_clase := 'objeto_instancia_test'
);
/*
resultado:
maquina_estado_obtener_estado_actual_objeto  
-----------------------------------------------
 (2,estado_en_curso,"Estado en curso de prueba")
(1 row)
*/

SELECT maquina_estado_cambiar_estado_objeto(
	p_objeto_clase := 'objeto_instancia_test',
	p_objeto_id    := 1,
	p_evento       := 'prueba_2'
);
/*
NOTICE:  Cambio de estado exitoso: objeto objeto_instancia_test:1 -> nuevo estado (3,estado_final,"Estado final de prueba")
 maquina_estado_cambiar_estado_objeto 
--------------------------------------
 
(1 row)
*/

SELECT maquina_estado_obtener_estado_actual_objeto(
	p_objeto_id    := 1, 
	p_objeto_clase := 'objeto_instancia_test'
);
/*
resultado:
maquina_estado_obtener_estado_actual_objeto  
-----------------------------------------------
 (3,estado_final,"Estado final de prueba")
(1 row)
*/

SELECT maquina_estado_cambiar_estado_objeto(
	p_objeto_clase := 'objeto_instancia_test',
	p_objeto_id    := 1,
	p_evento       := 'prueba cambiar objeto que esta en  estado final'
);
/*
ERROR:  El estado estado_final es un estado final
CONTEXT:  PL/pgSQL function maquina_estado_cambiar_estado_objeto(regclass,integer,text) line 20 at RAISE
*/


