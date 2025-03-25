# Máquina de Estados para PostgreSQL

Este proyecto implementa una máquina de estados configurable dinámicamente para objetos en tablas PostgreSQL.

## Descripción

El sistema permite definir máquinas de estado, estados independientes, configurar transiciones para cada máquina de estado y asociarlas a tablas específicas, manteniendo un registro histórico de las transiciones de estado de cada objeto.

## Características

- Configuración dinámica de estados y transiciones
- Asociación automática de estados iniciales a nuevos objetos mediante un trigger.
- Registro histórico de transiciones
- Validación de transiciones permitidas
- API única para transicionar estado de un objeto, con un ENUM `comando_transicion`:
  - `AVANZAR`,    --Avanzar a la siguiente transicion
  - `RETROCEDER`, --Retroceder a la transicion anterior
  - `REINICIAR`,  --Reiniciar la maquina de estado
  - `SETEAR`      --Establecer un estado en particular
- Prevención de transiciones `AVANZAR` desde estados finales o `RETROCEDER` desde estados iniciales

## Estructura de Tablas

### Tablas Principales

1. `maquina_estado`: Define las máquinas de estado
2. `maquina_estado_estados`: Almacena los estados posibles
3. `maquina_estado_transiciones`: Define las transiciones permitidas
4. `maquina_estado_clase_relacion`: Asocia máquinas de estado con tablas
5. `objeto_instancia_eventos_transicion`: Registra el historial de transiciones

## API de Funciones

### Creación y Configuración

#### Máquina de Estado

```sql
-- Crear una máquina de estado
SELECT me_maquina_estado_crear(
	p_nombre := 'nombre_maquina',
	p_descripcion := 'descripción'
);

-- Obtener una máquina de estado
SELECT me_maquina_estado_find('nombre_maquina');

-- Obtener todas las máquinas de estado
SELECT me_obtener_maquinas_estado();

-- Eliminar una máquina de estado
SELECT me_maquina_estado_remover(
    p_maquina_estado := me_maquina_estado_find('nombre_maquina')
);

```

#### Estados

```sql
-- Crear un estado
SELECT me_estado_crear(
    p_nombre      := 'nombre_estado',
    p_descripcion := 'descripción'
);

-- Obtener un estado
SELECT me_estado_find('nombre_estado');

-- Obtener todos los estados
SELECT me_obtener_estados();

-- Eliminar un estado
SELECT me_estado_remover(
    p_estado := me_estado_find('nombre_estado')
);
```

#### Transiciones

```sql
-- Crear una transición
SELECT me_transicion_crear(
	p_maquina_estado := me_maquina_estado_find('nombre_maquina'),
	p_estado_origen  := me_estado_find('estado_origen'),
	p_estado_destino := me_estado_find('estado_destino')
);

-- Eliminar una transición
SELECT me_transicion_remover(
	p_maquina_estado := me_maquina_estado_find('nombre_maquina'),
	p_estado_origen  := me_estado_find('estado_origen'),
	p_estado_destino := me_estado_find('estado_destino')
);

-- Limpiar transiciones y eventos de una máquina de estado
SELECT me_limpiar_transiciones(
	p_maquina_estado   := me_maquina_estado_find('nombre_maquina'),
	p_eliminar_eventos := true --DEFAULT false para no eliminar eventos registrados.
);

```

#### Asociación de Clase

```sql
-- Asociar una clase a una máquina de estado
SELECT me_maquina_estado_asociar_clase(
	p_maquina_estado := me_maquina_estado_find('nombre_maquina'),
	p_clase_nombre   := 'nombre_tabla'
);

-- Crear una máquina de estado con asociación de clase
SELECT me_maquina_estado_crear_con_asociacion(
	p_nombre_maquina      := 'nombre_maquina',
	p_descripcion_maquina := 'descripción_maquina',
	p_clase_nombre        := 'nombre_tabla'
);

-- Eliminar la asociación de una clase a una máquina de estado
SELECT me_maquina_estado_remover_asociacion(
	p_maquina_estado := me_maquina_estado_find('nombre_maquina'),
	p_clase_nombre   := 'nombre_tabla'
);

-- Obtener la máquina de estado asociada a una clase
SELECT me_maquina_estado_asociada_obtener('nombre_tabla');

-- Obtener las clases asociadas a una máquina de estado
SELECT me_obtener_clases_asociadas(
	p_maquina_estado := me_maquina_estado_find('nombre_maquina')
);
```

#### Eventos de Transicion

Para manejar los eventos de transicion, se utiliza una función que recibe ENUM `comando_transicion` y los parámetros necesarios para realizar la transicion.

```sql
-- Obtener estado actual
SELECT me_objeto_obtener_estado_actual(
	p_objeto_id := id_objeto,
	p_objeto_clase := 'nombre_tabla'
);

-- Crear evento de transicion sin setear estado
SELECT me_objeto_crear_evento_transicion(
	p_comando      := 'AVANZAR',
	p_objeto_id    := id_objeto,
	p_objeto_clase := 'nombre_tabla',
	p_evento       := 'descripción_evento'
);

-- Crear evento de transicion seteando estado
SELECT me_objeto_crear_evento_transicion(
	p_comando      := 'SETEAR',
	p_objeto_id    := id_objeto,
	p_objeto_clase := 'nombre_tabla',
	p_evento       := 'descripción_evento',
	p_estado       := me_estado_find('estado_a_setear')
);
```
Observación: Dado que el único comando que setea un estado es `SETEAR`, para los otros comandos el parametro p_estado no se será utilizado aunque fuera explicitado.


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
~~- Las transiciones son unidireccionales~~

## Instalación

Se crea un script de instalación para asegurar el orden y la instalación de todos los scripts de PL ya que se separaron en diferentes fuentes para un mayor orden, y para explicitar cuales son las funciones de uso público.

Dar permiso de ejecución del script
```
chmod +x maquina_estado_instalar.sh
```
ejecutar en la carpeta donde está el script
```
./maquina_estado_instalar.sh SERVER PUERTO NOMBRE_BBDD
```
## TODO List
### Tareas pendientes corto plazo
- [ ] Permitir clases asociadas a maquinas de estado sin transiciones, por ahora se lanza una excepción cuando se intenta asociar a una maquina sin transiciones configuradas, 

### Tareas pendientes para futuras versiones
- [ ] Permitir bifurcaciones y cambios de estados multidireccionales.
- [ ] Definición de estados finales e iniciales en una máquina de estado.
- [ ] Al eliminar un estado de una transición, se deben reconectar los estados restantes para no dejar transiciones huerfanas. Por ahora no permite eliminar un estado si existe en una transición.
- [ ] Permitir eliminar una transición. Cualquiera sea, por ahora permito sólo eliminar la transición si es la última.
- [ ] Actualmente se obliga a una continuidad bidimensional, pero pueden haber estados que son finales y tienen multiples origenes (como un estado 'cancelado', por ejemplo), asi también, una maquina de estado puede tener múltiples finales ('entregado', 'cancelado'). No se si tenga que cambiar la estructura de toda la implementación para permitir esto. Por ahora tengo la inquietud.

# Cambios en la nueva versión
## Los cambios principales incluyen:
- Actualización de los nombres de las funciones con el prefijo me_ para mantener consistencia
- Se cambia uso de función para setear estado, a 3 que permiten next, previous, reset y un set:
>  `me_objeto_setear_siguiente_estado`
>  `me_objeto_setear_anterior_estado`
>  `me_objeto_setear_reiniciar_maquina`
- Al insertar una transición se ejecuta una serie de validaciones mediante `me_transicion_validacion`, forzando la declaración de transiciones de forma "cronológica", para evitar inconsistencias (lanza una excepción)
  - la primera declaración debe ser de la transición original 
  - las posteriores validan que el estado inicial sea el destino en una transición.
  - que el estado no pueda ser origen o destino más de una vez en la maquina de estado, esto es para evitar que se creen maquinas de estado circulares.

Actualización de los nombres de las funciones existentes:
* `maquina_estado_crear` -> `me_maquina_estado_crear`
* `maquina_estado_crear_estado` -> `me_estado_crear`
* `maquina_estado_crear_transicion` -> `me_transicion_crear`
* `maquina_estado_asociar_clase` -> `me_maquina_estado_asociar_clase`
* `maquina_estado_obtener_estado_actual_objeto` -> `me_objeto_obtener_estado_actual`
* `maquina_estado_cambiar_estado_objeto` -> `me_objeto_setear_siguiente_estado`

## Autor
* Álvaro J. Carrillanca [kvtral](https://github.com/kvtral)

Estoy abierto a sugerencias o indicaciones de cambios:	
alvaro (dot) carrillanca (at) gmail (dot) com
