# CLAT Pacer — Product Document

**Version:** 1.0
**Platform:** Flutter (Android, iOS, Web, Windows, macOS, Linux)
**Last updated:** 2026-11-15

---

## 1. What Is CLAT Pacer?

CLAT Pacer is an AI-powered, offline-first mobile app that trains law school aspirants for the **Common Law Admission Test (CLAT)**. Every question is generated fresh by Sarvam's Qwen model using live news headlines — the app never serves a recycled question bank. It tracks performance over time, identifies weak spots, and adapts daily practice accordingly.

---

## 2. Target Users

| Persona | Description |
|---------|-------------|
| **CLAT Aspirant (12th grade / gap year)** | Primary user. Preparing 6–18 months before the exam. Needs daily structured practice without paying ₹10,000+ for coaching. |
| **Coaching Institute Student** | Uses the app as a supplement to classroom learning for self-paced drilling. |
| **Re-taker** | Has attempted CLAT once; wants to improve specific weak sections. |

---

## 3. Core Value Propositions

1. **Fresh questions every day** — Sarvam generates questions on demand; nothing is recycled.
2. **News-aware** — GK and reading comprehension passages are grounded in today's RSS headlines from The Hindu, Bar & Bench, LiveLaw, and Indian Express.
3. **Realistic exam simulation** — Full 120-question mock with CLAT's exact negative-marking scheme (+1 / −0.25).
4. **Smart weak-area targeting** — Brain Gym tracks per-topic accuracy and surfaces focused 5-question drills.
5. **Zero subscription** — All features work with a free Sarvam API key.

---

## 4. Features (Current)

### 4.1 Daily Sprint
- Fetches 5 RSS feeds in parallel; Sarvam selects 3 most CLAT-relevant passages.
- Timed reading (5 minutes) with live WPM counter.
- 5 elimination-style MCQs per passage (users can strike options before selecting).
- 5 swipeable flashcards with key facts per passage.
- Streak counter; stats saved: words read, average WPM, session count.

### 4.2 Full Mock Test
- Choose **Half-length** (60 Q / 60 min) or **Full-length** (120 Q / 120 min).
- 5 sections with tab navigation: Legal Reasoning, GK, Logical Reasoning, Quant, English.
- Free navigation (previous/next/jump), mark-for-review, live countdown timer.
- Negative marking: +1 correct, −0.25 wrong, 0 unattempted.
- Detailed results: net score, per-section breakdown (correct / wrong / unattempted).

### 4.3 Section Practice (5 Modules)
Each generates 10 fresh questions on demand:

| Section | Question Type |
|---------|--------------|
| Legal Reasoning | Principle → factual scenario; apply the principle |
| GK / Current Affairs | Live headline-grounded + static general knowledge |
| Logical Reasoning | Short argument; rotating archetypes (assumption / inference / strengthen / weaken / conclusion) |
| Quantitative Techniques | Text-only data: percentage, ratio, interest, speed-distance-time |
| English & Reading Comprehension | 2 original passages (~450–500 words) + 5 Qs each |

After each session: score + reviewable list of all questions with correct answers and explanations.

### 4.4 Brain Gym
- Tracks accuracy per (section, topic) pair from every quiz attempt.
- Surfaces topics with 3+ attempts ranked by accuracy (lowest first).
- Tap any weak topic → 5 focused drills generated on demand.

### 4.5 Dashboard
- Streak counter, average WPM, total words conquered (odometer display), sessions completed.
- One-tap navigation to all features.

### 4.6 Settings
- Encrypted Sarvam API key management (Android Keystore / iOS Keychain via flutter_secure_storage).
- **Daily reminder:** opt-in notification at a user-chosen time (default 7:00 PM, device time zone) nudging the user to finish the Daily Sprint. Today's reminder is skipped once a sprint is completed. Android, iOS and macOS; schedules a rolling 30-day window that is refreshed whenever the app opens.

---

## 5. Technical Architecture

### 5.1 Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart 3.3+) |
| State Management | StatefulWidget + static StorageService singleton |
| Local Persistence | shared_preferences (JSON) + flutter_secure_storage (API key) |
| AI Backend | Sarvam API — `sarvam-105b-conversations` model |
| News Feed | 5 RSS feeds (XML parsed via the `xml` package) |
| HTTP | `http` package |

### 5.2 External API Integrations

**Sarvam API**
- Endpoint: `https://api.sarvam.ai/v1/chat/completions`
- Auth: Bearer token (encrypted on device)
- Rate limits: not publicly documented; app retries on 429
- Batching: 6 questions per request, 10-second pause between batches
- Retry: exponential backoff (5s → 15s → 30s)

**RSS Feeds**
- The Hindu — National & Editorial
- Bar & Bench
- Indian Express — Explained
- LiveLaw — Top Stories
- Fetched in parallel; individual failures degrade gracefully.

### 5.3 Data Models (Summary)

```
QuizQuestion       → prompt, options[4], correctIndex, explanation, section, topic, passage?
QuizAttempt        → section, date, score, total, durationSeconds
TopicRecord        → section, topic, correct, date  (raw per-question log)
MockAttempt        → date, duration, sections: List<MockSectionResult>
MockSectionResult  → section, correct, wrong, unattempted, netScore
DashboardStats     → streak, totalWordsRead, averageWpm, sessionsCount
PassageModel       → title, body, questions, flashcards, wordCount
```

All data stored locally in SharedPreferences (JSON-serialized). No cloud sync, no user authentication.

### 5.4 Navigation Hierarchy

```
Home
├── Settings
├── Daily Sprint → List → [Passage] Pacer → Questions → Results → Flashcards
├── Mock Test → Loading (Half/Full choice) → Taking → Results
├── Legal Reasoning → Quiz → Results
├── GK / Current Affairs → Quiz → Results
├── Logical Reasoning → Quiz → Results
├── Quantitative Techniques → Quiz → Results
├── English & RC → Quiz → Results
└── Brain Gym → [Weak Topic] → Quiz → Results
```

### 5.5 Design System

- **Palette:** light, soft-sky theme (pale-blue page background, white cards with soft shadows, blue primary, teal success, rose error, amber warning). Tokens live in `lib/theme/app_theme.dart` (`AppColors`, `AppStyle`); text colours meet WCAG AA on both the page and card backgrounds.
- **Layout tokens:** 28 / 24 / 16 / 12px radii; pill buttons and chips; pastel-gradient feature cards; floating bottom navigation on Home
- **Home:** greeting + streak pill, gradient Daily Sprint and Mock Test banners, stat cards, searchable and filterable (All / Verbal / Reasoning / Quant / Drills) horizontal section cards
- **Interaction:** Elimination trainer (strike options), swipeable PageView flashcards, live progress on loading screens

---

## 6. Known Constraints & Limitations

| Constraint | Detail |
|------------|--------|
| Sarvam free-tier rate limit | unpublished limits (Groq-era 8k tokens/min pacing kept); batching adds ~30 s to full mock generation |
| No cross-device sync | All data local; uninstalling the app loses all history |
| No question deduplication | Each session generates fresh Qs; no guarantee of zero overlap across sessions |
| No offline question fallback | If Sarvam is unreachable, the app cannot generate questions |
| Single user | No multi-profile support; designed for one student per device |
| Quant section scope | Text-only math problems; no graphs, tables, or data interpretation |
| English passages | AI-generated, not sourced from real CLAT paper archives |
| No adaptive difficulty | Questions do not scale harder/easier based on performance yet |

---

## 7. Enhancement Roadmap (Proposed)

> These are candidate features for the next development phase. Priorities to be confirmed.

### High Priority

| # | Feature | Rationale |
|---|---------|-----------|
| H1 | **Performance Analytics Dashboard** | Students need trend charts (WPM over time, section-wise accuracy trends) to feel progress |
| H2 | **Question Deduplication / History** | Prevent identical Qs appearing across sessions; store recent question hashes |
| H3 | **Offline Fallback Question Bank** | Bundle 200 static Qs per section so the app works without internet after first run |
| H4 | **Mock Test History** | List past mock attempts with scores and date; allow reviewing any past test |
| H5 | **Adaptive Difficulty** | Tag questions easy/medium/hard; serve harder Qs when accuracy > 80%, easier when < 50% |

### Medium Priority

| # | Feature | Rationale |
|---|---------|-----------|
| M1 | **Study Plan / Schedule** | Let student set exam date; auto-generate a day-by-day plan covering all sections |
| M2 | **Bookmarks / Saved Questions** | Star a question from results screen to revisit it in a "Saved" deck |
| M3 | ~~**Daily Reminder Notification**~~ ✅ Done | Local notification at a user-set time to protect the streak (see 4.6) |
| M4 | **Explanation Quality Toggle** | Option for brief vs. detailed explanations (some users prefer just the correct answer) |
| M5 | **Data Interpretation (Quant)** | Tables and simple bar/pie charts for data interpretation Qs — closer to real CLAT |
| M6 | **Cloud Backup (optional opt-in)** | Firebase-based export of stats so users can switch devices |

### Lower Priority / Future

| # | Feature | Rationale |
|---|---------|-----------|
| L1 | **Peer Leaderboard** | Weekly WPM / mock score ranking among opted-in users |
| L2 | **Legal Vocabulary Builder** | Daily 5-word flashcard set from judgment excerpts |
| L3 | **Paper Archive Mode** | Import official past CLAT papers as a static test mode |
| L4 | **Multi-language UI** | Hindi interface option for Tier-2 city students |
| L5 | **Coaching Mode** | Teacher dashboard: assign tests, see student performance, export reports |

---

## 8. Success Metrics

| Metric | Target |
|--------|--------|
| Daily Sprint completion rate | ≥ 70% of sessions started → completed |
| 7-day retention | ≥ 40% of users active on day 7 |
| Average streak length | ≥ 5 days |
| Mock test completion rate | ≥ 80% of mock tests started → submitted |
| Brain Gym utilization | ≥ 30% of active users open Brain Gym at least once per week |
