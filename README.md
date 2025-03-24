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
SELECT me_maquina_estado_crear(
    p_nombre := 'nombre_maquina',
    p_descripcion := 'descripción'
);

-- Crear estados
SELECT me_estado_crear(
    p_nombre := 'nombre_estado',
    p_descripcion := 'descripción'
);

-- Definir transiciones
SELECT me_transicion_crear(
    p_maquina_estado := me_maquina_estado_find('nombre_maquina'),
    p_estado_origen := me_estado_find('estado_origen'),
    p_estado_destino := me_estado_find('estado_destino')
);

-- Asociar con una tabla
SELECT me_maquina_estado_asociar_clase(
    p_maquina_estado := me_maquina_estado_find('nombre_maquina'),
    p_clase_nombre := 'nombre_tabla'
);
```

### Operaciones de Estado

```sql
-- Obtener estado actual
SELECT me_objeto_obtener_estado_actual(
    p_objeto_id := id_objeto,
    p_objeto_clase := 'nombre_tabla'
);

-- Cambiar al siguiente estado
SELECT me_objeto_setear_siguiente_estado(
    p_objeto_clase := 'nombre_tabla',
    p_objeto_id := id_objeto,
    p_evento := 'descripción_evento'
);

-- Cambiar al estado anterior
SELECT me_objeto_setear_anterior_estado(
    p_objeto_clase := 'nombre_tabla',
    p_objeto_id := id_objeto,
    p_evento := 'descripción_evento'
);

-- Reiniciar al estado inicial
SELECT me_objeto_setear_reiniciar_maquina(
    p_objeto_clase := 'nombre_tabla',
    p_objeto_id := id_objeto,
    p_evento := 'descripción_evento'
);

-- Setear un estado especifico
SELECT me_objeto_setear_estado(
	p_objeto_clase := 'nombre_tabla',
	p_objeto_id    := id_objeto,
	p_estado       := me_estado_find('estado_a_setear'),
	p_evento       := 'Descripción del evento
);

```

## Ejemplo de Uso

Ver el archivo `ejemplos.sql` para un ejemplo completo de implementación que incluye:
1. Creación de una tabla de prueba
2. Configuración de una máquina de estado
3. Creación de estados y transiciones
4. Asociación con una tabla
5. Manipulación de estados de objetos (next, previous, reset)
6. Eliminación de transiciones de una maquina de estado
7. Eliminación de máquina de estados.

## Consideraciones

- Los estados finales no permiten transiciones posteriores
- Cada objeto debe tener un estado inicial al crearse
- Las transiciones solo pueden ocurrir entre estados definidos
- Se mantiene un historial completo de transiciones

## Limitaciones Actuales

- Una tabla solo puede tener una máquina de estado asociada
- No se pueden eliminar estados que tengan transiciones asociadas
- Sin embargo se puede eliminar toda la configuración de transiciones para una máquina de estados (con posibilidad de eliminar todos los eventos asociados).
- Las transiciones son unidireccionales

## TODO List
### Tareas pendientes para esta primera versión
- [X] Generar un constraint para no permitir la eliminación de un estado existente en una transición.
- [X] Funciones para la eliminación de definiciones de maquinas, estados, transiciones y asociaciones.
### Tareas pendientes para futuras versiones
- [ ] Permitir bifurcaciones y cambios de estados multidireccionales.
- [ ] Definición de estados finales e iniciales en una máquina de estado.
- [ ] Al eliminar un estado de una transición, se deben reconectar los estados restantes para no dejar transiciones huerfanas. Por ahora no permite eliminar un estado si existe en una transición.
- [ ] Permitir eliminar una transición. Cualquiera sea, por ahora permito sólo eliminar la transición si es la última.

- [ ] Estoy abierto a sugerencia o indicaciones de cambios.


# Cambios en la nueva versión
## Los cambios principales incluyen:
* Actualización de los nombres de las funciones con el prefijo me_ para mantener consistencia
* Se cambia uso de función para setear estado, a 3 que permiten next, previous, reset y un set:
** `me_objeto_setear_siguiente_estado`
** `me_objeto_setear_anterior_estado`
** `me_objeto_setear_reiniciar_maquina`

Actualización de los nombres de las funciones existentes:
`maquina_estado_crear` -> `me_maquina_estado_crear`
`maquina_estado_crear_estado` -> `me_estado_crear`
`maquina_estado_crear_transicion` -> `me_transicion_crear`
`maquina_estado_asociar_clase` -> `me_maquina_estado_asociar_clase`
`maquina_estado_obtener_estado_actual_objeto` -> `me_objeto_obtener_estado_actual`
`maquina_estado_cambiar_estado_objeto` -> `me_objeto_setear_siguiente_estado`


## Autor
* Álvaro J. Carrillanca [kvtral](https://github.com/kvtral)

alvaro (dot) carrillanca (at) gmail (dot) com