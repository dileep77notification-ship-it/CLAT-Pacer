# CLAT Pacer - Sarvam Daily Sprint (news article) test
# Mirrors the app: fetch 5 RSS feeds -> pick a story -> passage + 5 MCQs + 5 flashcards.
# Usage:  $env:SARVAM_API_KEY = "<your key>"; .\clat_sarvam_news_test.ps1
# Optional: $env:SARVAM_MODEL = "sarvam-105b"

$key = $env:SARVAM_API_KEY
if (-not $key) { Write-Host "Set SARVAM_API_KEY first." -ForegroundColor Red; exit 1 }
$model = if ($env:SARVAM_MODEL) { $env:SARVAM_MODEL } else { "sarvam-105b-conversations" }
$url = "https://api.sarvam.ai/v1/chat/completions"
$headers = @{ "Authorization" = "Bearer $key"; "api-subscription-key" = $key; "Content-Type" = "application/json" }

$feeds = @(
  @("The Hindu - National",  "https://www.thehindu.com/news/national/feeder/default.rss"),
  @("The Hindu - Editorial", "https://www.thehindu.com/opinion/editorial/feeder/default.rss"),
  @("Bar & Bench",           "https://www.barandbench.com/feed"),
  @("Indian Express",        "https://indianexpress.com/section/explained/feed/"),
  @("LiveLaw",               "https://www.livelaw.in/category/mobile-notification/google_feeds.xml")
)

Write-Host "`n[1] Fetching RSS feeds" -ForegroundColor Cyan
$headlines = @()
foreach ($f in $feeds) {
  try {
    $raw = (Invoke-WebRequest $f[1] -UserAgent "Mozilla/5.0" -TimeoutSec 20 -UseBasicParsing).Content
    $xml = [xml]$raw.Substring($raw.IndexOf('<'))
    $items = @($xml.SelectNodes("//item")); if ($items.Count -eq 0) { $items = @($xml.SelectNodes("//*[local-name()='entry']")) }
    $titles = $items | Select-Object -First 8 | ForEach-Object {
      $t = $_.title; if ($t -isnot [string]) { $t = $t.InnerText }; $t.Trim() }
    $titles | ForEach-Object { $headlines += "[$($f[0])] $_" }
    Write-Host "  PASS $($f[0]): $($titles.Count) headlines" -ForegroundColor Green
  } catch { Write-Host "  FAIL $($f[0]): $($_.Exception.Message)" -ForegroundColor Red }
}
if ($headlines.Count -eq 0) { Write-Host "No headlines fetched." -ForegroundColor Red; exit 1 }
$headlinesText = ($headlines | ForEach-Object { "- $_" }) -join "`n"

$tool = @{ type = "function"; function = @{
  name = "submit_daily_passage"; description = "Submit the generated CLAT daily Current Affairs passage with its questions and flashcards."
  parameters = @{ type = "object"; required = @("source_headline","title","body","questions","flashcards"); properties = @{
    source_headline = @{ type = "string"; description = "The exact headline text, copied from the provided list, that this passage is based on." }
    title = @{ type = "string" }
    body = @{ type = "string"; description = "The ~450-500 word CLAT-style passage." }
    questions = @{ type = "array"; minItems = 5; maxItems = 5; items = @{ type = "object"; required = @("question","options","correct_index"); properties = @{
      question = @{ type = "string" }; options = @{ type = "array"; items = @{ type = "string" }; minItems = 4; maxItems = 4 }; correct_index = @{ type = "integer" } } } }
    flashcards = @{ type = "array"; minItems = 5; maxItems = 5; items = @{ type = "object"; required = @("title","fact"); properties = @{
      title = @{ type = "string" }; fact = @{ type = "string" } } } } } } } }

function Get-Prompt($used) {
  $ex = ""; if ($used.Count) { $ex = "`n`nDo NOT pick any of these stories - they are already covered by other passages today:`n" + (($used | ForEach-Object { "- $_" }) -join "`n") }
@"
You are a CLAT (Common Law Admission Test) content writer producing one passage of the daily Current Affairs set. You will be given a list of today's news headlines from Indian sources. Your job:

1. Pick the SINGLE most CLAT-relevant story from the list that is not already covered - prioritize law, judiciary, Parliament/legislation, constitutional matters, and major national or international events with civic/legal significance.
2. Write an ORIGINAL ~450-500 word passage in CLAT comprehension-passage style about that story's topic, using your own general knowledge of the subject - not a verbatim reproduction of any article.
3. Write exactly 5 multiple-choice questions testing comprehension of the passage (4 options each, one correct).
4. Write exactly 5 short flashcard facts related to the passage's topic.
5. Report back the exact headline text (copied from the list) via the source_headline field.

IMPORTANT RULES:
- Respond entirely in English. No non-English characters, words, or scripts.
- Do not restate the options inside a question's own text.
- Exactly 4 options per question, and exactly 5 questions and 5 flashcards.$ex
"@ }

Write-Host "`n[2] Generating 2 passages (second must avoid the first story)" -ForegroundColor Cyan
$used = @()
foreach ($n in 1..2) {
  $body = @{ model = $model; max_tokens = 3500
    messages = @(@{ role = "system"; content = (Get-Prompt $used) },
                 @{ role = "user"; content = "Today's headlines:`n$headlinesText`n`nPick the single most CLAT-relevant story not already covered and generate the passage, questions, and flashcards via the submit_daily_passage tool." })
    tools = @($tool); tool_choice = @{ type = "function"; function = @{ name = "submit_daily_passage" } } } | ConvertTo-Json -Depth 20
  try {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $r = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -TimeoutSec 90
    $sw.Stop()
    $choice = $r.choices[0]
    $p = $choice.message.tool_calls[0].function.arguments | ConvertFrom-Json
    $words = ($p.body -split '\s+').Count
    $qOk = $p.questions.Count -eq 5 -and (@($p.questions | Where-Object { $_.options.Count -eq 4 -and $_.correct_index -ge 0 -and $_.correct_index -le 3 }).Count -eq 5)
    $fOk = $p.flashcards.Count -eq 5
    $inList = $headlines | Where-Object { $_ -like "*$($p.source_headline)*" }
    $nonAscii = $p.body -match '[^\u0000-\u007F‘’“”–—…]'
    $dup = $used -contains $p.source_headline
    Write-Host "`n  Passage $n ($([math]::Round($sw.Elapsed.TotalSeconds,1))s, tokens=$($r.usage.total_tokens), finish=$($choice.finish_reason))" -ForegroundColor Green
    Write-Host "    Title:    $($p.title)"
    Write-Host "    Source:   $($p.source_headline)"
    Write-Host "    Words:    $words (target 450-500)"
    Write-Host "    5 MCQs valid: $qOk | 5 flashcards: $fOk | source in list: $([bool]$inList) | repeats earlier story: $dup | odd characters: $nonAscii"
    Write-Host "    Preview:  $($p.body.Substring(0, [Math]::Min(220, $p.body.Length)))..."
    $used += $p.source_headline
  } catch {
    $msg = $_.ErrorDetails.Message; if (-not $msg) { $msg = $_.Exception.Message }
    Write-Host "  Passage ${n}: FAIL - $msg" -ForegroundColor Red
  }
}
