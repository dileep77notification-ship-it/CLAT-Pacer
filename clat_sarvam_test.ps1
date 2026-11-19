# ============================================================
# CLAT App - Sarvam API Dependency Test
# Same shape as the Gemini/Claude tests: key validity, trivial
# call, structured output via tool-calling, 5x reliability check.
# Sarvam is OpenAI-API-compatible: api.sarvam.com/openai/v1/...
#
# USAGE:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
#   .\clat_sarvam_test.ps1
# Paste back the full output.
# ============================================================

$GROQ_API_KEY = "YOUR_SARVAM_KEY"
$modelName = "sarvam-105b-conversations"
$baseUrl = "https://api.sarvam.com/openai/v1"

function Write-Section($title) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $title -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Test-HasNonEnglishChars($text) {
    # Flags any character outside basic ASCII printable range + common
    # punctuation - catches CJK, Cyrillic, etc. leaking into English output.
    return [regex]::IsMatch($text, '[^\x00-\x7F]')
}

$englishInstruction = "IMPORTANT: Respond entirely in English. Do not include any non-English characters, words, or scripts anywhere in your output. "

function Get-SarvamErrorBody($errorRecord) {
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

function Invoke-SarvamWithRetry($url, $bodyJson, $headers, $maxAttempts = 4) {
    $delays = @(5, 15, 30)
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $resp = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -ContentType "application/json" -Body $bodyJson -TimeoutSec 30
            return @{ Success = $true; Response = $resp }
        } catch {
            $statusCode = $null
            try { $statusCode = $_.Exception.Response.StatusCode.value__ } catch {}
            $body = Get-SarvamErrorBody $_
            $isRetryable = ($statusCode -eq 429) -or ($statusCode -eq 503)
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

$headers = @{ "Authorization" = "Bearer $GROQ_API_KEY" }

# ------------------------------------------------------------
# TEST 1: List models (key validity)
# ------------------------------------------------------------
Write-Section "TEST 1: GET /models (key validity + available model list)"
try {
    $modelsResp = Invoke-RestMethod -Uri "$baseUrl/models" -Method Get -Headers $headers
    Write-Host "SUCCESS. Models visible to this key:" -ForegroundColor Green
    $modelsResp.data | ForEach-Object { Write-Host "  - $($_.id)" }
} catch {
    Write-Host "FAILED:" -ForegroundColor Red
    Write-Host (Get-SarvamErrorBody $_) -ForegroundColor Red
}

# ------------------------------------------------------------
# TEST 2: Trivial chat completion
# ------------------------------------------------------------
Write-Section "TEST 2: Trivial chat completion"
$trivialBody = @{
    model = $modelName
    messages = @(@{ role = "user"; content = "Say the word 'hello' and nothing else." })
    max_tokens = 20
} | ConvertTo-Json -Depth 10

$result = Invoke-SarvamWithRetry -url "$baseUrl/chat/completions" -bodyJson $trivialBody -headers $headers
if ($result.Success) {
    Write-Host "SUCCESS. Model response:" -ForegroundColor Green
    Write-Host ($result.Response.choices[0].message.content)
} else {
    Write-Host "FAILED (after retries):" -ForegroundColor Red
    Write-Host $result.Body -ForegroundColor Red
}

# ------------------------------------------------------------
# TEST 3: Structured output via tool-calling
# ------------------------------------------------------------
Write-Section "TEST 3: Structured output (forced tool-call, question/options/correct_index/explanation schema)"

$questionTool = @{
    type = "function"
    function = @{
        name = "submit_mcq"
        description = "Submit a generated CLAT UG Legal Reasoning MCQ."
        parameters = @{
            type = "object"
            properties = @{
                question = @{ type = "string" }
                options = @{ type = "array"; items = @{ type = "string" } }
                correct_index = @{ type = "integer"; description = "0-based index into options" }
                explanation = @{ type = "string" }
            }
            required = @("question", "options", "correct_index", "explanation")
        }
    }
}

$schemaBody = @{
    model = $modelName
    messages = @(@{ role = "user"; content = "$englishInstruction Generate one CLAT UG Legal Reasoning MCQ (principle + facts style). Provide exactly 4 options and the correct_index as a 0-based integer." })
    tools = @($questionTool)
    tool_choice = @{ type = "function"; function = @{ name = "submit_mcq" } }
    max_tokens = 2048
} | ConvertTo-Json -Depth 20

$result = Invoke-SarvamWithRetry -url "$baseUrl/chat/completions" -bodyJson $schemaBody -headers $headers
if ($result.Success) {
    $toolCall = $result.Response.choices[0].message.tool_calls | Select-Object -First 1
    if ($toolCall) {
        Write-Host "SUCCESS. Raw tool-call arguments:" -ForegroundColor Green
        Write-Host $toolCall.function.arguments
        $parsed = $toolCall.function.arguments | ConvertFrom-Json
        $hasAllFields = $parsed.question -and $parsed.options -and ($null -ne $parsed.correct_index) -and $parsed.explanation
        $allText = "$($parsed.question) $($parsed.options -join ' ') $($parsed.explanation)"
        $hasGarbledText = Test-HasNonEnglishChars $allText
        if ($hasAllFields -and -not $hasGarbledText) {
            Write-Host "Schema + language validation: PASSED" -ForegroundColor Green
        } elseif ($hasGarbledText) {
            Write-Host "FAILED: non-English characters detected in output" -ForegroundColor Red
        } else {
            Write-Host "Schema validation: FAILED (missing fields)" -ForegroundColor Red
        }
    } else {
        Write-Host "FAILED: no tool_call in response" -ForegroundColor Red
        $result.Response | ConvertTo-Json -Depth 10 | Write-Host
    }
} else {
    Write-Host "FAILED (after retries):" -ForegroundColor Red
    Write-Host $result.Body -ForegroundColor Red
}

# ------------------------------------------------------------
# TEST 4: Repeat 5x (reliability check)
# ------------------------------------------------------------
Write-Section "TEST 4: Repeat structured-output call 5x (reliability check)"
$successCount = 0
for ($i = 1; $i -le 5; $i++) {
    $body2 = @{
        model = $modelName
        messages = @(@{ role = "user"; content = "Generate one CLAT UG Legal Reasoning MCQ (principle + facts style), different from before. Provide exactly 4 options and correct_index as a 0-based integer." })
        tools = @($questionTool)
        tool_choice = @{ type = "function"; function = @{ name = "submit_mcq" } }
        max_tokens = 1024
    } | ConvertTo-Json -Depth 20

    $result = Invoke-SarvamWithRetry -url "$baseUrl/chat/completions" -bodyJson $body2 -headers $headers
    if ($result.Success) {
        $toolCall = $result.Response.choices[0].message.tool_calls | Select-Object -First 1
        if ($toolCall) {
            $parsed = $toolCall.function.arguments | ConvertFrom-Json
            $ok = $parsed.question -and $parsed.options -and ($null -ne $parsed.correct_index) -and $parsed.explanation
            if ($ok) {
                $successCount++
                Write-Host "  Attempt $i : PASSED" -ForegroundColor Green
            } else {
                Write-Host "  Attempt $i : FAILED (malformed/missing fields)" -ForegroundColor Red
            }
        } else {
            Write-Host "  Attempt $i : FAILED (no tool_call)" -ForegroundColor Red
        }
    } else {
        Write-Host "  Attempt $i : FAILED (after retries) - $($result.Body)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 2  # stay comfortably under 30 RPM free-tier cap
}
Write-Host ""
Write-Host "Reliability result: $successCount / 5 structured calls passed schema validation." -ForegroundColor Cyan

Write-Section "SUMMARY"
Write-Host "Sarvam structured-output reliability: $successCount / 5" -ForegroundColor Cyan
Write-Host "Pass/fail bar: $(if ($successCount -ge 4) {'LIKELY PASS'} else {'LIKELY FAIL'}) (needs consistent output, not 1-in-5)"
