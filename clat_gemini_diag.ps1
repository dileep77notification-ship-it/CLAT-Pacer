# ============================================================
# CLAT App - Gemini endpoint diagnostic (narrow, focused)
# Your key IS valid (Test 1 proved that) and DOES list
# gemini-2.5-flash as available, but generateContent 404s on it -
# the original script's error handler wasn't printing the actual
# response body, so the real reason was hidden. This one captures
# the full body on every failure and tries several model/API-
# version combinations so we can see exactly what Google is
# rejecting and why.
#
# USAGE: same as before -
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
#   .\clat_gemini_diag.ps1
# Paste back the FULL output.
# ============================================================

$GEMINI_API_KEY = "AQ.Ab8RN6J5poguz8Bv0vgA9INyFAYj_nT1_CKYdVS64E5XxG6h3g"

function Get-ErrorBody($errorRecord) {
    $body = $null
    try {
        if ($errorRecord.Exception.Response) {
            $stream = $errorRecord.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $body = $reader.ReadToEnd()
        }
    } catch {}
    if (-not $body -and $errorRecord.ErrorDetails) {
        $body = $errorRecord.ErrorDetails.Message
    }
    return $body
}

$trivialBody = @{
    contents = @(
        @{ parts = @(@{ text = "Say the word 'hello' and nothing else." }) }
    )
} | ConvertTo-Json -Depth 10

# Combinations to try: (API version, model name as it appears WITHOUT "models/" prefix)
$combos = @(
    @{ Ver = "v1beta"; Model = "gemini-2.5-flash" },
    @{ Ver = "v1";      Model = "gemini-2.5-flash" },
    @{ Ver = "v1beta"; Model = "gemini-flash-latest" },
    @{ Ver = "v1beta"; Model = "gemini-pro-latest" },
    @{ Ver = "v1beta"; Model = "gemini-2.5-flash-lite" }
)

foreach ($combo in $combos) {
    $url = "https://generativelanguage.googleapis.com/$($combo.Ver)/models/$($combo.Model):generateContent?key=$GEMINI_API_KEY"
    Write-Host ""
    Write-Host "---- $($combo.Ver) / $($combo.Model) ----" -ForegroundColor Yellow
    Write-Host "URL: https://generativelanguage.googleapis.com/$($combo.Ver)/models/$($combo.Model):generateContent?key=***"
    try {
        $resp = Invoke-RestMethod -Uri $url -Method Post -ContentType "application/json" -Body $trivialBody
        Write-Host "SUCCESS:" -ForegroundColor Green
        Write-Host ($resp.candidates[0].content.parts[0].text)
    } catch {
        Write-Host "FAILED - HTTP status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
        $body = Get-ErrorBody $_
        if ($body) {
            Write-Host "Response body:" -ForegroundColor Red
            Write-Host $body
        } else {
            Write-Host "Exception message: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "(no response body captured)" -ForegroundColor Red
        }
    }
}
