param([string]$StudioRoot = 'C:\Program Files (x86)\Embarcadero\Studio\37.0')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $StudioRoot 'bin\dcc64.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'Informe a instalacao do Delphi 13 em -StudioRoot.' }
$output = Join-Path $root 'build\win64'
New-Item -ItemType Directory -Force -Path $output | Out-Null
Push-Location (Join-Path $root 'src')
try {
    foreach ($project in @('DpapiLab', 'DataAccessLab', 'CryptoLab', 'RulesLab', 'HttpClientLab')) {
        & $compiler -B -Q "-U$StudioRoot\lib\win64\release" "-I$StudioRoot\include" "-E$output" "-N0$output" "$project.dpr"
        if ($LASTEXITCODE -ne 0) { throw "Falha ao compilar $project" }
        if ($project -ne 'HttpClientLab') {
            & (Join-Path $output "$project.exe")
            if ($LASTEXITCODE -ne 0) { throw "Falha ao executar $project" }
        }
    }
} finally { Pop-Location }
