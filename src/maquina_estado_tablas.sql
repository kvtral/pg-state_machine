-- Tabla de estados de máquina
CREATE TABLE maquina_estado (
	id          serial,
    nombre      text NOT NULL,
    descripcion text,
    parent_id   integer, --no se usa por ahora, aún no se implementa la herencia de maquinas de estado
	PRIMARY KEY (id),
	FOREIGN KEY (parent_id) REFERENCES maquina_estado(id) ON DELETE SET NULL,
	UNIQUE (nombre)
);

-- Tabla de estados de máquina
CREATE TABLE maquina_estado_estados (
	id          serial,
    nombre      text NOT NULL,
    descripcion text,
	PRIMARY KEY (id),
	UNIQUE (nombre)
);

-- Tabla de transiciones de máquina
CREATE TABLE maquina_estado_transiciones (
	id                serial,
	maquina_id        integer NOT NULL,
	estado_origen_id  integer NOT NULL,
	estado_destino_id integer NOT NULL,
	PRIMARY KEY (id),
	FOREIGN KEY (maquina_id) REFERENCES maquina_estado(id) ON DELETE CASCADE,
	FOREIGN KEY (estado_origen_id) REFERENCES maquina_estado_estados(id), --ON DELETE CASCADE,
	FOREIGN KEY (estado_destino_id) REFERENCES maquina_estado_estados(id), --ON DELETE CASCADE,
	UNIQUE (maquina_id, estado_origen_id, estado_destino_id)
);

ALTER TABLE maquina_estado_transiciones 
ADD CONSTRAINT chk_transicion_diferente 
CHECK (estado_origen_id <> estado_destino_id);

CREATE TABLE maquina_estado_clase_relacion (
	id           serial,
	maquina_id   integer NOT NULL,
	clase_nombre regclass NOT NULL,
	PRIMARY KEY (id),
	FOREIGN KEY (maquina_id) REFERENCES maquina_estado(id) ON DELETE CASCADE,
	UNIQUE (clase_nombre)
);

CREATE TABLE objeto_instancia_eventos_transicion (
	id           serial,
	objeto_id    integer NOT NULL, --FIXME relacionarlo con la tabla de objetos clase_nombre
	objeto_clase regclass NOT NULL, --FIXME relacionarlo con la tabla de objetos clase_nombre
	estado_id    integer NOT NULL,
	evento_descripcion  text NOT NULL,
	fecha_evento timestamptz NOT NULL DEFAULT now(),
	PRIMARY KEY (id),
	FOREIGN KEY (estado_id) REFERENCES maquina_estado_estados(id) ON DELETE CASCADE,
	FOREIGN KEY (objeto_clase) REFERENCES maquina_estado_clase_relacion(clase_nombre),--ON DELETE CASCADE,
	UNIQUE (objeto_id, objeto_clase, estado_id, fecha_evento)
);

CREATE VIEW vista_estado_actual_objeto AS
	SELECT DISTINCT ON (objeto_id, objeto_clase) 
		objeto_id, 
		objeto_clase, 
		estado_id, 
		fecha_evento
	FROM objeto_instancia_eventos_transicion
	ORDER BY objeto_id, objeto_clase, fecha_evento DESC
;

CREATE UNIQUE INDEX idx_vista_estado_actual_objeto ON vista_estado_actual_objeto (objeto_id, objeto_clase);

/* 
--constraint que no permita borrar un estado si tiene transiciones
ALTER TABLE maquina_estado_estados ADD CONSTRAINT no_borrar_estado_con_transiciones CHECK (NOT EXISTS (SELECT 1 FROM maquina_estado_transiciones WHERE estado_origen_id = id OR estado_destino_id = id));


 */
