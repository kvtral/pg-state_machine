
CREATE OR REPLACE FUNCTION trigger_insercion_estado_objeto()
RETURNS trigger AS $$
DECLARE
	v_estado_inicial maquina_estado_estados;
BEGIN
	v_estado_inicial := me_maquina_estado_obtener_estado_inicial(me_maquina_estado_asociada_obtener(TG_TABLE_NAME::regclass));
	IF v_estado_inicial.id IS NOT NULL THEN
		INSERT INTO objeto_instancia_eventos_transicion (
			objeto_id,
			objeto_clase,
			estado_id,
			evento_descripcion,
			fecha_evento
		) VALUES (
			NEW.id,
			TG_TABLE_NAME::regclass,
			v_estado_inicial.id,
			'creación',
			now()
		);
	END IF;
--	REFRESH MATERIALIZED VIEW vista_estado_actual_objeto;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_trigger_existe(
	p_maquina_estado maquina_estado,
	p_clase_nombre   regclass )
RETURNS boolean AS $$
DECLARE
	v_me_trigger_existe boolean;
BEGIN
	SELECT EXISTS (
		SELECT 1
		FROM pg_trigger
		WHERE tgname = p_maquina_estado.nombre || '_' || p_clase_nombre::text || '_trigger'
	) INTO v_me_trigger_existe;
	
	RETURN v_me_trigger_existe;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION me_trigger_remover(
	p_maquina_estado maquina_estado,
	p_clase_nombre   regclass )
RETURNS void AS $$
BEGIN
	IF me_trigger_existe(p_maquina_estado, p_clase_nombre) THEN
		DROP TRIGGER IF EXISTS p_maquina_estado.nombre || '_' || p_clase_nombre::text || '_trigger' ON p_clase_nombre;
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION me_trigger_creacion(
	p_maquina_estado maquina_estado,
	p_clase_nombre   regclass )
RETURNS void AS $$
DECLARE
	v_me_estado_inicial maquina_estado_estados;
BEGIN
	PERFORM me_trigger_remover(p_maquina_estado, p_clase_nombre);
	
	EXECUTE format(
		'CREATE TRIGGER %I
		AFTER INSERT ON %I
		FOR EACH ROW
		EXECUTE FUNCTION trigger_insercion_estado_objeto();',
		p_maquina_estado.nombre || '_' || p_clase_nombre::text || '_trigger',
		p_clase_nombre::text
	);
	--Insertar el evento de creación en el estado inicial
	EXECUTE format(
		'INSERT INTO objeto_instancia_eventos_transicion (objeto_id, objeto_clase, estado_id, evento_descripcion, fecha_evento) 
		 SELECT id, %L::regclass, %s, ''creación'', now() FROM %I',
		p_clase_nombre::text,
		v_me_estado_inicial.id,
		p_clase_nombre::text
	);
END;
$$ LANGUAGE plpgsql;
