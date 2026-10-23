$ErrorActionPreference = 'Stop'
# Chave efemera exclusiva deste teste. Nao toca certificados nem a confianca do Windows.
$key = New-Object System.Security.Cryptography.RSACryptoServiceProvider(2048)
$public = New-Object System.Security.Cryptography.RSACryptoServiceProvider
$key.PersistKeyInCsp = $false
$public.PersistKeyInCsp = $false
try {
    $public.ImportParameters($key.ExportParameters($false))
    $manifest = [ordered]@{ product = 'SecureCompany.ERP'; channel = 'stable'; platform = 'win64'; sequence = 482; minimumSequence = 482; expiresAt = '2099-01-01T00:00:00Z' }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($manifest | ConvertTo-Json -Compress))
    $signature = $key.SignData($bytes, 'SHA256')
    if (-not $public.VerifyData($bytes, 'SHA256', $signature)) { throw 'Assinatura valida rejeitada' }
    Write-Output 'PASS update: assinatura RSA verificada pela chave publica'
    $altered = [byte[]]$bytes.Clone()
    $altered[10] = $altered[10] -bxor 1
    if ($public.VerifyData($altered, 'SHA256', $signature)) { throw 'Adulteracao aceita' }
    Write-Output 'PASS update: metadados adulterados rejeitados'
    function Test-Policy($value, [int]$greatest) {
        return $value.product -eq 'SecureCompany.ERP' -and $value.channel -eq 'stable' -and $value.platform -eq 'win64' -and $value.sequence -ge $greatest -and $value.sequence -ge $value.minimumSequence -and [DateTimeOffset]::Parse($value.expiresAt) -gt [DateTimeOffset]::UtcNow
    }
    # Interpretacao somente depois de verificar a assinatura dos bytes recebidos.
    $parsed = [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
    if (-not (Test-Policy $parsed 481)) { throw 'Atualizacao legitima rejeitada' }
    if (Test-Policy $parsed 483) { throw 'Downgrade aceito' }
    $parsed.expiresAt = '2000-01-01T00:00:00Z'
    if (Test-Policy $parsed 481) { throw 'Expiracao ignorada' }
    $parsed.expiresAt = '2099-01-01T00:00:00Z'
    $parsed.channel = 'test'
    if (Test-Policy $parsed 481) { throw 'Canal incorreto aceito' }
    Write-Output 'PASS update: politica rejeita downgrade, expiracao e outro canal'
} finally { $public.Dispose(); $key.Dispose() }
