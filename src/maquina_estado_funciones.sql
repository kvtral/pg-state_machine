
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
		id(maquina_estado_obtener_estado_inicial(maquina_estado_obtener_maquina_estado(TG_TABLE_NAME::regclass))),
		'creación',
		now()
	);
	REFRESH MATERIALIZED VIEW vista_estado_actual_objeto;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION maquina_estado_crear(
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


CREATE OR REPLACE FUNCTION maquina_estado_crear_estado(
--	maquina_estado maquina_estado,
	p_nombre         text,
	p_descripcion    text )
--	es_default     boolean DEFAULT FALSE )
--	parent         maquina_estado_estados DEFAULT NULL )
RETURNS maquina_estado_estados AS $$
DECLARE
	v_me_estado maquina_estado_estados;
BEGIN
	INSERT INTO maquina_estado_estados (
--		maquina_id,
		nombre,
		descripcion
--		es_default
--		parent_id
	) VALUES (
--		maquina_estado.id,
		p_nombre,
		p_descripcion
--		es_default
--		parent.id
	) RETURNING * INTO v_me_estado;
	RETURN v_me_estado;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION maquina_estado_crear_transicion(
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


CREATE OR REPLACE FUNCTION maquina_estado_obtener_estado_inicial(p_maquina_estado maquina_estado)
RETURNS maquina_estado_estados AS $$
DECLARE
	v_me_estado maquina_estado_estados;
BEGIN
	WITH 
	origenes AS (
		SELECT DISTINCT estado_origen_id AS estado_id
		FROM maquina_estado_transiciones
		WHERE maquina_id = p_maquina_estado.id
	), 
	destinos AS (
		SELECT DISTINCT estado_destino_id AS estado_id
		FROM maquina_estado_transiciones
		WHERE maquina_id = p_maquina_estado.id
	)
	SELECT e.* INTO v_me_estado
	FROM maquina_estado_estados e
	WHERE e.id IN (SELECT estado_id FROM origenes)
	AND e.id NOT IN (SELECT estado_id FROM destinos)
	LIMIT 1;
 
	IF v_me_estado IS NULL THEN
		RAISE EXCEPTION 'No se pudo determinar el estado inicial para la máquina de estado: %', maquina_estado.nombre;
	END IF;

	RETURN v_me_estado;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION maquina_estado_asociar_clase(
	p_maquina_estado maquina_estado,
	p_clase_nombre   regclass )
RETURNS maquina_estado_clase_relacion AS $$
DECLARE
	v_me_clase_relacion maquina_estado_clase_relacion;
	v_me_estado_inicial maquina_estado_estados;
BEGIN
	--Validar que la maquina de estado tenga al menos una transicion
	IF NOT maquina_estado_tiene_transiciones(p_maquina_estado) THEN
		RAISE EXCEPTION 'La máquina de estado % no tiene transiciones', p_maquina_estado.nombre;
	END IF;

	v_me_estado_inicial := maquina_estado_obtener_estado_inicial(p_maquina_estado);
	--Validar que la clase no este ya asociada a la maquina de estado
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


CREATE OR REPLACE FUNCTION maquina_estado_crear_maquina_asociada_con_transicion_inicial(
	nombre_maquina      text,
	descripcion_maquina text,
	clase_nombre        regclass,
	estado_inicial      maquina_estado_estados,
	estado_objetivo     maquina_estado_estados,
	parent              maquina_estado DEFAULT NULL )
RETURNS void AS $$
DECLARE
	v_me maquina_estado;
BEGIN
	v_me := maquina_estado_crear(nombre_maquina, descripcion_maquina, parent);
	PERFORM maquina_estado_crear_transicion(v_me, estado_inicial, estado_objetivo);
	PERFORM maquina_estado_asociar_clase(v_me, clase_nombre);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION maquina_estado_instancia(p_id integer )
RETURNS maquina_estado AS $$
DECLARE
	v_me maquina_estado;
BEGIN
	SELECT m.* INTO v_me FROM maquina_estado m WHERE m.id = p_id;
	RETURN v_me;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION maquina_estado_find(p_nombre text )
RETURNS maquina_estado AS $$
DECLARE
	v_me maquina_estado;
BEGIN
	SELECT * INTO v_me FROM maquina_estado WHERE nombre = p_nombre;
	RETURN v_me;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION maquina_estado_instancia_estado(p_id integer)
RETURNS maquina_estado_estados AS $$
DECLARE
	v_me_estado maquina_estado_estados;
BEGIN
	SELECT * INTO v_me_estado FROM maquina_estado_estados WHERE id = p_id;
	RETURN v_me_estado;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION maquina_estado_find_estado(p_nombre_estado  text)
RETURNS maquina_estado_estados AS $$
DECLARE
	v_me_estado maquina_estado_estados;
BEGIN
	SELECT * INTO v_me_estado FROM maquina_estado_estados WHERE nombre = p_nombre_estado;
	RETURN v_me_estado;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION maquina_estado_obtener_estado_actual_objeto(
	p_objeto_id    integer, 
	p_objeto_clase regclass)
RETURNS maquina_estado_estados AS $$
DECLARE
	v_me_estado_id integer;
BEGIN
    -- Obtener el estado actual
    SELECT estado_id INTO v_me_estado_id
    FROM vista_estado_actual_objeto v
	WHERE v.objeto_id = p_objeto_id AND v.objeto_clase = p_objeto_clase;

	RETURN maquina_estado_instancia_estado(v_me_estado_id);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION maquina_estado_es_estado_final(
	p_estado_actual maquina_estado_estados,
	p_maquina_estado maquina_estado )
RETURNS boolean AS $$
DECLARE
	v_tiene_transicion boolean;
BEGIN
	SELECT EXISTS (
		SELECT 1
		FROM maquina_estado_transiciones
		WHERE estado_origen_id = p_estado_actual.id
		AND maquina_id = p_maquina_estado.id
	) INTO v_tiene_transicion;

	RETURN NOT v_tiene_transicion;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION maquina_estado_obtener_estado_siguiente(
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

	RETURN maquina_estado_instancia_estado(v_nuevo_estado_id);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION maquina_estado_obtener_maquina_estado(p_objeto_clase regclass)
RETURNS maquina_estado AS $$
DECLARE
	v_rel_me_id integer;
BEGIN
	SELECT m.maquina_id INTO v_rel_me_id 
	FROM maquina_estado_clase_relacion m 
	WHERE m.clase_nombre = p_objeto_clase;
	
	RETURN maquina_estado_instancia(v_rel_me_id);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION maquina_estado_tiene_transiciones(p_maquina_estado maquina_estado)
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


CREATE OR REPLACE FUNCTION maquina_estado_cambiar_estado_objeto(
	p_objeto_clase regclass,
	p_objeto_id   integer,
	p_evento      text )
RETURNS void AS $$
DECLARE
	v_me_estado_actual maquina_estado_estados;
	v_nuevo_estado     maquina_estado_estados;
	v_maquina_estado   maquina_estado;
BEGIN
	v_maquina_estado   := maquina_estado_obtener_maquina_estado(p_objeto_clase);

	IF v_maquina_estado.id IS NULL THEN
		RAISE EXCEPTION 'No se encontró una máquina de estado asociada para la clase %', p_objeto_clase;
	END IF;

	v_me_estado_actual := maquina_estado_obtener_estado_actual_objeto(p_objeto_id, p_objeto_clase);

	IF v_me_estado_actual.id IS NULL THEN
		RAISE EXCEPTION 'El objeto %:% no tiene un estado definido', p_objeto_clase, p_objeto_id;
	END IF;

	IF maquina_estado_es_estado_final(v_me_estado_actual, v_maquina_estado) THEN
		RAISE EXCEPTION 'El estado % es un estado final', v_me_estado_actual.nombre;
	END IF;

	v_nuevo_estado := maquina_estado_obtener_estado_siguiente(v_me_estado_actual, v_maquina_estado);

	INSERT INTO objeto_instancia_eventos_transicion (
		objeto_id,
		objeto_clase,
		estado_id,
		evento_descripcion,
		fecha_evento
	) VALUES (p_objeto_id, p_objeto_clase, v_nuevo_estado.id, p_evento, NOW());

	REFRESH MATERIALIZED VIEW vista_estado_actual_objeto;

	RAISE NOTICE 'Cambio de estado exitoso: objeto %:% -> nuevo estado %', p_objeto_clase, p_objeto_id, v_nuevo_estado;

END;
$$ LANGUAGE plpgsql;





