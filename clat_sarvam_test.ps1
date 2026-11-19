# CLAT Pacer - Sarvam API test
# Usage:  $env:SARVAM_API_KEY = "<your key>"; .\clat_sarvam_test.ps1
# The key is read from the environment, never hardcoded.

$key = $env:SARVAM_API_KEY
if (-not $key) { Write-Host "Set SARVAM_API_KEY first." -ForegroundColor Red; exit 1 }

$url = "https://api.sarvam.ai/v1/chat/completions"
$model = if ($env:SARVAM_MODEL) { $env:SARVAM_MODEL } else { "sarvam-105b-conversations" }
$headers = @{ "Authorization" = "Bearer $key"; "api-subscription-key" = $key; "Content-Type" = "application/json" }

function Invoke-Sarvam($body) {
    try {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $r = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 20) -TimeoutSec 90
        $sw.Stop()
        return @{ ok = $true; data = $r; secs = [math]::Round($sw.Elapsed.TotalSeconds, 1) }
    } catch {
        $msg = $_.ErrorDetails.Message; if (-not $msg) { $msg = $_.Exception.Message }
        return @{ ok = $false; err = $msg }
    }
}

Write-Host "`n[1] Basic chat ($model)" -ForegroundColor Cyan
$r = Invoke-Sarvam @{ model = $model; messages = @(@{ role = "user"; content = "Reply with the single word: pong" }); max_tokens = 50 }
if ($r.ok) { Write-Host "PASS ($($r.secs)s): $($r.data.choices[0].message.content)" -ForegroundColor Green }
else { Write-Host "FAIL: $($r.err)" -ForegroundColor Red; exit 1 }

Write-Host "`n[2] Forced tool call x3 (what the app relies on)" -ForegroundColor Cyan
$tool = @{ type = "function"; function = @{
    name = "submit_mcqs"; description = "Submit 2 generated CLAT MCQs."
    parameters = @{ type = "object"; required = @("questions"); properties = @{ questions = @{ type = "array"; items = @{
        type = "object"; required = @("question","options","correct_index","explanation","topic")
        properties = @{
            question = @{ type = "string" }
            options = @{ type = "array"; items = @{ type = "string" }; minItems = 4; maxItems = 4 }
            correct_index = @{ type = "integer" }
            explanation = @{ type = "string" }
            topic = @{ type = "string" } } } } } } } }
$pass = 0
1..3 | ForEach-Object {
    $r = Invoke-Sarvam @{
        model = $model
        messages = @(
            @{ role = "system"; content = "You are a CLAT question setter. Respond in English only." },
            @{ role = "user"; content = "Generate exactly 2 fresh Legal Reasoning MCQs now via the submit_mcqs tool." })
        tools = @($tool)
        tool_choice = @{ type = "function"; function = @{ name = "submit_mcqs" } }
        max_tokens = 2300 }
    if (-not $r.ok) { Write-Host "  run ${_}: FAIL HTTP - $($r.err)" -ForegroundColor Red; return }
    try {
        $tc = $r.data.choices[0].message.tool_calls[0]
        $args = $tc.function.arguments | ConvertFrom-Json
        $qs = $args.questions
        $valid = $qs.Count -ge 1 -and ($qs | Where-Object { $_.options.Count -eq 4 -and $_.correct_index -ge 0 -and $_.correct_index -le 3 }).Count -eq $qs.Count
        if ($valid) { $script:pass++; Write-Host "  run ${_}: PASS ($($r.secs)s, $($qs.Count) questions, tokens=$($r.data.usage.total_tokens))" -ForegroundColor Green }
        else { Write-Host "  run ${_}: FAIL - JSON shape wrong" -ForegroundColor Red }
    } catch {
        Write-Host "  run ${_}: FAIL - no usable tool_call. content: $($r.data.choices[0].message.content)" -ForegroundColor Red
    }
}
Write-Host "`nTool-call reliability: $pass / 3" -ForegroundColor Cyan
