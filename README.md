# Máquina de Estados para PostgreSQL

Este proyecto implementa una máquina de estados configurable dinámicamente para objetos en tablas PostgreSQL.

## Descripción

El sistema permite definir máquinas de estado y asociarlas a tablas específicas, manteniendo un registro histórico de las transiciones de estado de cada objeto.

## Características

- Configuración dinámica de estados y transiciones
- Asociación automática de estados iniciales a nuevos objetos
- Registro histórico de transiciones
- Validación de transiciones permitidas
- Prevención de transiciones desde estados finales

## Estructura de Tablas

### Tablas Principales

1. `maquina_estado`: Define las máquinas de estado
2. `maquina_estado_estados`: Almacena los estados posibles
3. `maquina_estado_transiciones`: Define las transiciones permitidas
4. `maquina_estado_clase_relacion`: Asocia máquinas de estado con tablas
5. `objeto_instancia_eventos_transicion`: Registra el historial de transiciones

## API de Funciones

### Creación y Configuración

```sql
-- Crear una máquina de estado
SELECT maquina_estado_crear(
    p_nombre := 'nombre_maquina',
    p_descripcion := 'descripción'
);

-- Crear estados
SELECT maquina_estado_crear_estado(
    p_nombre := 'nombre_estado',
    p_descripcion := 'descripción'
);

-- Definir transiciones
SELECT maquina_estado_crear_transicion(
    p_maquina_estado := maquina_estado_find('nombre_maquina'),
    p_estado_origen := maquina_estado_find_estado('estado_origen'),
    p_estado_destino := maquina_estado_find_estado('estado_destino')
);

-- Asociar con una tabla
SELECT maquina_estado_asociar_clase(
    p_maquina_estado := maquina_estado_find('nombre_maquina'),
    p_clase_nombre := 'nombre_tabla'
);
```

### Operaciones de Estado

```sql
-- Obtener estado actual
SELECT maquina_estado_obtener_estado_actual_objeto(
    p_objeto_id := id_objeto,
    p_objeto_clase := 'nombre_tabla'
);

-- Cambiar estado
SELECT maquina_estado_cambiar_estado_objeto(
    p_objeto_clase := 'nombre_tabla',
    p_objeto_id := id_objeto,
    p_evento := 'descripción_evento'
);
```

## Ejemplo de Uso

Ver el archivo `ejemplos.sql` para un ejemplo completo de implementación que incluye:
1. Creación de una tabla de prueba
2. Configuración de una máquina de estado
3. Creación de estados y transiciones
4. Asociación con una tabla
5. Manipulación de estados de objetos

## Consideraciones

- Los estados finales no permiten transiciones posteriores
- Cada objeto debe tener un estado inicial al crearse
- Las transiciones solo pueden ocurrir entre estados definidos
- Se mantiene un historial completo de transiciones

## Limitaciones Actuales

- Una tabla solo puede tener una máquina de estado asociada
- No se pueden eliminar estados que tengan transiciones asociadas
- Las transiciones son unidireccionales

## TODO List
### Tareas pendientes para esta primera versión
- [ ] Generar un constraint para no permitir la eliminación de un estado existente en una transición.
- [ ] Funciones para la eliminación de definiciones de maquinas, estados, transiciones y asociaciones.
### Tareas pendientes para futuras versiones
- [ ] Permitir bifurcaciones y cambios de estados multidireccionales.
- [ ] Definición de estados finales e iniciales en una máquina de estado.

- [ ] Estoy abierto a sugerencia o indicaciones de cambios.


## Autor
* Álvaro J. Carrillanca [kvtral](https://github.com/kvtral)

alvaro (dot) carrillanca (at) gmail (dot) com