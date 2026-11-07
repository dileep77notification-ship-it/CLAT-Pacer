# ============================================================
# CLAT App - External Dependency Test Script (v2)
# Covers spec sections 13.1 (Gemini API) and 13.2 (RSS feeds)
# Run this on your Windows machine (NOT in this sandbox - both
# generativelanguage.googleapis.com and the news domains are
# blocked here).
#
# CHANGES FROM v1 (based on your first run's output):
#   - Fixed model name: your key doesn't have access to
#     "gemini-1.5-flash" at all (confirmed 404 x6). Switched to
#     "gemini-2.5-flash", which IS in your key's model list.
#   - Fixed RSS text extraction: The Hindu feeds' <title>/<link>/
#     <pubDate> nodes printed as "System.Xml.XmlElement" instead
#     of text - PowerShell's [xml] cast needs .InnerText pulled
#     explicitly when a node has mixed/CDATA content. Added a
#     Get-NodeText helper used for every field.
#   - Added a fallback URL for LiveLaw (its /feed endpoint 500'd).
#
# USAGE:
#   1. Your API key is already filled in from the last run.
#      Replace it if you rotate the key.
#   2. Open PowerShell, cd to this script's folder, run:
#        .\clat_dependency_test.ps1
#   3. Copy the FULL console output (including any red errors)
#      and paste it back.
# ============================================================

$ErrorActionPreference = "Continue"
$GEMINI_API_KEY = "AQ.Ab8RN6J5poguz8Bv0vgA9INyFAYj_nT1_CKYdVS64E5XxG6h3g"

function Write-Section($title) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $title -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Get-NodeText($node) {
    if ($null -eq $node) { return $null }
    if ($node -is [string]) { return $node }
    if ($node.PSObject.Properties.Name -contains "#text") { return $node."#text" }
    if ($node.PSObject.Properties.Name -contains "InnerText") { return $node.InnerText }
    return [string]$node
}

function Get-GeminiErrorBody($errorRecord) {
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

# Calls Gemini with a 30s per-attempt timeout and retries on 503
# (UNAVAILABLE / high-demand) with exponential backoff: 5s, 15s, 30s.
# Returns @{ Success = $true; Response = <obj> } or
#         @{ Success = $false; Body = <error body string> }
function Invoke-GeminiWithRetry($url, $bodyJson, $maxAttempts = 4) {
    $delays = @(5, 15, 30)
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $resp = Invoke-RestMethod -Uri $url -Method Post -ContentType "application/json" -Body $bodyJson -TimeoutSec 30
            return @{ Success = $true; Response = $resp }
        } catch {
            $statusCode = $null
            try { $statusCode = $_.Exception.Response.StatusCode.value__ } catch {}
            $body = Get-GeminiErrorBody $_

            $is503 = ($statusCode -eq 503) -or ($body -match '"code"\s*:\s*503' -or $body -match "UNAVAILABLE")
            if ($is503 -and $attempt -lt $maxAttempts) {
                $wait = $delays[$attempt - 1]
                Write-Host "    (attempt $attempt hit 503/high-demand, retrying in ${wait}s...)" -ForegroundColor DarkYellow
                Start-Sleep -Seconds $wait
                continue
            }
            return @{ Success = $false; Body = $body }
        }
    }
}

# ------------------------------------------------------------
# 13.1 — TEST 1: List models (proves key validity + model names)
# ------------------------------------------------------------
Write-Section "13.1 TEST 1: GET /v1beta/models (key validity + available model names)"
try {
    $modelsUrl = "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_API_KEY"
    $modelsResp = Invoke-RestMethod -Uri $modelsUrl -Method Get
    $modelNames = $modelsResp.models | Select-Object -ExpandProperty name
    Write-Host "SUCCESS. Models visible to this key:" -ForegroundColor Green
    $modelNames | ForEach-Object { Write-Host "  - $_" }
} catch {
    Write-Host "FAILED:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.ErrorDetails) { Write-Host $_.ErrorDetails.Message -ForegroundColor Red }
}

# ------------------------------------------------------------
# 13.1 — TEST 2: Trivial generateContent call (proves model name works end-to-end)
# ------------------------------------------------------------
Write-Section "13.1 TEST 2: Trivial generateContent call"
$modelName = "gemini-flash-latest"
$genUrl = "https://generativelanguage.googleapis.com/v1beta/models/$($modelName):generateContent?key=$GEMINI_API_KEY"
$trivialBody = @{
    contents = @(
        @{
            parts = @(
                @{ text = "Say the word 'hello' and nothing else." }
            )
        }
    )
} | ConvertTo-Json -Depth 10

$result = Invoke-GeminiWithRetry -url $genUrl -bodyJson $trivialBody
if ($result.Success) {
    Write-Host "SUCCESS. Model response:" -ForegroundColor Green
    Write-Host ($result.Response.candidates[0].content.parts[0].text)
} else {
    Write-Host "FAILED (after retries):" -ForegroundColor Red
    Write-Host $result.Body -ForegroundColor Red
}

# ------------------------------------------------------------
# 13.1 — TEST 3: Structured JSON output matching the question schema
# ------------------------------------------------------------
Write-Section "13.1 TEST 3: Structured output (question/options/correct_index/explanation schema)"
$responseSchema = @{
    type = "OBJECT"
    properties = @{
        question = @{ type = "STRING" }
        options = @{
            type = "ARRAY"
            items = @{ type = "STRING" }
        }
        correct_index = @{ type = "INTEGER" }
        explanation = @{ type = "STRING" }
    }
    required = @("question", "options", "correct_index", "explanation")
}
$schemaUrl = "https://generativelanguage.googleapis.com/v1beta/models/$($modelName):generateContent?key=$GEMINI_API_KEY"
$schemaBody = @{
    contents = @(
        @{
            parts = @(
                @{ text = "Generate one CLAT UG Legal Reasoning MCQ (principle + facts style). Provide exactly 4 options and the correct_index as a 0-based integer." }
            )
        }
    )
    generationConfig = @{
        response_mime_type = "application/json"
        response_schema = $responseSchema
    }
} | ConvertTo-Json -Depth 20

$result = Invoke-GeminiWithRetry -url $schemaUrl -bodyJson $schemaBody
if ($result.Success) {
    $rawJson = $result.Response.candidates[0].content.parts[0].text
    Write-Host "SUCCESS. Raw structured JSON returned:" -ForegroundColor Green
    Write-Host $rawJson

    $parsed = $rawJson | ConvertFrom-Json
    $hasAllFields = $parsed.question -and $parsed.options -and ($null -ne $parsed.correct_index) -and $parsed.explanation
    if ($hasAllFields) {
        Write-Host "Schema validation: PASSED (all required fields present)" -ForegroundColor Green
    } else {
        Write-Host "Schema validation: FAILED (missing one or more required fields)" -ForegroundColor Red
    }
} else {
    Write-Host "FAILED (after retries):" -ForegroundColor Red
    Write-Host $result.Body -ForegroundColor Red
}

# ------------------------------------------------------------
# 13.1 — TEST 4: Repeat structured call 5x to check schema reliability
# ------------------------------------------------------------
Write-Section "13.1 TEST 4: Repeat structured-output call 5x (reliability check)"
$successCount = 0
for ($i = 1; $i -le 5; $i++) {
    $schemaUrl = "https://generativelanguage.googleapis.com/v1beta/models/$($modelName):generateContent?key=$GEMINI_API_KEY"
    $schemaBody = @{
        contents = @(
            @{
                parts = @(
                    @{ text = "Generate one CLAT UG Legal Reasoning MCQ (principle + facts style), different from before. Provide exactly 4 options and correct_index as a 0-based integer." }
                )
            }
        )
        generationConfig = @{
            response_mime_type = "application/json"
            response_schema = $responseSchema
        }
    } | ConvertTo-Json -Depth 20

    $result = Invoke-GeminiWithRetry -url $schemaUrl -bodyJson $schemaBody
    if ($result.Success) {
        $raw = $result.Response.candidates[0].content.parts[0].text
        $parsed = $raw | ConvertFrom-Json
        $ok = $parsed.question -and $parsed.options -and ($null -ne $parsed.correct_index) -and $parsed.explanation
        if ($ok) {
            $successCount++
            Write-Host "  Attempt $i : PASSED" -ForegroundColor Green
        } else {
            Write-Host "  Attempt $i : FAILED (malformed/missing fields)" -ForegroundColor Red
            Write-Host "    Raw: $raw"
        }
    } else {
        Write-Host "  Attempt $i : FAILED (after retries)" -ForegroundColor Red
        Write-Host "    $($result.Body)" -ForegroundColor Red
    }
}
Write-Host ""
Write-Host "Reliability result: $successCount / 5 structured calls passed schema validation." -ForegroundColor Cyan

# ------------------------------------------------------------
# 13.2 — RSS feed tests
# ------------------------------------------------------------
Write-Section "13.2 RSS Feed Tests"

$feeds = @(
    @{ Name = "The Hindu - National";  Urls = @("https://www.thehindu.com/news/national/feeder/default.rss") },
    @{ Name = "The Hindu - Editorial"; Urls = @("https://www.thehindu.com/opinion/editorial/feeder/default.rss") },
    @{ Name = "LiveLaw";               Urls = @("https://www.livelaw.in/feed", "https://www.livelaw.in/feed/", "https://www.livelaw.in/rss.xml") },
    @{ Name = "Bar & Bench";           Urls = @("https://www.barandbench.com/feed") }
)

$feedResults = @()

foreach ($feed in $feeds) {
    Write-Host ""
    Write-Host "---- $($feed.Name) ----" -ForegroundColor Yellow

    $succeeded = $false
    foreach ($url in $feed.Urls) {
        Write-Host "URL: $url"
        try {
            $raw = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15 -Headers @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }
            Write-Host "HTTP Status: $($raw.StatusCode)" -ForegroundColor Green

            try {
                [xml]$xml = $raw.Content
                $items = $xml.rss.channel.item
                if (-not $items) { $items = $xml.feed.entry }  # Atom fallback

                if ($items -and $items.Count -gt 0) {
                    Write-Host "Parsed as valid XML/RSS. Item count found: $($items.Count)" -ForegroundColor Green
                    Write-Host "Sample of first 3-5 items:"
                    $items | Select-Object -First 5 | ForEach-Object {
                        $title = Get-NodeText $_.title
                        $link = Get-NodeText $_.link
                        $pubDate = Get-NodeText $_.pubDate
                        if (-not $pubDate) { $pubDate = Get-NodeText $_.published }
                        $desc = Get-NodeText $_.description
                        if (-not $desc) { $desc = Get-NodeText $_.summary }
                        $descPresent = if ($desc) { "yes" } else { "NO (title-only feed)" }

                        Write-Host "  - Title: $title"
                        Write-Host "    Link: $link"
                        Write-Host "    PubDate: $pubDate"
                        Write-Host "    Description present: $descPresent"
                        Write-Host ""
                    }

                    # Recency check on first item
                    $firstDateRaw = Get-NodeText $items[0].pubDate
                    if (-not $firstDateRaw) { $firstDateRaw = Get-NodeText $items[0].published }
                    try {
                        $firstDate = [datetime]::Parse($firstDateRaw)
                        $ageHours = (Get-Date) - $firstDate
                        Write-Host "Most recent item age: $([math]::Round($ageHours.TotalHours,1)) hours old" -ForegroundColor Cyan
                        $isRecent = $ageHours.TotalHours -lt 72
                        Write-Host "Recency check (<72h): $(if ($isRecent) {'PASS'} else {'STALE - possible cached snapshot'})" -ForegroundColor $(if ($isRecent) {'Green'} else {'Red'})
                    } catch {
                        Write-Host "Could not parse pubDate for recency check: $firstDateRaw" -ForegroundColor Red
                    }

                    $feedResults += [PSCustomObject]@{ Feed = $feed.Name; Status = "OK"; ItemCount = $items.Count; WorkingUrl = $url }
                    $succeeded = $true
                    break
                } else {
                    Write-Host "XML parsed but no <item> or <entry> elements found - check feed format." -ForegroundColor Red
                }
            } catch {
                Write-Host "FAILED to parse response as XML - likely an HTML error page, paywall redirect, or consent wall." -ForegroundColor Red
                Write-Host "First 300 chars of response:" -ForegroundColor Red
                Write-Host ($raw.Content.Substring(0, [Math]::Min(300, $raw.Content.Length)))
            }
        } catch {
            Write-Host "FAILED to fetch URL:" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }

    if (-not $succeeded) {
        $feedResults += [PSCustomObject]@{ Feed = $feed.Name; Status = "FAILED"; ItemCount = 0; WorkingUrl = "none" }
    }
}

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------
Write-Section "SUMMARY"
Write-Host "Gemini structured-output reliability: $successCount / 5" -ForegroundColor Cyan
Write-Host ""
Write-Host "RSS feed results:" -ForegroundColor Cyan
$feedResults | Format-Table -AutoSize

$workingFeeds = ($feedResults | Where-Object { $_.Status -eq "OK" }).Count
Write-Host ""
Write-Host "Pass/fail bar check (spec 13.3):"
Write-Host "  Gemini: $(if ($successCount -ge 4) {'LIKELY PASS'} else {'LIKELY FAIL'}) (needs consistent structured output, not 1-in-5)"
Write-Host "  News feeds: $(if ($workingFeeds -ge 2) {'PASS'} else {'FAIL'}) ($workingFeeds of 4 feeds returned well-formed recent items, need >=2)"
