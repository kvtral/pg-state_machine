
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


CREATE OR REPLACE FUNCTION me_obtener_maquinas_estado()
RETURNS SETOF maquina_estado AS $$
BEGIN
	RETURN QUERY SELECT * FROM maquina_estado;
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
	--FIXME Ver como hacer para que el trigger se cree tambien si no tiene transiciones configuradas, una vez configurado un estado inicial
		RAISE EXCEPTION 'La máquina de estado % no tiene transiciones', p_maquina_estado.nombre;
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

	IF v_me_estado_inicial.id IS NOT NULL THEN
		--Crear el trigger para la clase
		PERFORM me_trigger_creacion(p_maquina_estado, p_clase_nombre);
	END IF;

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


CREATE OR REPLACE FUNCTION me_obtener_clases_asociadas(
	p_maquina_estado maquina_estado )
RETURNS SETOF regclass AS $$
BEGIN
	RETURN QUERY 
		SELECT m.clase_nombre 
		FROM maquina_estado_clase_relacion m 
		WHERE m.maquina_id = p_maquina_estado.id
	;
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

	PERFORM me_trigger_remover(p_maquina_estado, p_clase_nombre);
END;
$$ LANGUAGE plpgsql;