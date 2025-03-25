
DB_USER=$1
DB_HOST=$2
DB_PORT=$3
DB_NAME=$4

# concatenar los archivos en un solo archivo
cat src/maquina_estado_tablas.sql src/maquina_estado_funciones.sql src/maquina_estado_apis.sql src/me_transicion_apis.sql src/me_estado_apis.sql src/maquina_estado_trigger.sql > src/maquina_estado_instalar.sql

# ejecutar el script
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f src/maquina_estado_instalar.sql

# eliminar el archivo temporal
rm src/maquina_estado_instalar.sql