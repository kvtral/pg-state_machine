
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


CREATE OR REPLACE FUNCTION me_estado_find(p_nombre_estado  text)
RETURNS maquina_estado_estados AS $$
DECLARE
	v_me_estado maquina_estado_estados;
BEGIN
	SELECT * INTO v_me_estado FROM maquina_estado_estados WHERE nombre = p_nombre_estado;
	RETURN v_me_estado;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION me_obtener_estados()
RETURNS SETOF maquina_estado_estados AS $$
BEGIN
	RETURN QUERY SELECT * FROM maquina_estado_estados;
END;
$$ LANGUAGE plpgsql;
