# ============================================================
# CLAT App - Claude API Dependency Test (replaces Gemini, §12 pivot)
# Covers the same ground as the old §13.1 Gemini tests, adapted to
# Claude's API shape:
#   - GET  /v1/models            (key validity + model list)
#   - POST /v1/messages          (trivial call, proves model/auth end-to-end)
#   - POST /v1/messages + forced tool-use (structured output, the
#     Claude equivalent of Gemini's response_schema/response_mime_type)
#   - Repeat the structured call 5x (schema reliability check)
#
# Run this on your Windows machine, same as the Gemini scripts.
#
# USAGE:
#   1. Get an API key from https://console.anthropic.com (separate
#      from any claude.ai subscription - this is pay-as-you-go
#      billing, add a payment method there if you haven't).
#   2. Paste it into $ANTHROPIC_API_KEY below.
#   3. Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
#   4. .\clat_claude_api_test.ps1
#   5. Paste back the full output.
# ============================================================

$ANTHROPIC_API_KEY = "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"
$ANTHROPIC_VERSION = "2026-10-21"
$modelName = "claude-haiku-5-5"

function Write-Section($title) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $title -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Get-ClaudeErrorBody($errorRecord) {
    $body = $null
    try {
        if ($errorRecord.Exception.Response) {
            $stream = $errorRecord.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $body = $reader.ReadToEnd()
        }
    } catch {}
    if (-not $body -and $errorRecord.ErrorDetails) { $body = $errorRecord.ErrorDetails.Message }
    if (-not $body) { $body = $errorRecord.Exception.Message }
    return $body
}

# Retries on 429 (rate limit) / 529 (overloaded) with backoff: 5s, 15s, 30s.
function Invoke-ClaudeWithRetry($url, $bodyJson, $headers, $maxAttempts = 4) {
    $delays = @(5, 15, 30)
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $resp = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -ContentType "application/json" -Body $bodyJson -TimeoutSec 30
            return @{ Success = $true; Response = $resp }
        } catch {
            $statusCode = $null
            try { $statusCode = $_.Exception.Response.StatusCode.value__ } catch {}
            $body = Get-ClaudeErrorBody $_
            $isRetryable = ($statusCode -eq 429) -or ($statusCode -eq 529) -or ($body -match "overloaded" -or $body -match "rate_limit")
            if ($isRetryable -and $attempt -lt $maxAttempts) {
                $wait = $delays[$attempt - 1]
                Write-Host "    (attempt $attempt hit $statusCode, retrying in ${wait}s...)" -ForegroundColor DarkYellow
                Start-Sleep -Seconds $wait
                continue
            }
            return @{ Success = $false; StatusCode = $statusCode; Body = $body }
        }
    }
}

$headers = @{
    "x-api-key" = $ANTHROPIC_API_KEY
    "anthropic-version" = $ANTHROPIC_VERSION
}

# ------------------------------------------------------------
# TEST 1: List models (key validity)
# ------------------------------------------------------------
Write-Section "TEST 1: GET /v1/models (key validity + available model list)"
try {
    $modelsUrl = "https://api.anthropic.com/v1/models?limit=50"
    $modelsResp = Invoke-RestMethod -Uri $modelsUrl -Method Get -Headers $headers
    Write-Host "SUCCESS. Models visible to this key:" -ForegroundColor Green
    $modelsResp.data | ForEach-Object { Write-Host "  - $($_.id)  [$($_.lifecycle)]" }
} catch {
    Write-Host "FAILED:" -ForegroundColor Red
    Write-Host (Get-ClaudeErrorBody $_) -ForegroundColor Red
}

# ------------------------------------------------------------
# TEST 2: Trivial /v1/messages call
# ------------------------------------------------------------
Write-Section "TEST 2: Trivial /v1/messages call"
$trivialBody = @{
    model = $modelName
    max_tokens = 20
    messages = @(
        @{ role = "user"; content = "Say the word 'hello' and nothing else." }
    )
} | ConvertTo-Json -Depth 10

$result = Invoke-ClaudeWithRetry -url "https://api.anthropic.com/v1/messages" -bodyJson $trivialBody -headers $headers
if ($result.Success) {
    Write-Host "SUCCESS. Model response:" -ForegroundColor Green
    Write-Host ($result.Response.content[0].text)
} else {
    Write-Host "FAILED (after retries):" -ForegroundColor Red
    Write-Host $result.Body -ForegroundColor Red
}

# ------------------------------------------------------------
# TEST 3: Structured output via forced tool-use
# (Claude's equivalent of Gemini's response_schema)
# ------------------------------------------------------------
Write-Section "TEST 3: Structured output (forced tool-use, question/options/correct_index/explanation schema)"

$questionTool = @{
    name = "submit_mcq"
    description = "Submit a generated CLAT UG Legal Reasoning MCQ."
    input_schema = @{
        type = "object"
        properties = @{
            question = @{ type = "string" }
            options = @{
                type = "array"
                items = @{ type = "string" }
                minItems = 4
                maxItems = 4
            }
            correct_index = @{ type = "integer"; description = "0-based index into options" }
            explanation = @{ type = "string" }
        }
        required = @("question", "options", "correct_index", "explanation")
    }
}

$schemaBody = @{
    model = $modelName
    max_tokens = 1024
    tools = @($questionTool)
    tool_choice = @{ type = "tool"; name = "submit_mcq" }
    messages = @(
        @{ role = "user"; content = "Generate one CLAT UG Legal Reasoning MCQ (principle + facts style). Provide exactly 4 options and the correct_index as a 0-based integer." }
    )
} | ConvertTo-Json -Depth 20

$result = Invoke-ClaudeWithRetry -url "https://api.anthropic.com/v1/messages" -bodyJson $schemaBody -headers $headers
if ($result.Success) {
    $toolUseBlock = $result.Response.content | Where-Object { $_.type -eq "tool_use" } | Select-Object -First 1
    if ($toolUseBlock) {
        Write-Host "SUCCESS. Structured input returned:" -ForegroundColor Green
        $toolUseBlock.input | ConvertTo-Json -Depth 10 | Write-Host
        $p = $toolUseBlock.input
        $hasAllFields = $p.question -and $p.options -and ($null -ne $p.correct_index) -and $p.explanation
        if ($hasAllFields) {
            Write-Host "Schema validation: PASSED" -ForegroundColor Green
        } else {
            Write-Host "Schema validation: FAILED (missing fields)" -ForegroundColor Red
        }
    } else {
        Write-Host "FAILED: no tool_use block in response (model didn't call the tool)" -ForegroundColor Red
        $result.Response | ConvertTo-Json -Depth 10 | Write-Host
    }
} else {
    Write-Host "FAILED (after retries):" -ForegroundColor Red
    Write-Host $result.Body -ForegroundColor Red
}

# ------------------------------------------------------------
# TEST 4: Repeat structured call 5x (reliability check)
# ------------------------------------------------------------
Write-Section "TEST 4: Repeat structured-output call 5x (reliability check)"
$successCount = 0
for ($i = 1; $i -le 5; $i++) {
    $schemaBody2 = @{
        model = $modelName
        max_tokens = 1024
        tools = @($questionTool)
        tool_choice = @{ type = "tool"; name = "submit_mcq" }
        messages = @(
            @{ role = "user"; content = "Generate one CLAT UG Legal Reasoning MCQ (principle + facts style), different from before. Provide exactly 4 options and correct_index as a 0-based integer." }
        )
    } | ConvertTo-Json -Depth 20

    $result = Invoke-ClaudeWithRetry -url "https://api.anthropic.com/v1/messages" -bodyJson $schemaBody2 -headers $headers
    if ($result.Success) {
        $toolUseBlock = $result.Response.content | Where-Object { $_.type -eq "tool_use" } | Select-Object -First 1
        if ($toolUseBlock) {
            $p = $toolUseBlock.input
            $ok = $p.question -and $p.options -and ($null -ne $p.correct_index) -and $p.explanation
            if ($ok) {
                $successCount++
                Write-Host "  Attempt $i : PASSED" -ForegroundColor Green
            } else {
                Write-Host "  Attempt $i : FAILED (malformed/missing fields)" -ForegroundColor Red
            }
        } else {
            Write-Host "  Attempt $i : FAILED (no tool_use block)" -ForegroundColor Red
        }
    } else {
        Write-Host "  Attempt $i : FAILED (after retries) - $($result.Body)" -ForegroundColor Red
    }
}
Write-Host ""
Write-Host "Reliability result: $successCount / 5 structured calls passed schema validation." -ForegroundColor Cyan

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------
Write-Section "SUMMARY"
Write-Host "Claude API structured-output reliability: $successCount / 5" -ForegroundColor Cyan
Write-Host "Pass/fail bar (same as old §13.3): $(if ($successCount -ge 4) {'LIKELY PASS'} else {'LIKELY FAIL'}) (needs consistent output, not 1-in-5)"
