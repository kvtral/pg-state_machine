
CREATE OR REPLACE FUNCTION trigger_insercion_estado_objeto()
RETURNS trigger AS $$
BEGIN
	INSERT INTO objeto_instancia_eventos_transicion (
		objeto_id,
		objeto_clase,
		estado_id,
		evento_descripcion,
		fecha_evento
	) VALUES (
		NEW.id,
		TG_TABLE_NAME::regclass,
		id(me_maquina_estado_obtener_estado_inicial(me_maquina_estado_asociada_obtener(TG_TABLE_NAME::regclass))),
		'creación',
		now()
	);
	REFRESH MATERIALIZED VIEW vista_estado_actual_objeto;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

---------------------------------------
-- Funciones para la maquina de estado
---------------------------------------

CREATE OR REPLACE FUNCTION me_maquina_estado_crear(
	p_nombre      text,
	p_descripcion text,
	p_parent      maquina_estado DEFAULT NULL )
RETURNS maquina_estado AS $$
DECLARE
	v_maquina_estado maquina_estado;
BEGIN
	INSERT INTO maquina_estado (
		nombre, 
		descripcion, 
		parent_id
	) VALUES (
		p_nombre, 
		p_descripcion, 
		p_parent.id
	) RETURNING * INTO v_maquina_estado;
	RETURN v_maquina_estado;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_maquina_estado_remover(
	p_maquina_estado maquina_estado )
RETURNS void AS $$
BEGIN
	RAISE WARNING 'Si la máquina de estado % tiene estados asociados, se eliminaran en cascada, asi como las transiciones configuradas', p_maquina_estado.nombre;
	DELETE FROM maquina_estado WHERE id = p_maquina_estado.id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_maquina_estado_instancia(
	p_id integer )
RETURNS maquina_estado AS $$
DECLARE
	v_me maquina_estado;
BEGIN
	SELECT m.* INTO v_me FROM maquina_estado m WHERE m.id = p_id;
	RETURN v_me;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_maquina_estado_find(
	p_nombre text )
RETURNS maquina_estado AS $$
DECLARE
	v_me maquina_estado;
BEGIN
	SELECT * INTO v_me FROM maquina_estado WHERE nombre = p_nombre;
	RETURN v_me;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_maquina_estado_obtener_estado_inicial(
	p_maquina_estado maquina_estado)
RETURNS maquina_estado_estados AS $$
DECLARE
	v_me_estado_id integer;
BEGIN
	SELECT t1.estado_origen_id INTO v_me_estado_id
	FROM maquina_estado_transiciones t1
	LEFT JOIN maquina_estado_transiciones t2
		ON t1.estado_origen_id = t2.estado_destino_id
	WHERE t2.id IS NULL
	AND t1.maquina_id = p_maquina_estado.id;
 
	IF v_me_estado_id IS NULL THEN
		RAISE EXCEPTION 'No se pudo determinar el estado inicial para la máquina de estado: %', maquina_estado.nombre;
	END IF;

	RETURN me_estado_instancia(v_me_estado_id);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_maquina_estado_obtener_estado_final(
	p_maquina_estado maquina_estado)
RETURNS maquina_estado_estados AS $$
DECLARE
	v_me_estado_id integer;
BEGIN
	SELECT t1.estado_destino_id INTO v_me_estado_id
	FROM maquina_estado_transiciones t1
	LEFT JOIN maquina_estado_transiciones t2
		ON t1.estado_destino_id = t2.estado_origen_id
	WHERE t2.id IS NULL
	AND t1.maquina_id = p_maquina_estado.id;

	IF v_me_estado_id IS NULL THEN
		RAISE EXCEPTION 'No se pudo determinar el estado final para la máquina de estado: %', maquina_estado.nombre;
	END IF;

	RETURN me_estado_instancia(v_me_estado_id);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_maquina_estado_es_estado_valido(
	p_estado maquina_estado_estados,
	p_maquina_estado maquina_estado )
RETURNS boolean AS $$
DECLARE
	v_es_estado_valido boolean;
BEGIN
	SELECT EXISTS (
		SELECT 1
		FROM maquina_estado_transiciones
		WHERE maquina_id = p_maquina_estado.id
		AND (estado_origen_id = p_estado.id OR estado_destino_id = p_estado.id)
	) INTO v_es_estado_valido;

	RETURN v_es_estado_valido;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_maquina_estado_tiene_transiciones(p_maquina_estado maquina_estado)
RETURNS boolean AS $$
DECLARE
	v_tiene_transiciones boolean;
BEGIN
	SELECT EXISTS (
		SELECT 1
		FROM maquina_estado_transiciones
		WHERE maquina_id = p_maquina_estado.id
	) INTO v_tiene_transiciones;

	RETURN v_tiene_transiciones;
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------
-- Funciones para asociar clases a las maquinas de estado
-----------------------------------------------------------

CREATE OR REPLACE FUNCTION me_maquina_estado_asociar_clase(
	p_maquina_estado maquina_estado,
	p_clase_nombre   regclass )
RETURNS maquina_estado_clase_relacion AS $$
DECLARE
	v_me_clase_relacion maquina_estado_clase_relacion;
	v_me_estado_inicial maquina_estado_estados;
	v_maquina_estado_asociada maquina_estado;
BEGIN
	--Validar que la maquina de estado tenga al menos una transicion
	IF NOT me_maquina_estado_tiene_transiciones(p_maquina_estado) THEN
	--NOTE Voy a quitar el raise para que se pueda asociar la clase a la maquina de estado aunque no tenga transiciones
	--A menos que se desee que la clase no pueda tener transiciones
	--	RAISE EXCEPTION 'La máquina de estado % no tiene transiciones', p_maquina_estado.nombre;
	END IF;

	v_me_estado_inicial := me_maquina_estado_obtener_estado_inicial(p_maquina_estado);
	--Validar que la clase no este ya asociada a una maquina de estado
	v_maquina_estado_asociada := me_maquina_estado_asociada_obtener(p_clase_nombre);
	IF v_maquina_estado_asociada.id IS NOT NULL THEN
		RAISE EXCEPTION 'La clase % ya esta asociada a una maquina de estado: %', p_clase_nombre, v_maquina_estado_asociada.nombre;
	END IF;
	
	INSERT INTO maquina_estado_clase_relacion (
		maquina_id,
		clase_nombre
	) VALUES (
		p_maquina_estado.id,
		p_clase_nombre
	) ON CONFLICT (clase_nombre) DO NOTHING
	RETURNING * INTO v_me_clase_relacion;

	--Crear el trigger para la clase
	EXECUTE format(
		'CREATE TRIGGER %I
		AFTER INSERT ON %I
		FOR EACH ROW
		EXECUTE FUNCTION trigger_insercion_estado_objeto();',
		p_maquina_estado.nombre || '_' || p_clase_nombre::text || '_trigger',
		p_clase_nombre::text
	);

	EXECUTE format(
		'INSERT INTO objeto_instancia_eventos_transicion (objeto_id, objeto_clase, estado_id, evento_descripcion, fecha_evento) 
		 SELECT id, %L::regclass, %s, ''creación'', now() FROM %I',
		p_clase_nombre::text,
		v_me_estado_inicial.id,
		p_clase_nombre::text
	);

	RETURN v_me_clase_relacion;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_maquina_estado_crear_con_asociacion(
	p_nombre_maquina      text,
	p_descripcion_maquina text,
	p_clase_nombre        regclass,
	p_parent              maquina_estado DEFAULT NULL )
RETURNS void AS $$
DECLARE
	v_me maquina_estado;
BEGIN
	v_me := me_maquina_estado_crear(p_nombre_maquina, p_descripcion_maquina, p_parent);
	PERFORM me_maquina_estado_asociar_clase(v_me, p_clase_nombre);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_maquina_estado_asociada_obtener(
	p_objeto_clase regclass )
RETURNS maquina_estado AS $$
DECLARE
	v_rel_me_id integer;
BEGIN
	SELECT m.maquina_id INTO v_rel_me_id 
	FROM maquina_estado_clase_relacion m 
	WHERE m.clase_nombre = p_objeto_clase;
	
	RETURN me_maquina_estado_instancia(v_rel_me_id);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_maquina_estado_remover_asociacion(
	p_maquina_estado maquina_estado,
	p_clase_nombre   regclass )
RETURNS void AS $$
BEGIN
	DELETE FROM maquina_estado_clase_relacion 
	WHERE maquina_id = p_maquina_estado.id 
	AND clase_nombre = p_clase_nombre;
END;
$$ LANGUAGE plpgsql;

---------------------------------------
-- Funciones para los estados
---------------------------------------|

CREATE OR REPLACE FUNCTION me_estado_crear(
	p_nombre         text,
	p_descripcion    text )
RETURNS maquina_estado_estados AS $$
DECLARE
	v_me_estado maquina_estado_estados;
BEGIN
	INSERT INTO maquina_estado_estados (
		nombre,
		descripcion
	) VALUES (
		p_nombre,
		p_descripcion
	) RETURNING * INTO v_me_estado;
	RETURN v_me_estado;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_estado_tiene_transiciones(
	p_estado maquina_estado_estados )
RETURNS boolean AS $$
DECLARE
	v_tiene_transiciones boolean;
BEGIN
	SELECT EXISTS (
		SELECT 1
		FROM maquina_estado_transiciones
		WHERE estado_origen_id = p_estado.id
		OR estado_destino_id = p_estado.id
	) INTO v_tiene_transiciones;

	RETURN v_tiene_transiciones;
END;
$$ LANGUAGE plpgsql STABLE;


CREATE OR REPLACE FUNCTION me_estado_remover( 
	p_estado maquina_estado_estados )
RETURNS void AS $$
BEGIN
	IF me_estado_tiene_transiciones(p_estado) THEN
		RAISE EXCEPTION 'El estado % tiene transiciones configuradas, eliminar la configuración de transiciones asociadas', p_estado.nombre;
	END IF;
	--Eliminar el estado
	DELETE FROM maquina_estado_estados WHERE id = p_estado.id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_estado_instancia(p_id integer)
RETURNS maquina_estado_estados AS $$
DECLARE
	v_me_estado maquina_estado_estados;
BEGIN
	SELECT * INTO v_me_estado FROM maquina_estado_estados WHERE id = p_id;
	RETURN v_me_estado;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_estado_find(p_nombre_estado  text)
RETURNS maquina_estado_estados AS $$
DECLARE
	v_me_estado maquina_estado_estados;
BEGIN
	SELECT * INTO v_me_estado FROM maquina_estado_estados WHERE nombre = p_nombre_estado;
	RETURN v_me_estado;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_estado_es_final(
	p_estado         maquina_estado_estados,
	p_maquina_estado maquina_estado )
RETURNS boolean AS $$
DECLARE
	v_estado_final maquina_estado_estados;
BEGIN
	v_estado_final := me_maquina_estado_obtener_estado_final(p_maquina_estado);
	RETURN v_estado_final.id = p_estado.id;
END;
$$ LANGUAGE plpgsql STABLE;


CREATE OR REPLACE FUNCTION me_estado_es_inicial(
	p_estado_actual maquina_estado_estados,
	p_maquina_estado maquina_estado )
RETURNS boolean AS $$
DECLARE
	v_estado_inicial maquina_estado_estados;
BEGIN
	v_estado_inicial := me_maquina_estado_obtener_estado_inicial(p_maquina_estado);
	RETURN v_estado_inicial.id = p_estado_actual.id;
END;
$$ LANGUAGE plpgsql STABLE;


CREATE OR REPLACE FUNCTION me_estado_obtener_siguiente(
	p_estado_actual maquina_estado_estados,
	p_maquina_estado maquina_estado )
RETURNS maquina_estado_estados AS $$
DECLARE
	v_nuevo_estado_id integer;
BEGIN
	SELECT estado_destino_id INTO v_nuevo_estado_id
	FROM maquina_estado_transiciones m
	WHERE estado_origen_id = p_estado_actual.id
	AND maquina_id = p_maquina_estado.id
	LIMIT 1;

	RETURN me_estado_instancia(v_nuevo_estado_id);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_estado_obtener_anterior(
	p_estado maquina_estado_estados,
	p_maquina_estado maquina_estado )
RETURNS maquina_estado_estados AS $$
DECLARE
	v_nuevo_estado_id integer;
BEGIN
	SELECT estado_origen_id INTO v_nuevo_estado_id
	FROM maquina_estado_transiciones m
	WHERE estado_destino_id = p_estado.id
	AND maquina_id = p_maquina_estado.id
	LIMIT 1;

	RETURN me_estado_instancia(v_nuevo_estado_id);
END;
$$ LANGUAGE plpgsql;


---------------------------------------
-- Funciones para las transiciones
---------------------------------------|

CREATE OR REPLACE FUNCTION me_transicion_crear(
	p_maquina_estado maquina_estado,
	p_estado_origen maquina_estado_estados,
	p_estado_destino maquina_estado_estados )
RETURNS maquina_estado_transiciones AS $$
DECLARE
	v_me_transicion maquina_estado_transiciones;
BEGIN
	INSERT INTO maquina_estado_transiciones (
		maquina_id,
		estado_origen_id,
		estado_destino_id
	) VALUES (
		p_maquina_estado.id,
		p_estado_origen.id,
		p_estado_destino.id
	) ON CONFLICT (maquina_id, estado_origen_id, estado_destino_id) DO NOTHING
	RETURNING * INTO v_me_transicion;
	RETURN v_me_transicion;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_transicion_obtener_instancia(
	p_maquina_estado maquina_estado,
	p_estado_origen maquina_estado_estados,
	p_estado_destino maquina_estado_estados )
RETURNS maquina_estado_transiciones AS $$
DECLARE
	v_me_transicion maquina_estado_transiciones;
BEGIN
	SELECT * INTO v_me_transicion 
	FROM maquina_estado_transiciones 
	WHERE maquina_id = p_maquina_estado.id 
	AND estado_origen_id = p_estado_origen.id 
	AND estado_destino_id = p_estado_destino.id;
	RETURN v_me_transicion;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_borrar_transiciones(
	p_maquina_estado maquina_estado,
	p_eliminar_eventos boolean DEFAULT false )
RETURNS void AS $$
BEGIN
	DELETE FROM maquina_estado_transiciones WHERE maquina_id = p_maquina_estado.id;
	IF p_eliminar_eventos THEN
		WITH clase_relacion AS (
			SELECT clase_nombre 
			FROM maquina_estado_clase_relacion 
			WHERE maquina_id = p_maquina_estado.id
		)
		DELETE FROM objeto_instancia_eventos_transicion WHERE objeto_clase IN (SELECT clase_nombre FROM clase_relacion);
	END IF;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_transicion_remover( 
	p_maquina_estado maquina_estado,
	p_estado_origen maquina_estado_estados,
	p_estado_destino maquina_estado_estados )
RETURNS void AS $$
BEGIN
	IF me_estado_es_final(p_estado_destino, p_maquina_estado) THEN
		DELETE FROM maquina_estado_transiciones 
		WHERE maquina_id = p_maquina_estado.id 
		AND estado_origen_id = p_estado_origen.id 
		AND estado_destino_id = p_estado_destino.id;
	ELSE
		RAISE NOTICE 'Eliminar una transición que no sea final no está implementado';
	END IF;
END;
$$ LANGUAGE plpgsql;

---------------------------------------
-- Funciones para los objetos
---------------------------------------

CREATE OR REPLACE FUNCTION me_objeto_crear_evento_transicion(
	p_objeto_id    integer,
	p_objeto_clase regclass,
	p_estado_id    integer,
	p_evento       text )
RETURNS void AS $$
BEGIN
	INSERT INTO objeto_instancia_eventos_transicion (
		objeto_id,
		objeto_clase,
		estado_id,
		evento_descripcion,
		fecha_evento
	) VALUES (
		p_objeto_id, 
		p_objeto_clase, 
		p_estado_id, 
		p_evento, 
		now()
	);

	RAISE NOTICE 'Cambio de estado exitoso: objeto %:% -> nuevo estado: %', p_objeto_clase, p_objeto_id, (me_estado_instancia(p_estado_id)).nombre;
	REFRESH MATERIALIZED VIEW vista_estado_actual_objeto;	
END;
$$ LANGUAGE plpgsql;

---------------------------------------
-- API de eventos de transicion
---------------------------------------


CREATE OR REPLACE FUNCTION me_objeto_obtener_estado_actual(
	p_objeto_id    integer, 
	p_objeto_clase regclass)
RETURNS maquina_estado_estados AS $$
DECLARE
	v_me_estado_id integer;
BEGIN
	SELECT estado_id INTO v_me_estado_id
	FROM vista_estado_actual_objeto v
	WHERE v.objeto_id = p_objeto_id AND v.objeto_clase = p_objeto_clase;

	RETURN me_estado_instancia(v_me_estado_id);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_objeto_setear_siguiente_estado(
	p_objeto_clase regclass,
	p_objeto_id   integer,
	p_evento      text )
RETURNS void AS $$
DECLARE
	v_me_estado_actual maquina_estado_estados;
	v_nuevo_estado     maquina_estado_estados;
	v_maquina_estado   maquina_estado;
BEGIN
	v_maquina_estado   := me_maquina_estado_asociada_obtener(p_objeto_clase);
	IF v_maquina_estado.id IS NULL THEN
		RAISE EXCEPTION 'No se encontró una máquina de estado asociada para la clase %', p_objeto_clase;
	END IF;

	v_me_estado_actual := me_objeto_obtener_estado_actual(p_objeto_id, p_objeto_clase);
	IF v_me_estado_actual.id IS NULL THEN
		RAISE EXCEPTION 'El objeto %:% no tiene un estado definido', p_objeto_clase, p_objeto_id;
	END IF;

	IF me_estado_es_final(v_me_estado_actual, v_maquina_estado) THEN
		RAISE EXCEPTION 'El estado % es un estado final, no se puede avanzar', v_me_estado_actual.nombre;
	END IF;

	v_nuevo_estado := me_estado_obtener_siguiente(v_me_estado_actual, v_maquina_estado);

	PERFORM me_objeto_crear_evento_transicion(
		p_objeto_id    := p_objeto_id, 
		p_objeto_clase := p_objeto_clase, 
		p_estado_id    := v_nuevo_estado.id, 
		p_evento       := p_evento
	);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_objeto_setear_anterior_estado(
	p_objeto_clase regclass,
	p_objeto_id   integer,
	p_evento      text )
RETURNS void AS $$
DECLARE
	v_me_estado_actual maquina_estado_estados;
	v_nuevo_estado     maquina_estado_estados;
	v_maquina_estado   maquina_estado;
BEGIN
	v_maquina_estado   := me_maquina_estado_asociada_obtener(p_objeto_clase);
	IF v_maquina_estado.id IS NULL THEN
		RAISE EXCEPTION 'No se encontró una máquina de estado asociada para la clase %', p_objeto_clase;
	END IF;

	v_me_estado_actual := me_objeto_obtener_estado_actual(p_objeto_id, p_objeto_clase);
	IF v_me_estado_actual.id IS NULL THEN
		RAISE EXCEPTION 'El objeto %:% no tiene un estado definido', p_objeto_clase, p_objeto_id;
	END IF;

	IF me_estado_es_inicial(v_me_estado_actual, v_maquina_estado) THEN
		RAISE EXCEPTION 'El estado % es un estado inicial, no se puede retroceder', v_me_estado_actual.nombre;
	END IF;

	v_nuevo_estado := me_estado_obtener_anterior(v_me_estado_actual, v_maquina_estado);

	PERFORM me_objeto_crear_evento_transicion(
		p_objeto_id    := p_objeto_id, 
		p_objeto_clase := p_objeto_clase, 
		p_estado_id    := v_nuevo_estado.id, 
		p_evento       := p_evento
	);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_objeto_setear_reiniciar_maquina(
	p_objeto_clase regclass,
	p_objeto_id   integer,
	p_evento      text )
RETURNS void AS $$
DECLARE
	v_me_estado_actual maquina_estado_estados;
	v_nuevo_estado     maquina_estado_estados;
	v_maquina_estado   maquina_estado;
BEGIN
	v_maquina_estado   := me_maquina_estado_asociada_obtener(p_objeto_clase);
	IF v_maquina_estado.id IS NULL THEN
		RAISE EXCEPTION 'No se encontró una máquina de estado asociada para la clase %', p_objeto_clase;
	END IF;

	v_me_estado_actual := me_objeto_obtener_estado_actual(p_objeto_id, p_objeto_clase);
	IF v_me_estado_actual.id IS NULL THEN
		RAISE EXCEPTION 'El objeto %:% no tiene un estado definido', p_objeto_clase, p_objeto_id;
	END IF;

	v_nuevo_estado := me_maquina_estado_obtener_estado_inicial(v_maquina_estado);

	PERFORM me_objeto_crear_evento_transicion(
		p_objeto_id    := p_objeto_id, 
		p_objeto_clase := p_objeto_clase, 
		p_estado_id    := v_nuevo_estado.id, 
		p_evento       := p_evento
	);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_objeto_setear_estado(
	p_objeto_clase regclass,
	p_objeto_id    integer,
	p_estado       maquina_estado_estados,
	p_evento       text )
RETURNS void AS $$
DECLARE
	v_maquina_estado   maquina_estado;
BEGIN
	v_maquina_estado   := me_maquina_estado_asociada_obtener(p_objeto_clase);
	IF v_maquina_estado.id IS NULL THEN
		RAISE EXCEPTION 'No se encontró una máquina de estado asociada para la clase %', p_objeto_clase;
	END IF;

	IF NOT me_maquina_estado_es_estado_valido(p_estado, v_maquina_estado) THEN
		RAISE EXCEPTION 'El estado % no es válido para la máquina de estado %', p_estado.nombre, v_maquina_estado.nombre;
	END IF;

	PERFORM me_objeto_crear_evento_transicion(
		p_objeto_id    := p_objeto_id, 
		p_objeto_clase := p_objeto_clase, 
		p_estado_id    := p_estado.id, 
		p_evento       := p_evento
	);
END;
$$ LANGUAGE plpgsql;


