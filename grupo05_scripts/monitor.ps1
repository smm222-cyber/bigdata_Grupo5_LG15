param(
  [Parameter(Mandatory=$true)][ValidateSet("1GB","10GB")][string]$Dataset,
  [int]$Segundos = 30
)
$carpeta = "grupo05_evidencias/$Dataset"
New-Item -ItemType Directory -Force -Path $carpeta | Out-Null
$archivo = "$carpeta/monitor.txt"
$inicio  = Get-Date
$vistoSub  = $false
$vistoDead = $false

function Log($m) { Write-Host $m; $m | Out-File -Append -Encoding utf8 $archivo }
Log "=== GRUPO 05 | monitor $Dataset | inicio $($inicio.ToString('yyyy-MM-dd HH:mm:ss')) ==="

while ($true) {
  $rep  = docker exec grupo05-client hdfs dfsadmin -report 2>&1 | ForEach-Object { "$_" }
  $live = ($rep | Select-String "^\s*Live datanodes"          | Select-Object -First 1).Line
  $dead = ($rep | Select-String "^\s*Dead datanodes"          | Select-Object -First 1).Line
  $sub  = ($rep | Select-String "^\s*Under replicated blocks"  | Select-Object -First 1).Line
  $min  = [math]::Round(((Get-Date) - $inicio).TotalMinutes, 1)
  Log ("{0} (+{1} min) | {2} | {3} | {4}" -f (Get-Date -Format 'HH:mm:ss'), $min, $live, $dead, $sub)

  if ($dead -and -not $vistoDead) { $vistoDead = $true; Log ">>> DataNode declarado caído en +$min min" }
  if ($sub) {
    $n = [int]($sub -replace '\D','')
    if ($n -gt 0) { $vistoSub = $true }
    if ($vistoSub -and $n -eq 0) { Log ">>> RECUPERADO: subreplicados = 0 en +$min min"; break }
  }
  Start-Sleep -Seconds $Segundos
}
