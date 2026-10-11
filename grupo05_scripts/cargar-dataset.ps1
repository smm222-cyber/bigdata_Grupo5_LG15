param(
  [Parameter(Mandatory=$true)][ValidateSet("1GB","10GB")][string]$Dataset
)
$gb   = $Dataset -replace 'GB',''
$ruta = "/grupo05/dataset_${Dataset}/dataset_grupo05_${Dataset}"
$cmd  = "head -c ${gb}G /dev/urandom | hdfs dfs -D dfs.replication=2 -put - $ruta"

$inicio = Get-Date
Write-Host "Inicio carga ${Dataset} - $($inicio.ToString('yyyy-MM-dd HH:mm:ss'))"
docker exec grupo05-client bash -c $cmd
$fin = Get-Date
Write-Host "Fin carga - $($fin.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host ("Duracion: {0} segundos" -f [math]::Round(($fin - $inicio).TotalSeconds))
