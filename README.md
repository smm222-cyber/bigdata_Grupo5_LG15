# LG15 - Tolerancia a fallos y replicación de datos en HDFS

## 1. Descripción del proyecto

Este proyecto implementa y evalúa un clúster HDFS con un **NameNode**, tres
**DataNodes** y un cliente Hadoop. El objetivo es observar qué ocurre cuando
un DataNode deja de estar disponible y comprobar si HDFS mantiene el acceso al
archivo, detecta los bloques subreplicados y crea nuevas réplicas.

El trabajo se relaciona con **LG14** porque utiliza la arquitectura y los
conceptos de Hadoop/HDFS estudiados allí: NameNode, DataNodes, bloques,
factor de replicación, comandos HDFS y monitoreo del clúster. LG15 amplía esa
base con pruebas controladas de fallo y recuperación automática.

Se ejecutaron dos experimentos:

- Archivo de **1 GB**, con replicación 2; se detuvo el DataNode 2.
- Archivo de **10 GB**, con replicación 2; se detuvo el DataNode 3.

## 2. Arquitectura y diagrama

La configuración se encuentra en [`docker-compose.yml`](./docker-compose.yml).
El NameNode administra los metadatos y la ubicación de los bloques; los
DataNodes almacenan las réplicas; y el cliente ejecuta las operaciones HDFS.

```mermaid
flowchart TB
    C[grupo05-client<br/>Cliente Hadoop]
    N[grupo05-namenode<br/>NameNode<br/>9870 / 8020]
    D1[grupo05-datanode1<br/>DN1 - 172.19.0.4]
    D2[grupo05-datanode2<br/>DN2 - 172.19.0.6]
    D3[grupo05-datanode3<br/>DN3 - 172.19.0.5]

    C -->|comandos HDFS y lectura| N
    N -->|metadatos y asignación| D1
    N -->|metadatos y asignación| D2
    N -->|metadatos y asignación| D3
    C -->|escritura/lectura de bloques| D1
    C -->|escritura/lectura de bloques| D2
    C -->|escritura/lectura de bloques| D3
```

Mapa de direcciones: [`mapa_ips.txt`](./grupo05_resultados/mapa_ips.txt).

Capturas generales del clúster:

- [Contenedores activos](./grupo05_evidencias/01-dockerps.png)
- [DataNodes en la interfaz web](./grupo05_evidencias/02-datanodes_web.png)
- [Reporte inicial](./grupo05_evidencias/03-report_inicial.png)
- [Configuración HDFS](./grupo05_evidencias/04-configuracion.png)
- [Mapa de IPs](./grupo05_evidencias/05-mapa_ips.png)
- [Directorios HDFS](./grupo05_evidencias/06-directorios_hdfs.png)

## 3. Requisitos

- Docker Desktop con Docker Compose.
- PowerShell.
- Espacio suficiente en disco para las imágenes y los archivos de prueba.
- Puertos `9870` y `8020` disponibles.

Verificar la instalación:

```powershell
docker --version
docker compose version
```

## 4. Instalación y ejecución

Ejecutar los comandos desde la carpeta raíz del repositorio.

### Fase 2: levantar y verificar el clúster

```powershell
docker compose up -d
docker ps
docker exec grupo05-client hdfs dfsadmin -report
docker exec grupo05-client hdfs dfsadmin -safemode get
```

La interfaz web del NameNode queda disponible en
<http://localhost:9870>. Para detener y eliminar el clúster:

```powershell
docker compose down
```

### Fase 4: cargar datos y ejecutar la prueba

Los scripts se encuentran en [`grupo05_scripts/`](./grupo05_scripts/).
Cada experimento debe ejecutarse con el clúster levantado. Primero se carga el
archivo con replicación 2:

```powershell
.\grupo05_scripts\cargar-dataset.ps1 -Dataset 1GB -Etiqueta 01-carga
.\grupo05_scripts\cargar-dataset.ps1 -Dataset 10GB -Etiqueta 01-carga
```

La opción `-Dataset` acepta `1GB` o `10GB`; la carga usa bloques de 128 MB y
establece la replicación en 2 mediante `dfs.replication=2`.

Para guardar el estado inicial:

```powershell
.\grupo05_scripts\estado.ps1 -Dataset 1GB -Etiqueta 03-estado-inicial
.\grupo05_scripts\estado.ps1 -Dataset 10GB -Etiqueta 03-estado-inicial
```

En otra ventana de PowerShell se puede iniciar el monitor:

```powershell
.\grupo05_scripts\monitor.ps1 -Dataset 1GB -Segundos 30
.\grupo05_scripts\monitor.ps1 -Dataset 10GB -Segundos 30
```

Durante cada prueba se detiene el DataNode indicado:

```powershell
# Prueba de 1 GB
docker stop grupo05-datanode2

# Prueba de 10 GB
docker stop grupo05-datanode3
```

Después de observar la detección y la recuperación, se restaura el contenedor:

```powershell
docker start grupo05-datanode2
docker start grupo05-datanode3
```

El estado final se comprueba con:

```powershell
docker exec grupo05-client hdfs dfsadmin -report
docker exec grupo05-client hdfs fsck /grupo05/dataset_1GB -files -blocks -locations
docker exec grupo05-client hdfs fsck /grupo05/dataset_10GB -files -blocks -locations
```

Los scripts guardan sus respaldos de texto en
`grupo05_evidencias\1GB\` o `grupo05_evidencias\10GB\`. Las capturas y los
respaldos organizados que se entregan están en
`grupo05_evidencias\grupo05_1GB\` y `grupo05_evidencias\grupo05_10GB\`.

## 5. Resultados del experimento de 1 GB

| Aspecto | Resultado |
|---|---|
| Archivo | `dataset_grupo05_1GB` |
| Factor de replicación | 2 |
| Tamaño de bloque | 128 MB |
| Número de bloques | 8 |
| DataNode detenido | DN2 (`172.19.0.6`) |
| Bloques que tenía el nodo detenido | 7 |
| Bloques faltantes | 0 |
| Archivo accesible durante el fallo | Sí; el cliente utilizó la réplica disponible |
| Estado final | `HEALTHY`, sin bloques faltantes ni subreplicados |
| Integridad | Hash MD5 igual antes y durante/después de la falla |

Evidencias:

- [Carga del archivo](./grupo05_evidencias/grupo05_1GB/01-carga.png)
- [Estado y bloques iniciales](./grupo05_evidencias/grupo05_1GB/03-estado-inicial.txt)
- [Reporte durante el fallo](./grupo05_evidencias/grupo05_1GB/08-report_dn_caido.png)
- [FSCK con bloques subreplicados](./grupo05_evidencias/grupo05_1GB/09-fsck_subreplicados.png)
- [Prueba de lectura durante el fallo](./grupo05_evidencias/grupo05_1GB/07_md5_durante.png)
- [FSCK final](./grupo05_evidencias/grupo05_1GB/11-fsck_final.png)
- [Integridad después de la recuperación](./grupo05_evidencias/grupo05_1GB/12-md5_despues.png)
- [Línea de tiempo](./grupo05_evidencias/grupo05_1GB/monitor.txt)

## 6. Resultados del experimento de 10 GB

| Aspecto | Resultado |
|---|---|
| Archivo | `dataset_grupo05_10GB` |
| Factor de replicación | 2 |
| Tamaño de bloque | 128 MB |
| Número de bloques | 80 |
| DataNode detenido | DN3 (`172.19.0.5`) |
| Bloques subreplicados observados | 47 de 80 (58,75 %) |
| Promedio de replicación durante el fallo | 1,41 (según `fsck`) |
| Bloques faltantes | 0 |
| Archivo accesible durante el fallo | Sí; `wc` devolvió 10 737 418 240 bytes |
| Recuperación observada | 47 → 21 → 2 → 0 bloques subreplicados (según `fsck`) |
| Estado final | `HEALTHY`, promedio de replicación 2,0 |
| Tiempo aproximado | Detección: 9,9 min; recuperación: aproximadamente 7 min |

Evidencias:

- [Mapa de IP](./grupo05_evidencias/grupo05_10GB/00-mapa_ips.png)
- [Carga del archivo](./grupo05_evidencias/grupo05_10GB/01-carga.png)
- [Estado y bloques iniciales](./grupo05_evidencias/grupo05_10GB/03-estado-inicial.txt)
- [Reporte durante el fallo](./grupo05_evidencias/grupo05_10GB/08-report_dn_caido.png)
- [FSCK subreplicado](./grupo05_evidencias/grupo05_10GB/09-fsck_subreplicados.png)
- [Prueba de lectura durante el fallo](./grupo05_evidencias/grupo05_10GB/07-wc_durante.png)
- [Monitoreo de detección](./grupo05_evidencias/grupo05_10GB/monitor.txt)
- [Monitoreo de recuperación](./grupo05_evidencias/grupo05_10GB/monitor-fsck.txt)
- [FSCK final](./grupo05_evidencias/grupo05_10GB/12-fsck_final.png)
- [Integridad después de la recuperación](./grupo05_evidencias/grupo05_10GB/13-wc_despues.png)

> **Nota sobre el monitoreo:** durante la prueba de 10 GB, `dfsadmin -report`
> podía mostrar cero bloques subreplicados mientras `fsck` ya mostraba 47.
> Por eso la recuperación se midió con `monitor-fsck.txt`, que registra la
> evolución 47 → 21 → 2 → 0.

## 7. Tabla comparativa

> 
Comparamos las dos pruebas de tolerancia a fallos: se detuvo un DataNode con `docker stop` y se observó cómo HDFS mantiene el archivo disponible y restablece la replicación.

| Característica | Dataset 1 GB | Dataset 10 GB |
|---|---|---|
| Tamaño | 1 GB (1 073 741 824 bytes) | 10 GB (10 737 418 240 bytes) |
| Número de bloques | 8 (de 128 MB) | 80 |
| Factor de replicación | 2 | 2 (promedio 2.0 antes de la falla) |
| DataNode afectado | DN2 (172.19.0.6) | DN3 (172.19.0.5) |
| Bloques afectados | 7 de 8 (los que tenían réplica en DN2) | 47 de 80 (58,75 %) |
| Bloques disponibles después de la falla | 8 de 8: HEALTHY, Missing blocks 0 | 80 de 80: HEALTHY, 0 missing |
| ¿Archivo accesible? | Sí. El md5 durante la falla es igual al de antes (`e4dc59f8…da07`) | Sí. Se leyeron los 10 737 418 240 bytes |
| ¿Existieron bloques subreplicados? | Sí, 7 bloques quedaron con una sola réplica viva. Los contadores de HDFS siguieron en 0 (ver observaciones) | Sí, 47 bloques y promedio de replicación 1,41 durante la falla |
| Tiempo de recuperación | Menos de 4,6 min tras declararse caído el DataNode (18:06:34 → ya recuperado a las 18:11:11) | ~7 min (declarado caído ~18:44, recuperado 18:51:09). Subreplicados: 47 → 21 → 2 → 0 |
| Nuevas réplicas | 7 réplicas nuevas: 6 en DN1 (bloques 0 a 5) y 1 en DN3 (bloque 7). Quedó DN1 con 8 bloques y DN3 con 8 | Se recrearon en DN1 y DN2, los únicos nodos vivos. Promedio final 2.0 |


## 8. Respuestas a las 9 preguntas

1. **¿Por qué sigue entregando el archivo?**  
   Porque cada bloque tiene otra réplica en un DataNode diferente. El cliente
   cambia automáticamente a la réplica disponible.

2. **¿Qué pasaría con replicación 1?**  
   Si falla el DataNode que contiene un bloque, ese bloque no podría leerse y
   el archivo podría quedar incompleto o inaccesible.

3. **¿Qué ocurriría si fallaran dos DataNodes?**  
   Los bloques cuyas dos réplicas estuvieran en esos nodos quedarían
   inaccesibles, con posible pérdida de datos.

4. **¿Por qué replicación 2 no son dos copias completas?**  
   HDFS replica cada bloque dos veces y distribuye los bloques entre los
   DataNodes; no guarda dos archivos completos en cada nodo.

5. **¿Cuál es el tamaño de bloque y el número de bloques?**  
   El bloque es de 128 MB. El archivo de 1 GB tiene 8 bloques y el de 10 GB
   tiene 80 bloques.

6. **¿Por qué 10 GB es más representativo?**  
   Porque utiliza más bloques y permite observar mejor los bloques afectados,
   la subreplicación y la recuperación automática.

7. **¿Qué bloques tenían réplica en el DataNode caído?**  
   En 1 GB, el DN2 tenía 7 de los 8 bloques. En 10 GB se observaron 47 bloques
   subreplicados al detener el DN3, pero no hubo bloques faltantes.

8. **¿Quién administra la ubicación y replicación?**  
   El NameNode administra los metadatos, decide la ubicación de las réplicas y
   ordena su recuperación. El cliente solicita y lee los bloques.

9. **¿Cuál es la diferencia entre disponibilidad y cumplimiento de replicación?**  
   La disponibilidad significa que el archivo puede leerse. El cumplimiento
   de replicación significa que cada bloque tiene la cantidad configurada de
   copias. Un archivo puede estar disponible aunque temporalmente esté
   subreplicado.

## 9. Estructura del repositorio

```text
bigdata_Grupo5_LG15/
├── docker-compose.yml
├── README.md
├── grupo05_docs/
│   └── Preguntas.docx
├── grupo05_scripts/
│   ├── cargar-dataset.ps1
│   ├── estado.ps1
│   └── monitor.ps1
├── grupo05_evidencias/
│   ├── 01-dockerps.png
│   ├── 02-datanodes_web.png
│   ├── 03-report_inicial.png
│   ├── 04-configuracion.png
│   ├── 05-mapa_ips.png
│   ├── 06-directorios_hdfs.png
│   ├── grupo05_1GB/
│   ├── grupo05_10GB/
│   └── 1GB/
└── grupo05_resultados/
    └── mapa_ips.txt
```

Las carpetas de evidencias contienen tanto las capturas como los archivos de
respaldo `.txt` generados por los scripts. La carpeta `1GB/` puede contener
el monitor generado por una ejecución anterior; las evidencias principales
están organizadas en `grupo05_1GB/` y `grupo05_10GB/`.

## 10. Observaciones y limitaciones

- La detección del DataNode caído tarda aproximadamente 9,9 minutos con la
  configuración utilizada. Esto se debe al intervalo de heartbeat y al
  tiempo de revalidación configurados en HDFS.
- Los tres DataNodes comparten el almacenamiento del entorno Docker, por lo
  que la capacidad reportada puede aparecer repetida en los informes.
- La prueba de 1 GB se realizó deteniendo DN2 y la de 10 GB deteniendo DN3;
  por tanto, los resultados no representan exactamente el mismo patrón de
  distribución de bloques.
- La disponibilidad del archivo y el cumplimiento del factor de replicación
  son propiedades diferentes: el archivo puede seguir leyéndose mientras
  existen bloques temporalmente subreplicados.

## 11. Análisis

### Antes de la falla

| Pregunta | Prueba de 1 GB | Prueba de 10 GB |
|---|---|---|
| ¿Cuántos bloques tenía el archivo? | 8 bloques de 128 MB | 80 bloques de 128 MB |
| ¿Cuántas réplicas tenía cada bloque? | 2 (`Live_repl=2`) | 2 (promedio de replicación 2,0) |
| ¿En qué DataNodes estaban? | DN1 guardaba 2 bloques, DN2 guardaba 7 y DN3 guardaba 7. Cada bloque estaba en una pareja de nodos (ver tabla de abajo). | Repartidos entre los tres nodos: DN1 = 63, DN2 = 58 y DN3 = 55 bloques. Estas cifras incluyen los 8 bloques del dataset de 1 GB, que seguía en HDFS. La ubicación de cada bloque está en el `fsck` inicial. |

Estado inicial en ambas pruebas: DN1 → Activo, DN2 → Activo, DN3 → Activo, con el archivo en estado `HEALTHY`.

Ubicación de las réplicas del dataset de 1 GB:

| Bloque | Réplica 1 | Réplica 2 |
|---|---|---|
| 0 | DN3 | DN2 |
| 1 | DN2 | DN3 |
| 2 | DN3 | DN2 |
| 3 | DN2 | DN3 |
| 4 | DN3 | DN2 |
| 5 | DN3 | DN2 |
| 6 | DN3 | DN1 |
| 7 | DN2 | DN1 |

### Durante la falla

| Pregunta | Prueba de 1 GB | Prueba de 10 GB |
|---|---|---|
| ¿Qué DataNode fue detenido? | DN2 (`grupo05-datanode2`, 172.19.0.6) | DN3 (`grupo05-datanode3`, 172.19.0.5) |
| ¿Qué bloques estaban almacenados en él? | 7 de los 8 bloques: 0, 1, 2, 3, 4, 5 y 7 | 47 bloques del archivo (los que aparecieron subreplicados) |
| ¿Existían otras réplicas? | Sí. Cada uno de esos bloques tenía su segunda copia en DN1 o DN3. | Sí. Los 47 bloques conservaban una réplica en DN1 o DN2; no hubo bloques faltantes. |
| ¿El archivo continuó disponible? | Sí. Se pudo leer completo y el hash MD5 fue idéntico al de antes de la falla. | Sí. Se leyeron 10 737 418 240 bytes, igual que antes. |
| ¿Qué cambió en HDFS? | Al principio nada: el NameNode seguía mostrando 3 nodos vivos. Después de unos 10 minutos sin heartbeats, DN2 pasó a estado caído. | Igual: primero sin cambios y luego DN3 pasó a *Dead*. El `fsck` mostró 2 DataNodes, 47 bloques subreplicados (58,75 %), 47 réplicas faltantes y promedio de replicación 1,41. El estado del archivo siguió en `HEALTHY`. |

Mientras el NameNode todavía no había declarado caído al nodo, el cliente que intentó leer de él recibió el error `No route to host`, lo marcó como nodo muerto y leyó el bloque desde otra réplica. Estado durante la falla: en 1 GB, DN1 y DN3 activos y DN2 en FALLA; en 10 GB, DN1 y DN2 activos y DN3 en FALLA.

### Después de la falla

| Pregunta | Prueba de 1 GB | Prueba de 10 GB |
|---|---|---|
| ¿Qué estado reporta HDFS? | `HEALTHY`, sin bloques faltantes ni corruptos | `HEALTHY`, sin bloques faltantes ni corruptos, con 2 DataNodes vivos |
| ¿Existen bloques subreplicados? | Los bloques con copia en DN2 quedaron con una sola réplica al declararse caído el nodo. Al terminar la recuperación, 0. | Sí, 47 bloques al declararse caído DN3. Al terminar la recuperación, 0. |
| ¿HDFS intenta recuperar automáticamente las réplicas? | Sí, sin intervención de nuestra parte. | Sí. El conteo bajó 47 → 21 → 2 → 0 y el promedio de replicación volvió a 2,0. |
| ¿En qué DataNode se generaron las nuevas réplicas? | Solo podían crearse en los nodos vivos que no tenían el bloque: los bloques 0 a 5 se copiaron a DN1 y el bloque 7 a DN3. | Solo en los nodos vivos, DN1 y DN2. Ya no quedó ninguna réplica apuntando a la IP de DN3. |

Al reiniciar el DataNode detenido, el clúster volvió a mostrar 3 DataNodes vivos.

### Por qué ocurrió

HDFS divide cada archivo en bloques y guarda cada bloque en varios DataNodes según el factor de replicación (aquí, 2). El NameNode mantiene el mapa de qué bloque está en qué nodo y recibe de cada DataNode heartbeats periódicos e informes de bloques.

Al detener un DataNode, el NameNode no se entera de inmediato. Espera hasta acumular el tiempo límite sin heartbeats (con la configuración por defecto, unos 10 minutos) y recién entonces lo declara muerto. Mientras tanto, la lectura funciona porque el cliente prueba con otra réplica de cada bloque.

Cuando el nodo se declara caído, el NameNode marca como subreplicados todos los bloques que tenían una copia allí, porque pasaron de 2 réplicas a 1. A continuación programa su copia: toma la réplica que sobrevive y la envía a otro DataNode vivo que todavía no tenga ese bloque, hasta volver al factor de replicación 2. Por eso el archivo estuvo siempre disponible, aunque durante un tiempo no cumplió el factor de replicación, y por eso las nuevas réplicas solo aparecen en los DataNodes que seguían activos.

En 10 GB hubo más bloques afectados (47 frente a 7) y la recuperación llevó más trabajo, porque hay que copiar más datos entre los nodos que quedan.