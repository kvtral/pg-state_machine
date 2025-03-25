
CREATE OR REPLACE FUNCTION me_transicion_crear(
	p_maquina_estado maquina_estado,
	p_estado_origen maquina_estado_estados,
	p_estado_destino maquina_estado_estados )
RETURNS maquina_estado_transiciones AS $$
DECLARE
	v_me_transicion maquina_estado_transiciones;
BEGIN
	PERFORM me_transicion_validacion(p_maquina_estado, p_estado_origen, p_estado_destino);

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


CREATE OR REPLACE FUNCTION me_limpiar_transiciones(
	p_maquina_estado   maquina_estado,
	p_eliminar_eventos boolean DEFAULT false )
RETURNS void AS $$
BEGIN
	DELETE FROM maquina_estado_transiciones WHERE maquina_id = p_maquina_estado.id;
	PERFORM me_maquina_estado_remover_asociacion(p_maquina_estado, clase_nombre)
		FROM me_obtener_clases_asociadas(p_maquina_estado) AS clase_nombre;

	IF p_eliminar_eventos THEN
		DELETE FROM objeto_instancia_eventos_transicion 
		WHERE objeto_clase IN (
			SELECT * FROM me_obtener_clases_asociadas(p_maquina_estado)
		);
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
-- API de eventos de transicion
---------------------------------------

CREATE OR REPLACE FUNCTION me_objeto_cambiar_estado(
	p_comando      comando_transicion,
	p_objeto_id    integer,
	p_objeto_clase regclass,
	p_evento       text )
RETURNS void AS $$
BEGIN
	PERFORM me_objeto_cambiar_estado(
		p_comando      := p_comando,
		p_objeto_id    := p_objeto_id,
		p_objeto_clase := p_objeto_clase,
		p_evento       := p_evento,
		p_estado       := NULL
	);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_objeto_cambiar_estado(
	p_comando      comando_transicion,
	p_objeto_id    integer,
	p_objeto_clase regclass,
	p_evento       text,
	p_estado       maquina_estado_estados DEFAULT NULL )
RETURNS void AS $$
DECLARE
	v_maquina_estado   maquina_estado;
BEGIN
	v_maquina_estado   := me_maquina_estado_asociada_obtener(p_objeto_clase);
	IF v_maquina_estado.id IS NULL THEN
		RAISE EXCEPTION 'No se encontró una máquina de estado asociada para la clase %', p_objeto_clase;
	END IF;
	IF p_comando = 'AVANZAR' THEN
		PERFORM me_objeto_setear_siguiente_estado(p_objeto_id, p_objeto_clase, p_evento, v_maquina_estado);
	ELSIF p_comando = 'RETROCEDER' THEN
		PERFORM me_objeto_setear_anterior_estado(p_objeto_id, p_objeto_clase, p_evento, v_maquina_estado);
	ELSIF p_comando = 'REINICIAR' THEN
		PERFORM me_objeto_setear_reiniciar_maquina(p_objeto_id, p_objeto_clase, p_evento, v_maquina_estado);
	ELSIF p_comando = 'SETEAR' THEN
		PERFORM me_objeto_setear_estado(p_objeto_id, p_objeto_clase, p_estado, p_evento, v_maquina_estado);
	END IF;
END;
$$ LANGUAGE plpgsql;


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