param(
  [Parameter(Mandatory=$true)][ValidateSet("1GB","10GB")][string]$Dataset,
  [Parameter(Mandatory=$true)][string]$Etiqueta
)
$ruta    = "/grupo05/dataset_${Dataset}"
$carpeta = "grupo05_evidencias/${Dataset}"
New-Item -ItemType Directory -Force -Path $carpeta | Out-Null

$fecha   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$salida  = @()
$salida += "=== GRUPO 05 | ${Dataset} | ${Etiqueta} | $fecha ==="
$salida += "--- hdfs dfsadmin -report ---"
$salida += (docker exec grupo05-client hdfs dfsadmin -report 2>&1 | ForEach-Object { "$_" })
$salida += "--- hdfs fsck $ruta -files -blocks -locations ---"
$salida += (docker exec grupo05-client hdfs fsck $ruta -files -blocks -locations 2>&1 | ForEach-Object { "$_" })

$salida | Out-File -Encoding utf8 "$carpeta/${Etiqueta}.txt"
$salida
