# Hackerring 2.0 — Audience-Aware Video Transformation

> **One recording. Every audience. Same meaning.**

An AI-assisted video editing backend for **Hackerring 2.0 / HR26-AI-03 (Video Content Creation)**. Upload one recording, choose a target audience, explain what that audience should understand, and request a preferred length. The system transcribes and classifies the recording, proposes a source-grounded edit, checks it for meaning risks, and can render approved source clips to MP4.

**Project status:** The repository contains a unified source-classification and audience-editing API, with the native ContextGuard verifier connected through an adapter that preserves the pipeline's Contracts A/B/C. A live run (real Whisper, local-fallback classification after an Agnes stall, real NLI guard, FFmpeg MP4) is recorded below; small synthetic cases do not establish production accuracy. The TESSERA studio frontend is a five-step flow — Upload & Setup, AI Processing, Video Topic, Review & Edit, Final Output — integrated with the FastAPI client contract; its static build and contract tests run in CI. An explicit creator override can admit a `blocked` render, and the override is recorded on the version rather than applied silently. Real local inference requires optional model dependencies and cached/downloaded weights; unavailable verification fails closed.

## What it does

- **Source analysis:** FFmpeg/ffprobe inspect the uploaded media, faster-whisper produces timestamped speech segments, and Agnes classifies topics, claims, qualifications, relationships, repetitions and corrections (or the local deterministic heuristics when `CLASSIFICATION_ENGINE=local` or Agnes is unreachable).
- **Processing runs with live estimates:** Each audience run starts a server-side tracking run (`POST /projects/{id}/processing-runs`) whose snapshots the studio polls independently while analysis runs. A missing route or failed start leaves estimates honestly unavailable without blocking analysis.
- **Video-topic review:** Before any edit plan is created, the creator reviews AI-suggested topic bullets, fixes wording, and locks the final ones (`GET`/`PATCH /projects/{id}/topics`). Locked bullets are the truth the plan is built from.
- **Audience-aware planning:** Selects relevant source segments for the backend-advertised audience profiles or a custom audience. Adjacent transcript chunks that belong to one unfinished sentence are selected or dropped together; independent complete sentences remain eligible for meaningful audience cuts. Plans explain KEEP/CUT decisions and preserve original timestamp references.
- **Meaning protection:** A separate ContextGuard interface checks the proposed final sequence for harmful omissions. The backend refuses to treat an unavailable verifier as a SAFE result.
- **Review and rendering:** Review operations can restore/remove source segments, acknowledge issues, or change the target audience/purpose/duration. Approved plans render original footage via FFmpeg with an output-to-source manifest. A blocked verdict can be rendered anyway only behind an explicit creator confirmation, recorded on the version (`guard_override`).
- **Versions and workspace:** Every review creates a new stored plan version; rendered versions keep a pinned output URL, and older versions open read-only. Projects can be reopened, listed, and deleted through the workspace endpoints.
- **Topic clips and mistake cleanup:** Saved topic clips can be suggested, edited, and rendered individually, and a separate mistake-cleanup pass removes filler/false-starts/repeats/silence without touching the audience plan.
- **Social publishing:** A finished render can be published to a connected YouTube, X, or Instagram account from the Final Output card, with idempotent requests and real provider post IDs (see below).

The target duration is a preference, not a reason to clip speech mid-sentence. If no useful complete unit fits, the planner may keep a longer useful unit and note the deviation. Independent complete sentences remain eligible for audience-specific cuts; source order and semantic protections remain. Explicit human remove choices stay visible to ContextGuard rather than being silently reversed. Repeated-take detection requires duplicate/retake evidence, not merely same-topic vocabulary, and keeps distinct numbers, entities, polarity, and conditions separate.

## Current implementation

| Area | Status | Location |
| --- | --- | --- |
| Upload, media inspection, audio extraction | Implemented | `src/source_classification/` |
| Whisper transcription with timestamps | Implemented | `src/source_classification/transcription.py` |
| Agnes-backed source classification | Implemented; live API credentials required | `src/source_classification/classification.py` |
| Audience selection and edit planning | Implemented; rule-based fallback available | `backend/ai/` |
| ContextGuard adapter and fail-closed behavior | Implemented; local inference is optional | `backend/ai/guard_client.py`, `backend/ai/context_guard.py`, `backend/ai/guard_bridge.py` |
| Native ContextGuard NLI and rules | Pinned-model CPU/auto inference exercised on synthetic cases; broader accuracy and target-floor remain unmeasured | `backend/ai/context_guard.py`, `backend/ai/guard_*.py`, `backend/ai/nli_*.py` |
| Video topics with lock-as-truth review | Implemented | `backend/routes/topics.py`, `backend/services/topic_store.py` |
| Processing runs and live ETA snapshots | Implemented | `backend/routes/processing.py`, `backend/services/processing_eta.py` |
| Topic clips (suggest/edit/render) | Implemented | `backend/routes/clips.py` |
| Mistake cleanup pass | Implemented | `backend/ai/mistakes.py`, editing routes |
| Workspace, versions, project deletion | Implemented | `backend/routes/workspace.py`, `backend/routes/project_deletion.py`, `backend/services/project_store.py` |
| Social publishing (YouTube/X/Instagram) | Implemented; provider credentials required | `backend/routes/social.py`, `backend/social/` |
| FFmpeg cut/concat and source manifest | Implemented | `backend/rendering/renderer.py` |
| SQLite edit-plan history | Implemented | `backend/services/project_store.py` |
| **TESSERA studio frontend** | Integrated; Next.js build and API-adapter tests automated | `app/`, `components/`, `lib/` |
| Full live Whisper → ContextGuard → MP4 run | **Verified** (local-classifier fallback; Agnes answered once, then stalled) | Evidence table below |

See [the post-merge audit](https://github.com/RajRishi1896/Hackerring-Project/issues/6) for remaining blockers, operational risks, and acceptance criteria.

## Pipeline

```text
Original MP4 / MOV / WebM
      |
      v
FFprobe inspection + FFmpeg audio extraction
      |
      v
faster-whisper -> transcript + original timestamps
      |
      v
Agnes source analysis -> topics, claims, dependencies
      |
      v
Topic bullets -> creator review, wording fixes, locks
      |
      v
Audience relevance -> KEEP / CUT edit plan
      |
      v
ContextGuard -> SAFE / NEEDS_REVIEW / BLOCKED
      |
      v
Creator review, restoration and re-verification
      |
      v
FFmpeg trim / concat -> final MP4 + source mapping
      |
      v
Optional social publish of the exact finished file
```

All cuts refer back to timestamps **in the original uploaded video**. Rendering uses accurate source trims and a consistent joined audio/video clock in constant-frame-rate (CFR) output; FFmpeg re-encodes the approved intervals rather than stream-copying, and the system does **not** generate replacement footage from text. This does not promise to remove pauses already present in the source or guarantee gapless playback on arbitrary networks.

## Requirements

- **Python 3.11 or newer** (declared minimum; CI uses 3.11)
- **FFmpeg and ffprobe**: tried automatically at startup through the platform package manager (winget/choco/scoop, brew, apt-get/dnf/pacman); otherwise install them and add them to `PATH`, or set `FFMPEG_BIN`/`FFPROBE_BIN`
- Enough RAM and CPU/GPU capacity for the selected faster-whisper model
- **Agnes API access** for live source classification, unless tests inject a classifier stub
- Linux, macOS, or Windows development environment

Both servers run a startup dependency check before serving. The unified API verifies ffmpeg, ffprobe, the faster-whisper package and speech model, and the configured reviewer; `python -m backend` verifies only the reviewer. Anything absent is downloaded when that is safe (package manager, first-use model download). A missing tool or model with no fallback refuses startup with one message naming each item; a missing reviewer under the default `auto` mode serves degraded instead, with per-request denial and honest `/health`, while `local` mode requires it. Missing Python packages are reported with the install command, never installed. An injected reviewer (tests) bypasses the check.

### Install

From the repository root:

```bash
python -m venv .venv

# Linux / macOS
source .venv/bin/activate

# Windows PowerShell
# .venv\Scripts\Activate.ps1

python -m pip install --upgrade pip
python -m pip install -r requirements.txt
python -m pip install -e ".[server,test]"

ffmpeg -version
ffprobe -version
```

Copy `.env.example` to `.env`, then supply the required environment values. **Never commit API keys or uploaded media.** The application does not automatically load an ordinary `.env` file when launched without `--env-file`.

### Agnes configuration: three clients currently exist

Agnes configuration is not unified across the repository:

- **Source classification** (`src/source_classification/agnes.py`) uses `AGNES_API_KEY` and hardcodes its endpoint and model (`https://apihub.agnes-ai.com/v1`, `agnes-3.0-flash`), with a 30-second default timeout.
- **Audience relevance** (`backend/ai/agnes.py`) uses `AGNES_API_KEY`, `AGNES_BASE_URL`, `AGNES_MODEL`, and optional `AGNES_CHAT_PATH`, `AGNES_TIMEOUT`, `AGNES_AUTH_HEADER`, and `AGNES_AUTH_SCHEME`.
- **Native ContextGuard review** (`backend/ai/guard_agnes.py`) uses `AGNES_API_KEY`, `AGNES_MODEL`, and optional full URL `AGNES_CHAT_COMPLETIONS_URL`; its default is the documented Agnes chat-completions endpoint and model. It sends one request per review and does not retry.

Use the endpoint, model, and auth details supplied for your Agnes account; do not assume one client's settings configure the other two. Agnes' free/default 10 requests per minute limit is shared by calls using that key, including source analysis, audience planning, and ContextGuard. Coordinate the rate budget and in-flight requests across clients; ContextGuard itself has no quota scheduler or retry loop. `RELEVANCE_ENGINE=auto` may use deterministic relevance instead, which is not evidence that live Agnes reasoning ran.

### Start the API

```bash
python -m uvicorn backend.main:app --reload --port 8000 --env-file .env
```

API documentation: **http://localhost:8000/docs**

Liveness and active model indicators: **http://localhost:8000/health**

The unified `/health` response includes `status`, `relevance_engine`, `agnes_configured`, `context_guard`, `context_guard_configured`, `context_guard_available`, `context_guard_ready`, and `context_guard_device`. `context_guard` is `not_initialized` before selection; `context_guard_configured` is null before the first attempt, then reports whether a reviewer was selected. `context_guard_available` stays false until a real reviewer call returns; `context_guard_ready` records whether any call has succeeded. Neither means the result was safe. Device is null until the selected backend reports one. The database path is intentionally omitted from health responses.

The unified FastAPI application mounts classification, editing, topics, processing-run, clips, workspace, deletion, and social endpoints. During development, use one worker; in-process background tasks and some state are not designed as a production job queue.

## API walkthrough

The following shows the **real API contracts**. Replace `VIDEO_ID` with the `video_id` returned by upload. A successful upload does not imply analysis has finished.

### 1. Upload a recording

```bash
curl -X POST http://localhost:8000/projects \
  -F "file=@sample.mp4"
```

Returns a project ID, media metadata, and an initial processing status. Supported media formats are determined by FFmpeg/ffprobe; the current code is not a hardened public upload service.

### 2. Start source analysis

```bash
curl -X POST http://localhost:8000/projects/VIDEO_ID/analyze
curl http://localhost:8000/projects/VIDEO_ID
curl http://localhost:8000/projects/VIDEO_ID/analysis
```

Poll the project until it reaches `completed` or `failed`. Analysis requires a working Agnes credential and a transcription-capable source recording. Its data is persisted at `storage/projects/<video_id>/analysis.json`.

Each audience run may also open a tracking run for live estimates:

```bash
curl -X POST http://localhost:8000/projects/VIDEO_ID/processing-runs \
  -H "Content-Type: application/json" \
  -d '{"audience":"Student","audience_goal":"...","original_duration_seconds":120,"target_duration_seconds":180}'
curl http://localhost:8000/projects/VIDEO_ID/processing-runs/RUN_ID
```

### 3. Review video topics, then generate the edit plan

```bash
curl http://localhost:8000/projects/VIDEO_ID/topics
curl -X PATCH http://localhost:8000/projects/VIDEO_ID/topics \
  -H "Content-Type: application/json" \
  -d '{"operations":[{"op":"update_text","bullet_id":"b1","text":"..."},{"op":"lock","bullet_id":"b1"}]}'

curl -X POST http://localhost:8000/projects/VIDEO_ID/plan \
  -H "Content-Type: application/json" \
  -d '{
    "audience": "first_time_customer",
    "purpose": "Understand the problem, product, and main benefit",
    "target_duration_seconds": 180,
    "engine": "auto"
  }'
```

Also available:

- `GET /projects/VIDEO_ID/audiences` — available profiles and suggested purposes.
- `GET /projects/VIDEO_ID/edit-plan` — ordered clips, omissions, reasons, issues, repair suggestions and render eligibility.
- `GET /projects/VIDEO_ID/edit-plan?version=N` — a pinned earlier version (read-only).
- `POST /projects/VIDEO_ID/edit-plan/reverify` — re-run ContextGuard on the stored plan as reviewed (restores, removals and acknowledgements kept); unlike re-planning, it never drops review decisions.

With `CONTEXT_GUARD_MODE=auto`, the planner calls the in-process native guard through the compatibility bridge. The default `CONTEXTGUARD_BACKEND=local_nli` requires the optional local runtime and model weights. The unified API does not preload this reviewer at application startup; it resolves and loads it when verification is first requested. Missing dependencies, weights, or incomplete review deny automatic rendering rather than certify the plan.

### 4. Review edits and render

```bash
curl -X PATCH http://localhost:8000/projects/VIDEO_ID/edit-plan \
  -H "Content-Type: application/json" \
  -d '{"operations":[{"op":"restore","segment_ids":["seg-000001"]}]}'

# Only succeeds when the edit plan passes the verification/review gate:
curl -X POST http://localhost:8000/projects/VIDEO_ID/render \
  -H "Content-Type: application/json" -d '{}'

curl http://localhost:8000/projects/VIDEO_ID/edit-plan
curl -L http://localhost:8000/projects/VIDEO_ID/output -o edited.mp4
```

Review operations include `restore`, `remove`, `acknowledge`, `approve`, `set_duration`, `set_audience`, and `set_purpose`. Modifications trigger verification again. `POST /projects/VIDEO_ID/edit-plan/reverify` re-runs verification on the stored plan without changing it, so retrying a failed check keeps every review decision. Rendering is asynchronous and exposes progress/status through the edit-plan endpoint. `GET /projects/VIDEO_ID/output?download=true` requests a download; `GET /projects/VIDEO_ID/output?version=N` addresses a pinned earlier render.

A `blocked` verdict can be rendered anyway only with an explicit creator override (`{"override_blocked": true}`), which the backend records on the version (`guard_override`) instead of applying silently.

**Safety note:** Do not use `CONTEXT_GUARD_MODE=disabled` for a real demo or deployment. A live TTS-spoken run passed upload, real Whisper, fallback classification, same-app reviewer, fresh verification and FFmpeg output (below); a second run with contradictory content was honestly blocked. Live Agnes answered once (paraphrased) then stalled; production semantic accuracy remains unproven.

### 5. Publish the finished render (optional)

Once a render is complete, the exact finished file can be published directly to a connected YouTube, X, or Instagram account: connect the account and enter the title/caption in the Final Output publish card, confirm the native upload in the confirmation dialog, and keep the returned real post ID (post/watch link shown when the provider returns one; it may be null even when published). See [Social publishing](docs/SOCIAL_PUBLISHING.md) for setup (backend-only credentials, OAuth callbacks, and platform limits).

## Shared data contracts

- **Contract A — `SourceAnalysis`:** `video_id`, original duration, stable segment IDs, `start`/`end` timestamps, transcript text, topics, claims and dependencies.
- **Contract B — `EditPlan`:** ordered original footage intervals, segment references, KEEP/CUT reasons, target and estimated durations, protected segments, review acknowledgements.
- **Contract C — `GuardResult`:** `safe` / `needs_review` / `blocked`, evidence-grounded issues, severity and recommended corrective actions.

The editing API's Contract A/B/C types are in `backend/models/contracts.py`. The native verifier has separate typed `SourceAnalysis`, `EditPlan`, and `GuardResult` models in `backend/models/context_guard.py`; `backend/ai/guard_bridge.py` translates between them, and `backend/ai/guard_client.py` connects that bridge to planning. The public editing payloads and lowercase status values remain unchanged. See `backend/README_PERSON4.md` for the editing-engine contract.

## Project structure

```text
backend/
  main.py                 # Unified FastAPI app
  config.py               # Storage and runtime settings
  ai/
    agnes.py              # Audience relevance Agnes client
    audience.py           # Audience relevance engines
    edit_planner.py       # Source-grounded edit plans and guard call
    speech_units.py       # Conservative grouping of transcript chunks into speech units
    mistakes.py           # Mistake-cleanup analysis
    clip_suggest.py       # Topic-clip suggestions
    guard_client.py       # Pipeline adapter and fail-closed selection
    guard_bridge.py       # Contract A/B/C <-> native guard mapping
    guard_lifecycle.py    # Lazy app reviewer, request context and lease
    render_gate.py        # Fresh render verification and export checks
    guard_agnes.py        # Native guard's separate Agnes reviewer
    context_guard.py      # Native rules, NLI review and results
    guard_rules.py, guard_review.py, guard_evidence.py
    local_nli.py, nli_*.py, review_backends.py # Optional NLI runtime
    nli_ownership.py      # Shared runtime pins and cross-loop leases
    guard_recovery.py     # Review suggestions
    guard_source_repairs.py # Source interval validation for review suggestions
    repetition.py         # Conservative duplicate/retake and continuity analysis
  models/
    contracts.py         # Editing pipeline Contracts A/B/C
    context_guard.py     # Native ContextGuard contracts
    topics.py            # Video-topic bullets and patch operations
  routes/
    editing.py           # Plan/review/render endpoints
    topics.py            # Topic bullet review
    processing.py        # Processing runs and ETA snapshots
    clips.py             # Topic-clip suggest/edit/render
    workspace.py         # Project and version listings
    project_deletion.py  # Project deletion
    social.py            # Social accounts and publishing
  rendering/renderer.py   # FFmpeg output
  services/               # Source files + SQLite plan history
  social/                 # YouTube/X/Instagram provider integrations
  startup_preflight.py, binary_acquisition.py # Startup check, tool download
  server.py, __main__.py # Standalone loopback ContextGuard service
src/source_classification/
  api.py                  # Upload, jobs, analysis endpoints
  media.py, audio.py      # FFprobe + FFmpeg ingestion
  transcription.py        # faster-whisper
  classification.py       # Topic/claim classification
  agnes.py                # Source-classification Agnes adapter
tests/                    # Classification, editing and integration tests
fixtures/                 # Development-only synthetic examples
scripts/                  # Demo and render verification helpers
.github/workflows/        # Backend CI
```

### Local files

Generated source media and analysis live under `storage/projects/<video_id>/`; render outputs are stored under that project's `output/` directory. SQLite stores edit plans and related metadata. Media, artifacts and `.env` should remain outside version control.

## Testing

```bash
python -m pytest -q
```

The root `pytest.ini` overrides the narrower settings in `pyproject.toml`, so `python -m pytest` runs the full repository suite: classification, editing, ContextGuard, topics, clips, workspace, social, and live-pipeline integration tests. ContextGuard fast CI (`contextguard-fast.yml`) sets `CONTEXTGUARD_RUN_MODEL_TESTS=0` and runs the guard subset with no provider calls or NLI weights; the full suite includes real Whisper/media tests and may acquire Whisper weights. See [the ContextGuard evidence table](docs/CONTEXTGUARD.md#validation-evidence) for scope and warnings.

```bash
node --test tests/*.cjs
```

The Node suites cover the studio without a build: controller behavior (ingestion, ETA tracking, opens, deletion, approval), workflow presentation contracts, transcript decisions, library/history rendering, social API and publish-panel behavior, render-override handling, and production honesty checks (no sample data, fixtures, or mock-mode branches).

CI runs three workflows:

| Workflow | Checks |
| --- | --- |
| `frontend.yml` | `pnpm typecheck`, `frontend-contract` tests, `pnpm build`, `landing-routes` tests |
| `tests.yml` | Full `pytest` on Python 3.11 with FFmpeg |
| `contextguard-fast.yml` | Guard subset, no model weights or provider calls |

For synthetic fixture development:

```bash
python scripts/make_demo_source.py --duration 150
python scripts/seed_demo_project.py video_001
```

These files and timestamps are **test fixtures, not genuine Whisper transcripts**. The staging demo is useful for testing clip selection and FFmpeg behavior without consuming API quota. Do not present fixture-generated results as live transcription or verification.

Optional verification scripts:

```bash
python scripts/verify_cut_accuracy.py --help
python scripts/verify_two_audiences.py --help
```

## TESSERA studio frontend

The Next.js app at the repository root is the product surface for this API. It is
a static export (`output: "export"`) with no server routes or rewrite proxy, so
it reaches the backend directly from the browser and the backend must allow its
origin through CORS. There is no demo mode: every screen reads real persisted
backend state, and every render comes from a verified plan.

The studio walks five steps — **Upload & Setup, AI Processing, Video Topic,
Review & Edit, Final Output** — with the stepper, workspace library, versions,
and settings around them. Analysis lands on topic review first; the edit plan
is created only after the creator continues from the reviewed topics. Older
plan versions open read-only; the output screen plays the current render, or —
when the current plan has no export of its own — the newest completed earlier
render, explicitly labelled as such.

### Run it

```bash
pnpm install
pnpm dev            # http://localhost:3000, product at /app, landing at /
pnpm typecheck
pnpm build          # emits out/
```

Point it at a backend by copying `app/.env.example` to **repository-root** `.env.local` before running `pnpm dev` or `pnpm build`, then setting the browser-visible base URL:

```bash
# .env.local  (repository root; Next.js does not read app/.env.local)
NEXT_PUBLIC_API_BASE_URL=http://localhost:8000
```

`NEXT_PUBLIC_*` values are inlined into the bundle, so this is public
configuration, never a place for a secret. The base URL is required: leave it
unset and the studio reports itself as unconfigured, with setup disabled and an
honest error instead of sample projects, fabricated progress, or downloads.

### Endpoints it uses

| UI action | Call |
| --- | --- |
| Upload a recording | `POST /projects` (multipart `file`) |
| Track the run live | `POST /projects/{video_id}/processing-runs`, poll `GET /projects/{video_id}/processing-runs/{runId}` |
| Analyse after upload | `POST /projects/{video_id}/analyze`, poll `GET /projects/{video_id}` and fetch transcript via `GET /projects/{video_id}/analysis` |
| Review video topics | `GET` / `PATCH /projects/{video_id}/topics` |
| List persisted projects | `GET /workspace/projects`, reopen one via `GET /workspace/projects/{video_id}` |
| Delete a project | `DELETE` via the project-deletion route, only after an explicit confirmation |
| List stored versions | `GET /workspace/versions` and `GET /projects/{video_id}/versions`; open a pinned version via `GET /projects/{video_id}/edit-plan?version=N` |
| Watch the original back | `GET /projects/{video_id}/source` (range-capable original media, never a generated still) |
| Build an edit plan | `POST /projects/{video_id}/plan` (audience id, purpose, target duration) |
| Refine the plan | `PATCH /projects/{video_id}/edit-plan` |
| Approve and render | `POST /projects/{video_id}/render` with the stored export preferences (`resolution`, `crf`), then poll the plan |
| Render a blocked plan anyway | Same call with `override_blocked`, only behind an explicit confirmation; the verdict is recorded on the version |
| Play / download output | `GET /projects/{video_id}/output?version=N` (only a completed version's file; downloads use this pinned URL verbatim) |
| Topic clips | `POST /projects/{video_id}/clips/suggest`, `GET` / `PATCH` clips, render one or all |
| Mistake cleanup | `POST` the cleanup plan, review removals, render the cleaned pass |
| Audience profiles | `GET /audiences` before any upload, `GET /projects/{video_id}/audiences` once a project exists |
| Publish the render | Social connect/publish/status endpoints behind the Final Output card (see `docs/SOCIAL_PUBLISHING.md`) |
| Report real engine state | `GET /health` (connection status is `unconfigured`, `checking`, `connected`, or `unreachable` from this probe - never "configured therefore connected") |

Workspace settings (export resolution and quality, remember-audience,
appearance) persist in the browser via validated `localStorage` preferences;
resetting them never deletes backend data. The remembered audience refills only
from an actual user selection, and only while that opt-in is enabled - a new
setup otherwise starts blank.

All of it goes through one typed adapter in `lib/api.ts`, so a contract change
is a change in one file rather than in every screen. Responses are validated
before the UI trusts them, and the adapter replays the backend's own
`repair_suggestions` rather than translating `recommended_action` itself, so the
UI cannot invent a different meaning for "restore this section".

### UI stack and theming

The screens are built on shadcn/ui primitives (`components/ui/`) over Tailwind
tokens defined once in `app/globals.css`. Light and dark are both driven by that
single token layer, so the theme switch in the header rethemes every screen with
no per-component conditional. The public landing page keeps its bespoke CSS but
its palette is tokenised the same way.

### What the UI will not claim

A `blocked` verdict means the backend refused to render, and the UI reports that
as a block with the backend's own reason — never as a failure to reach the
service, and never as a rendered video. An explicit override render is badged
as such, with the backend's recorded verdict, rather than presented as a clean
pass. When the analysis behind a plan came from committed fixtures rather than
a live run, the review screen says so. If ContextGuard proposes no automatic
repair for a finding, the UI says that a human decision is needed instead of
guessing at one. A fallback preview names the earlier version it came from and
never presents itself as the current plan's output.

The proposed preview seeks the source footage; it is not a verified export.
Transitions do not repeatedly re-seek rounded boundaries, and preview playback
respects pause intent. Neither behavior proves how the rendered file will play.


## Limitations and next milestones

1. **Broaden semantic evaluation and benchmark the 4-vCPU/8-GiB target.** Current small synthetic cases and developer-host timings do not establish production accuracy or performance on that floor.
2. **Re-run the live journey against a responsive Agnes** to prove the `agnes` classification path end to end (the fallback path below is proven; the provider stalled on the test night), and verify output footage matches the source.
3. Confirm all three Agnes clients against the supplied provider configuration. Add transcript chunking, bounded retries and configurable multilingual ASR.
4. Harden upload quotas, FFmpeg timeouts, authentication, cleanup policies, long-running job persistence and server deployment.

**Security:** The current backend is intended for hackathon/local development. It does not implement authenticated per-user media isolation, comprehensive size/time limits, or durable distributed worker scheduling. Do not expose it directly as a public internet service handling untrusted user files.

## Team ownership

| Role | Scope |
| --- | --- |
| **Person 1 — ContextGuard** | Independent semantic-risk verification and regression cases |
| **Person 2 — Frontend** | UI template, upload/review experience, video preview |
| **Person 3 — Source classification** | Ingestion, Whisper, source topics/claims/dependencies |
| **Person 4 — Audience editing** | Audience relevance, edit decisions, review orchestration, FFmpeg |

For changes that modify a shared schema or endpoint, update both producer and consumer tests before merging.

---

Built for **Hackerring 2.0**. The central idea is *audience-specific versions of the same original recording, with explicit source traceability and conservative meaning safeguards*.


## Locally hosted Meaning & Context Guard

`CONTEXT_GUARD_MODE=auto` selects the pipeline integration; `CONTEXTGUARD_BACKEND=local_nli` selects the native guard reviewer. The ContextGuard fast workflow does not download NLI weights or contact Agnes; the full repository suite may acquire Whisper weights for real ASR tests. See [ContextGuard setup](docs/CONTEXTGUARD.md) for standalone startup, offline weights, device settings, contracts and test scope. Entailment is not proof that meaning survived: deterministic rules and human review remain important, and unavailable inference must not produce `safe`.


### Windows launcher and local preflight

From the repository root, double-click `START.bat`. It runs the entire
startup sequence: checks Python and Node, creates the Python virtual
environment and installs both package sets on first run, creates `.env`
and `.env.local` from the examples when missing (put Agnes and
ContextGuard settings in the repository-root `.env`, the public Next.js
API URL in repository-root `.env.local`), launches the backend and the
frontend in their own windows, waits for backend `/health`, and opens
the workspace at `http://localhost:3000/app`. Re-runnable at any time;
it skips whatever is already present. `run-api.bat` and `run-web.bat`
remain for starting each server on its own. `install.bat` remains for
one-time model and media-tool downloads. Close the two server windows
to stop. First start can take a minute or two.
The backend uses `--env-file .env` and the frontend reads `.env.local`.
Both launchers pass `--loop backend.server_loop:server_loop`, which
keeps the Windows Proactor loop (required for subprocess rendering) and only
recovers transient accept aborts on Python 3.14.

To serve a verified static export offline, run `pnpm build` then `pnpm start`
(the local server reads `out/`). `pnpm dev` remains the normal development command.

The backend-provided audience list is read from `GET /projects/{id}/audiences`.
The UI sends the advertised canonical `id` on plan creation when available.
ContextGuard warnings on the output screen distinguish a rendered-but-unverified
file from blocked/unfinished rendering, and never treat an approval as a SAFE verdict.

### Landing-page acceptance checks

The public landing page is **`http://localhost:3000/`**, and its main action
opens **`http://localhost:3000/app`**. The landing page is statically rendered
and does not require FastAPI to respond. From the app's TESSERA mark, users can
return to the public landing page. The app only labels the API as *connected*
once `/health` verifies service availability, rather than assuming that a
configured base URL is a working connection.

After `pnpm build`, run `node --test tests/landing-routes.cjs` to check the
TESSERA-branded exported HTML, CTA, locally referenced assets (every
root-absolute `src`/`poster`/`href` in the markup must exist in `out/`), `/`
and `/app` over a real local HTTP server and 404 handling, plus
`node --test tests/no-demo-production.cjs` to prove the production controller
carries no sample-data, demoApi, starter versions, or mock-mode branches.
CI runs these tests after the production build.
