# Bring aztinstaller current

- **Scope & relationships:** <https://github.com/MaggieCampo/aztinstaller> (write access
  to <https://github.com/MaggieCampo/>), plus whatever in azt's own install path has to
  change to make the installer honest again. Local clone: `AZT/aztinstaller_windows_exe/`
  (renamed from `aztinstaller` 2026-09-23 — this repo is the Windows exe and nothing else).
  - **Boundary (2026-09-24 coordination pass):** WHAT gets installed, on every platform, is
    decided in azt — `azt/agenda/update_install_non-windows-specific.md` owns
    `requirements.txt` + `utilities/py_modules.py`. This item owns HOW the Windows exe
    delivers it. See "Coordination with azt" below before starting any list item.
  - Sibling of `azt/agenda/rework_install_procedure.md` (Efficiency 1d+, block1.15) —
    that item is "rework how AZT installs"; this one is "make the INSTALLER match". They
    will collide if worked separately: decide early whether the install procedure changes
    first and the installer follows, or the installer's constraints drive the procedure.
  - The D1-tail from `azt_run_with_server.md` was deferred into the install-rework item,
    so it lands here too.
- **Vision / done-criteria:** a fresh Windows machine, handed the installer, ends up with
  a working current AZT — all required repos present, dependencies installed from
  `requirements.txt`, and shortcuts where the user can actually find them. Done when
  someone who is not Kent can run it and get a working install without a phone call.
- **Deadline:** none
- **Waiting on:** Nothing

## SHALLOW CLONES — with one trap that must not be missed (2026-09-01)

Kent: *"all our cloning should be shallow clones. we don't need history for any users."*
Applied in-app that day to the three sister repos (`utilities/sister_repos.py`, `--depth 1`,
with a per-repo `depth` override). **The installer is where the source clone happens, so
this is the item that owns the rest of it** — and the azt source is the one repo where
naive shallowing breaks a feature:

- **UPDATE 2026-09-24 — the trap below is now closed IN-APP.** `Git.hard_checkout` calls
  `fetch_tracking_branch()` first (explicit `<b>:refs/remotes/origin/<b>` refspec), so a
  plain `--depth 1` single-branch clone can still "Try the testing version"; and when the
  ref truly can't be had it now fails loudly instead of inventing a branch at HEAD. So the
  exe needs only `--depth 1`. `--no-single-branch` is NOT wanted: it fetches every
  branch's tip, against Kent's "name the branches, don't widen to `*`" (2026-09-09).
  Optional, to match the Mac script: `set-branches --add` for `main` + testversionname.
  The paragraph below is kept as the history of why.
- **`--depth 1` implies `--single-branch`.** A shallow source clone therefore has no
  `origin/testing`, and `Git.hard_checkout` (`azt/backend/core/vcs.py:1116`) names
  `origin/<branch>` explicitly. Without it, it logs "No origin/testing; switching without
  resetting it" and falls back to `checkout()`, which takes its `-b` path and creates the
  branch **at HEAD** with no upstream. So "Try the testing version" reports SUCCESS (the
  caller only checks that the branch NAME matches) while running exactly the code it was
  already running. Silent and self-confirming — see
  `azt/agenda/checkout_b_from_head_not_remote.md`, which is that bug filed separately.
  → So: `git clone --depth 1 --no-single-branch`, or fetch `testing` explicitly afterwards.
  Verify on a fresh install that `git rev-parse --verify origin/testing` succeeds BEFORE
  declaring the install good; the failure mode is invisible otherwise.
- **Do NOT shallow the USB paths.** `clonetoUSB`/`clonefromUSB` in `vcs.py` are deliberately
  full clones (docstring there says why): they serve DATA repos too, where history is the
  user's own record and the merge base the collab three-way merge needs, and `clonetoUSB`
  makes a bare clone it then adds as a *remote*, so depth on a two-way sync channel is a
  footgun. An offline installer payload on a stick is a different job from a sync remote; if
  the payload should be shallow, split it out rather than adding a flag there.
- Sizes, for judging the win: `images_CAWL` is the few-hundred-MB one and is already shallow
  in-app; the azt source is small by comparison, so the installer's gain is mostly on the
  sister repos it also has to fetch (item 1 below).

## The list (start here; expected to grow)

1. **Multiple repos download — MOSTLY ALREADY DONE IN AZT; don't duplicate it.**
   `azt/utilities/sister_repos.py::ensure_all()` runs at every boot and clones
   azt-collab, images_CAWL and lift_templates (shallow since 2026-09-01) as siblings,
   with junctions on Windows. So the exe does NOT need its own clone lines for the
   sisters. What remains here is only *timing*: under the upfront-install decision (item
   2) the sister fetch should happen while the installer is still on screen, not on first
   launch. Prefer triggering azt's own `ensure_all()` over re-implementing it in NSIS, so
   the logic doesn't fork. Consequence for the install dir move (item 3): azt treats the
   PARENT of its checkout as the suite root (`sister_repos.suite_root()`) — sisters clone
   there, and `ensure_venv()` looks for `..\env` there first. So InstallDir must be
   `%LOCALAPPDATA%\Programs\AZT\azt`, NOT `...\Programs\azt` (which would put
   `env`, `lift_templates`, `images_CAWL` loose in `Programs\`). Corollary for TODAY's
   installs: with `$DESKTOP\azt`, the suite root is the Desktop itself, so the three
   sisters (images_CAWL = hundreds of MB) are being cloned loose onto the (often
   OneDrive) desktop. All three sisters are optional — azt degrades without each. Whether
   images_CAWL is opt-in is an azt decision (`rework_install_procedure.md`, "Multiple-
   repository download rethink", Q1) — follow it, don't pre-empt it.
2. **Install `requirements.txt` UPFRONT — DECIDED in azt 2026-09-23; Windows is the last
   platform not doing it.** (`update_install_non-windows-specific.md`, "every installer
   fills the venv before it says it is done"; Mac and Linux already do.) Three pieces,
   the third easy to miss: create `env/` with the installed python and check it has pip;
   `pip install -r requirements.txt` into it; write `env\azt_requirements.stamp` = sha256
   of `requirements.txt`, ONLY on a clean full install (partial ⇒ no stamp, so
   `sync_requirements()` still tries on first run). Do NOT remove azt's first-run path —
   it is the rollout mechanism for existing installs.
   - The torch index worry is RESOLVED: `requirements.txt` carries its own
     `--extra-index-url https://download.pytorch.org/whl/cpu` line (checked 2026-09-24).
   - **Venv location: `<azt>\env`** — settled by Plans E (it is what `ensure_venv()`
     itself creates; `..\env` would land loose on the Desktop for in-place updates).
   - **Entry point: settled by Plans E** — the exe runs `env\Scripts\python.exe -c "import
     utilities.py_modules"`, i.e. azt's IMPORT-TIME bootstrap (`ensure_venv` →
     `sync_requirements` → `ensure_sister_repos`). That makes those import side effects a
     cross-repo CONTRACT: an azt edit that moves them behind a `main()` or a `--install`
     switch (as `rework_install_procedure.md` proposes) silently turns the exe's install
     step into a no-op. The azt side must record this (see "Alignment check" below).
   - **Success test must compare the stamp's CONTENT, not its existence** (alignment check
     2026-09-25). `sync_requirements()` never deletes an old stamp on failure. On an
     in-place update of `$DESKTOP\azt` (Plans A) the old `env\azt_requirements.stamp` is
     already there, so "stamp exists" reports success even when the new requirements
     failed. Compare it to sha256(requirements.txt), lowercase hex, as Plans E describes.
   - Must run as the USER, not elevated — see item 7.
   - **RE-CONFIRMED FOR THE EXE, Kent 2026-09-25: BOTH, in that order.** The exe does the
     full install upfront. azt's first-run check (`ensure_venv` + `sync_requirements`)
     STAYS as a BACKSTOP, which on a fresh install should find the stamp matching and do
     nothing. It only does real work when `requirements.txt` has changed since install, or
     the upfront install was partial (no stamp written). So "keep launching main.py and let
     azt install" is not the plan, and neither is removing the first-run path.
3. **Where the PROGRAM FILES belong — probably not the desktop at all** (Kent
   2026-08-25: "perhaps putting those on the desktop was a bad idea, and using a real
   install directory would be better"). This is the big one, and it likely dissolves
   most of item 4 below. Think through:
   - **A real install directory.** `%LOCALAPPDATA%\Programs\<app>` is per-user and needs
     no elevation, which matters because azt UPDATES AND RESTARTS ITSELF (`sysrestart`,
     `ensure_venv` re-exec) — writing into `Program Files` would need admin rights on
     every update. Per-user is the modern default for exactly this reason.
   - **The desktop then holds only a SHORTCUT.** That is the real prize: a program tree
     on a OneDrive-redirected desktop means OneDrive syncing the whole checkout *and the
     venv* — hundreds of MB including torch — which is slow, wasteful, and a documented
     way to corrupt files that are being written while synced. A shortcut is a few bytes
     and syncs harmlessly.
   - NOT questions (Kent 2026-08-25): existing desktop installs — if one works, leave it
     alone, no migration needed. And the venv already goes in the install dir, which is
     correct: it would only have been a problem under `Program Files`, where a
     user-writable venv inside a read-only install dir is impossible. Per-user install
     dissolves it.
   - **DECIDED 2026-09-25 (Kent): an existing `$DESKTOP\azt` is UPDATED IN PLACE** (the
     current `gitPullAZT` path), not duplicated. The new `%LOCALAPPDATA%\Programs\AZT\azt`
     location is for fresh installs only. Detect the old dir before choosing InstallDir.
4. **Where the shortcut goes, under OneDrive.** Reduced to a small problem by item 3, but
   still real: "the Desktop" may be `%USERPROFILE%\Desktop` or
   `%USERPROFILE%\OneDrive\Desktop` depending on whether Known Folder Move is on. Ask the
   shell known-folder API rather than string-building a path, and decide what to do when:
   - the internet is down at install time;
   - OneDrive is installed but not syncing, or syncing but paused;
   - the folder is redirected AFTER install, moving the shortcut out from under us.
5. **Data in OneDrive: not the default, but a supported stopgap** (Kent 2026-08-25).
   Two sync systems on one git working tree is a way to corrupt a checkout, so data does
   NOT belong there in the normal case — but **until a team has collaboration online set
   up, OneDrive may be their only way to get data off one machine**, so it has to remain
   a deliberate, available option rather than something the installer forbids. Decide
   what the installer offers, what it defaults to, and what it warns about.
6. **Python version: pin the MINOR, resolve the PATCH** (azt decision 2026-09-24,
   `update_install_non-windows-specific.md` "The python versions"; floor/ceiling in
   `azt/docs/adr/0005-python-version-floor-and-ceiling.md`). The `.nsi` hardcodes
   `pythonversion "3.13.7"` (line ~2143). Keep the minor deliberate (3.13 is inside the
   ADR range; 3.14 is excluded today — per azt 2026-09-25 mainly by **kivy having no cp314
   wheels on any platform**, plus `torch==2.7.1` having none), but derive the latest patch from
   python.org's `ftp/python/` listing, with the pinned URL as offline fallback — same
   shape as the Mac script. NB: the azt item's research table says "Windows exe 3.12.4";
   that number is the dead `.bat`, not this exe. The exe is 3.13.x.
   - **Kent 2026-09-25: python will move again, probably to 3.14.x.** So keep the minor
     in ONE variable. But 3.14 is gated in azt, not here: ADR 0005 excludes it until the
     torch pin (`torch==2.7.1`, no cp314 wheel) moves, and `requirements.txt` must pass
     `modules_by_python_version.py --compare 3.13,3.14` first. The exe changes its minor
     only after azt says so — it must never be the first platform on a new python.
7. **Elevation: the installer runs as admin, and so does everything it launches.**
   `RequestExecutionLevel admin`; the final `ExecShell open $pythonExe main.py` inherits
   that token, so today's first run — which builds `env/` and pip-installs — probably
   runs ELEVATED. azt's rule: pip must run as the user, or the venv is owned wrongly and
   the app can't update it later. The same applies to `git clone`: an admin-owned
   checkout later trips git's "dubious ownership" (`safe.directory`) refusal when the
   user's azt tries to update itself — partly mitigated: every `Git()` init runs
   `mark_safe()` (`vcs.py:1020`, `config --global --add safe.directory`) as whoever runs
   azt. UNVERIFIED — check ownership of `env/` and `.git` on a machine installed by the
   current exe. Also: under over-the-shoulder UAC (a standard user elevating with a
   DIFFERENT admin account), `$DESKTOP`/`$LOCALAPPDATA` resolve to the ADMIN's profile, so
   the clone lands where the user never sees it. azt itself needs no admin after install
   (no elevation calls anywhere in azt; paths derive from `__file__`; self-update is
   `git pull` in the install dir). Fix shape: **superseded by Plans H, "Elevation shape —
   DECIDED 2026-09-25: atomic"** (user-level installer, one elevated child for the
   machine-wide steps). The `runas /trustlevel` stopgap is no longer the plan.
8. **Shallow clone of the source is still NOT done here** (line ~735 is a plain
   `git clone`). Plain `--depth 1` suffices now (see the UPDATE in SHALLOW CLONES above);
   `set-branches --add origin main` + `<testversionname>` then `git fetch --depth 1` is
   optional belt-and-braces, as in the Mac script (re-add the cloned branch —
   `set-branches` replaces; read `testversionname` from `main.py`). The existing-dir path (`gitPullAZT`, `git pull origin`) must use
   `--depth 1` too or it starts deepening. `rework_install_procedure.md` lists "the
   Windows installer's git clone lines" in its own scope — that half is THIS item's.
9. **Charis download is broken as written — likely never installs v7.** The `.nsi` builds
   `CharisSIL-7.000.zip`; the real v7 file is `Charis-7.000.zip`, and the server is
   case/name-exact (verified by hand 2026-09-09, `rework_install_procedure.md`). v7 also
   renamed the family "Charis SIL" → "Charis", so the `StrRep "CharisSIL-"` face-name
   logic and the `"Charis SIL $FACEMOD (TrueType)"` registry names need redoing. The
   `.nsi`'s own comment already proposes the fix azt adopted for the Mac: ask
   `api.github.com/repos/silnrsi/font-charis/releases/latest` for the `.zip` asset, keep
   one pinned URL as fallback. The app accepts either family name.
10. **The Transcriber shortcut points at a file that doesn't exist.**
    `transcriberfilename = $INSTDIR\transcriber.py`; the module is
    `frontend/transcriber.py`. ~~Not runnable standalone; drop the shortcut~~ — **WRONG,
    corrected by Kent 2026-09-25:** `python -m frontend.transcriber` works. So keep the
    shortcut and retarget it (Plans D). `azt/agenda/transcriber_standalone.md` may
    therefore be stale too.
11. **Webview: install NOTHING for it** (azt decision 2026-09-24:
    `requirements-webview.txt` is not an install target on any platform; the app
    installs the right subset when `--webview` is asked for). Likewise no WebView2
    bootstrapper at install time — azt's `webview2_problem()` handles its absence at
    runtime.
12. **Antivirus exclusions** (Kent 2026-07-30, recorded in `rework_install_procedure.md`
    Notes): the installer is where they'd be set or explained. Which paths/products is
    unsettled.
13. **(?) Are XLingPaper, Praat and Mercurial still wanted as optional components?**
    Not checked against current azt use; decide before carrying them into the rework.
14. *(to add)*

## Coordination with azt (2026-09-24)

Asked: does anything on this list overlap work already going on in azt? Answer, per item:

| Here | In azt | Status | Who does what |
|---|---|---|---|
| 1 multi-repo | `sister_repos.ensure_all()` | built | azt clones; exe only triggers it at install time |
| 2 requirements | `update_install_non-windows-specific.md` | decided, Mac+Linux done; exe PR1 drafted | exe calls azt's import-time bootstrap (Plans E) — a contract azt must keep |
| 6 python ver | ADR 0005 + same item | **CONFLICT — see Alignment check** | azt names the minor; exe resolves the patch |
| 8 shallow | `rework_install_procedure.md`, `azt/CLAUDE.md` | decided, exe not done | exe |
| 9 Charis | Mac script's GitHub-API route | built for Mac | exe ports it |
| 10 Transcriber | `transcriber_standalone.md` | runs as `-m frontend.transcriber` (Kent) | exe retargets shortcut (Plans D) |
| 11 webview | `webview_requested_but_absent.md` | done | nothing for exe |
| — | `py_modules` POSIX `os.execv` relaunch fix | open in azt | **does not touch the exe**; its Windows side is untouched deliberately |

**Anything that changes `requirements.txt` or `py_modules.py` IS a change to the Windows
install path** (the exe defers to them). That work is azt's, gated on the Windows
non-regression checklist in `update_install_non-windows-specific.md` plan 6.

**Batch the Windows-machine trips.** Testing a new exe needs a fresh Windows box; so do
azt's plan-6 non-regression checklist, `windows_webview2_verification.md` and
`cross_platform_checks.md`. One trip, one checklist. Also add from here: `origin/testing`
resolves after install (shallow trap), `env/` and `.git` owned by the user (item 7), and
the Charis family actually registered (item 9).

**Sequencing recommendation:** items 3 (install dir) and 2 (venv location) must be decided
together with azt, because `ensure_venv()`'s sister-`../env` lookup and `sister_repos`'
sibling layout already assume a suite root. Decide the layout first; the rest of this list
is exe-only work that can then proceed without touching azt.

### Alignment check 2026-09-25 (both repos' agenda re-read against each other)

**1. CONFLICT: python minor after 2026-10-01.** The exe's PR2 rule (Research, "bump the
MINOR, don't walk back"; "no python version ceiling") moves to 3.14 as soon as
`downloads/latest/python3.13/` stops linking an exe. That happens when 3.13 goes
security-only on 2026-10-01. azt says on the same day that 3.14 is **unavailable**, because
kivy has no cp314 wheels (and torch 2.7.1 has none either), and names 3.13.15 as the target.
So once that lands, every fresh install would get 3.14, and its upfront `pip -r` would
fail. The two readings fit only if "no ceiling" means *no ceiling by policy*, while
what actually installs still sets a limit in practice. Proposed reconciliation for Kent: the exe does not choose
the minor by itself. It takes the minor azt names (a single value, ideally read from azt, e.g. a
raw file in the azt repo, with the `.nsi` variable as fallback). When the minor has no
newer installer, it falls back to the newest patch of THAT minor that has one (the FTP
walk). It does not bump to the next minor.

**2. UNVERIFIED FACT, stated two ways.** azt: *"no installer less than 3.13.15"*, and
"python.org withdraws installers for versions no longer in bugfix maintenance". The exe's
research: 3.12.10's `-amd64.exe` is still on FTP although 3.12 is security-only. Both
can't be true. One hand check settles it:
`https://www.python.org/ftp/python/3.13.7/python-3.13.7-amd64.exe`. If it downloads, the
"current outage" in the azt item is wrong, and the FTP walk-back in point 1 is safe.

**3. azt-side lines that are now stale** (NOT edited from here; for whoever works azt):
- `update_install_non-windows-specific.md`: "Windows still defers, by way of the exe
  running `main.py`". The exe PR1 is drafted to install upfront (untested).
- Same file, plan 6 and "CORRECTION 2026-09-23": "the exe clones this repo and runs
  `main.py`". Now the exe imports `utilities.py_modules` as its installer. So
  `py_modules`' **import-time side effects are a contract with the exe**, and that belongs
  on the Windows non-regression checklist. `rework_install_procedure.md`'s proposed
  `python -m utilities.py_modules --install` must keep the import path working, or
  coordinate a switch of the exe to it.
- Same file, "Windows caveat": calls the `runas /trustlevel` `.bat` "current". The exe
  has decided the atomic shape instead (Plans H). The principle (pip as the user) still holds.
- Same file, "a python move is ... administrator rights on Windows". Not true once the
  exe installs python per-user (`InstallAllUsers=0`, Plans H).
- `transcriber_standalone.md`: may be stale given `-m frontend.transcriber` works.

**Aligned, no action:** shallow clones (plain `--depth 1`), sister repos (azt's),
webview (nothing), venv at `<azt>\env`, first-run check kept as backstop, Charis via
GitHub API, `safe.directory` (azt's `mark_safe()`).

## Research 2026-08-25 — desktop vs `%LOCALAPPDATA%\Programs` for the program repos

Asked: pros and cons of each as the place the installer clones into. **The evidence is
one-sided; the only real arguments for the desktop are discoverability and inertia, and
both are answered by a shortcut.**

### Against the desktop, specifically because of OneDrive

1. **Git repos in a OneDrive-synced folder are a documented corruption path.** Not
   theory: Git for Windows itself warns "Concurrent access to OneDrive synced folders
   might corrupt repositories" when you clone into one. Field reports include a `.git`
   folder becoming invalid for Git *after OneDrive finished syncing*, and OneDrive
   hanging on "Looking for changes" until the repo was moved out. The mechanism is two
   writers on one tree: Git rewrites packs/refs/index while the sync client is reading
   and replacing the same files.
2. **Known Folder Move puts the Desktop in scope automatically.** This is not a user
   choosing to clone into OneDrive — KFM redirects Desktop/Documents/Pictures wholesale,
   often by org policy, so an installer that targets "the Desktop" lands inside OneDrive
   *without anyone deciding to*. That is exactly our situation.
3. **Files On-Demand will dehydrate the venv.** OneDrive frees space by evicting files
   that haven't been touched recently. Applied to a venv (or any thousands-of-small-files
   tree) that means re-downloading them on next use — and an app that self-restarts into
   its venv is the worst case for it.
4. **Path length.** Windows' everyday limit is still 260 characters, and a redirected
   desktop starts from something like `C:\Users\<user>\OneDrive - <Org Name>\Desktop\`
   before our own nesting begins. Python venvs nest deeply
   (`Lib\site-packages\<pkg>\...`), and torch is exactly the kind of package that goes
   deep. OneDrive adds its own ceilings on top (400-char relative path, 520 total).
   The org name being *in the path* means the budget differs per customer.
5. **Sync cost.** The program tree is hundreds of MB (torch alone). Uploading and
   re-downloading that across a field connection is pure waste — nothing in it is user
   data, and it is all reconstructible from git + pip.

### For `%LOCALAPPDATA%\Programs\<app>`

1. **It is the Windows convention for per-user installs, and needs no elevation.**
   VS Code's "User Setup" installs exactly there for exactly this reason. Our need is
   sharper than VS Code's: azt **updates and restarts itself**, so an install root the
   user can't write to would demand admin on every update.
2. **`AppData` is not a known folder OneDrive redirects.** KFM covers Desktop, Documents,
   Pictures — not `AppData`. So the program tree is out of sync scope *by construction*,
   not by asking the user to opt out.
3. Shorter path, no org name in it, so the 260-char budget is spent on our own nesting.

### Costs of moving, and what pays them

- **Discoverability.** A folder on the desktop is findable; `%LOCALAPPDATA%` is hidden by
  default. Answered by the desktop shortcut — which is what most users actually used the
  desktop folder for.
- **"Where did my program go?"** for anyone used to opening the folder. Worth a line in
  the installer's final screen naming the path.
- **Uninstall/reinstall by dragging the folder to the bin** stops being obvious. Probably
  a feature, given how it interacts with self-update.

### Recommendation

Clone the program repos into `%LOCALAPPDATA%\Programs\<app>`; put a shortcut on the
desktop (resolved via the shell known-folder API, per item 4). This also means item 5's
data question is genuinely separate: data can be wherever the team needs, including
OneDrive as a deliberate stopgap, without dragging the program tree in with it.

Sources: [Git/OneDrive corruption reports](https://techcommunity.microsoft.com/discussions/onedriveforbusiness/onedrive-is-corrupting-my-git-repositories/3898283) ·
[OneDrive and git — don't do it](https://dustinbriles.com/onedrive-and-git-dont-do-it/) ·
[MATLAB Answers: projects, Git and OneDrive corruption](https://www.mathworks.com/matlabcentral/answers/2056649-projects-git-and-onedrive-repository-corruption) ·
[Redirect known folders to OneDrive (KFM)](https://learn.microsoft.com/en-us/sharepoint/redirect-known-folders) ·
[OneDrive file path length limits](https://support.microsoft.com/en-us/onedrive/what-are-file-path-length-limits) ·
[VS Code Windows setup (User vs System)](https://code.visualstudio.com/docs/setup/windows) ·
[AppData / LocalAppData / ProgramData](https://www.advancedinstaller.com/appdata-localappdata-programdata.html)
  
## Plans

2026-09-25 — minimal-diff plan for `AZT_Installer_UI.nsi` (upstream PR; no style edits):

- A. (list 3) `InstallDir` → `$LOCALAPPDATA\Programs\AZT\azt` for fresh installs; if
  `$DESKTOP\azt` exists, keep it as INSTDIR and update in place (DECIDED 2026-09-25).
- B. (list 8) Clone `--depth 1` (plain; NOT `--no-single-branch`); `gitPullAZT` pull `--depth 1`.
- C. A-Z+T shortcut: target is hard-coded `$DESKTOP\azt\main.py` → use `$aztfilename`.
- D. (list 10) Transcriber shortcut: NOT dropped. Kent 2026-09-25: `python -m
  frontend.transcriber` works — list 10's "not runnable standalone" is WRONG (came via
  the azt agent; `transcriber_standalone.md` may be stale too). Shortcut now targets
  `env\Scripts\python.exe` (base python if no venv), args `-m frontend.transcriber`,
  start-in = clone.
- E. (list 2) Requirements UPFRONT in the exe — DECIDED (re-confirmed 2026-09-25).
  Implemented as: `<azt>\env` (where azt's `ensure_venv()` itself creates it; `..\env`
  would land loose on the Desktop for in-place updates), then
  `env\Scripts\python.exe -c "import utilities.py_modules"` with cwd = clone — azt's own
  headless bootstrap (requirements sync + sister clones + import backstop), which writes
  its own stamp. Success = stamp exists (exit code is NOT a signal). Known gap: pip
  output is captured, so several silent minutes. Stamp format (if ever self-written):
  sha256 of raw file bytes, lowercase hex, no newline, at env root.
- PR1 DRAFTED 2026-09-25 in the working tree (NOT compiled, NOT tested on Windows).
  Known limits for the PR description: newly installed Git isn't on the parent's PATH
  for the bootstrap's sister clones (optional; azt retries at start); `/S` silent runs
  skip the components page, so the elevated copy wouldn't get optional selections;
  HKLM old-python-path removal in the Python section now fails (logged) as the user
  (removed entirely in PR2).
- PR2 DRAFTED 2026-09-25 on top of PR1 (NOT compiled, NOT tested). **No bump for now**
  (Kent 2026-09-25, resolving Alignment check #1): `!define PYTHONMINORS 1`; set >1 once
  azt's requirements install on 3.14. Alignment #2 settled: Kent confirmed 3.12.10's
  installer is still on FTP → walk-back is safe. Shape: `findPythonMinor` (PEP 514
  registry, HKCU then HKLM, 64-bit view) → skip install if present; else
  `resolvePythonVersion` (latest page → walk back with `inetc::head` → installer beside
  the exe) → install → `findPythonMinor` again (old `getPythonPath` kept as fallback).
  Old "≥ desired + remove other pythons from PATH" block deleted. Test: minor 3.12 must
  resolve to 3.12.10.
- F. Shortcut: keep current file-association launch (Kent 2026-09-25: no), but leave a
  comment with the `pythonw.exe main.py` form — expected to go there eventually.
- G. (list 7) De-elevate venv/pip/first launch — YES (Kent 2026-09-25).
- H. (list 7) Kent's intent (2026-09-25): elevation only where needed, atomically; users
  run and use all of azt unelevated. Clarified: azt already runs unelevated after install
  (shortcut launch). The open part is install-time identity — see "Elevation shape" below.
- I. THREE PRs (Kent 2026-09-25):
  - PR1: A–F + atomic elevation (H, DECIDED below; supersedes G's runas-trustlevel).
  - PR2: list 6, python patch resolve — see Research "Latest python patch".
  - PR3: list 9, Charis v7 via GitHub releases API.
- Not doing: sister-repo clones (azt's `ensure_all()`), safe.directory (azt's `mark_safe()`;
  existing installer lines left alone), webview (list 11).

### Elevation shape (H) — DECIDED 2026-09-25: atomic, in PR1

Kent: "things going into the wrong users' settings has bit us hard in the past. if we can
just do this right, I'd rather." Resolution of the unknowns below:

- Per-user Git and per-user fonts are NOT needed. Wrong-user harm is only to per-user state
  (profile paths, HKCU, user-owned clone/`env\`). Machine-wide installs (Git in Program
  Files, fonts in `$FONTS` + HKLM, LongPaths, Praat) are correct whoever the admin is.
  Keep them machine-wide, done by an elevated child. (Per-user fonts also risk
  XeTeX/XLingPaper not seeing them — avoided.) MinGit zip = no-admin git, if ever wanted.
- User-level installer (`RequestExecutionLevel user`): clone, venv, pip, shortcuts, first
  launch, Python (`InstallAllUsers=0`).
- Launching elevated: `ExecWait` on an admin installer fails (740, elevation required).
  Use `ExecShellWait "runas"` — needs NSIS ≥ 3.02; **last build used NSIS 3.10** (Kent).
- One UAC prompt, not four: installer re-launches ITSELF elevated with a switch (e.g.
  `/ADMINSTEPS`) that runs only the machine-wide sections (Git, fonts, LongPaths, Praat,
  HKLM PATH cleanup), then returns.
- Over-the-shoulder: admin credentials only reach machine-wide steps → correct by construction.
- `.onInit`'s "must be run as Administrator" abort goes (or moves into the /ADMINSTEPS path).

### Elevation shape — original options (kept for the record)

NSIS elevation is per-PROCESS: `RequestExecutionLevel admin` makes every step admin, and
`$LOCALAPPDATA`/`$DESKTOP` are the elevated account's. Two shapes:

- **G only (stopgap):** stay admin, de-elevate user steps with `runas /trustlevel:0x20000`.
  Works when the user IS the admin (usual field case). Fails over-the-shoulder:
  trustlevel drops privileges but keeps the ADMIN's identity/profile.
- **Atomic (Kent's stated intent):** `RequestExecutionLevel user`; the installer runs as the
  user (clone, venv, pip, shortcuts, launch — all correct profile by construction) and
  elevates only the steps that need it, each as its own `ExecShell "runas"` child:
  - Python: needs none if per-user (`InstallAllUsers=0`) — current code already
    parameterises this via `$withadmin`.
  - Git for Windows: all-users installer needs admin; per-user (`/CURRENTUSER`) UNVERIFIED.
  - Charis fonts: per-user font install (HKCU + `%LOCALAPPDATA%\Microsoft\Windows\Fonts`,
    Win10 1809+) needs none — UNVERIFIED that azt/XLingPaper see per-user fonts.
  - LongPathsEnabled (HKLM): needs admin — one elevated `reg add` child.
  - Praat into Program Files + HKLM PATH: needs admin (or move to per-user).
  - XLingPaper / Mercurial: their own installers self-elevate.
  Bigger diff than G, and it touches the admin check in `.onInit` — a reviewer-visible
  structural change, so it should be argued in the PR description.

## Notes

- Filed 2026-08-25 from Kent, at second position in the Function block.
- Write access is to the MaggieCampo org, not to Kent's own account — check the auth path
  before assuming a push works.

## Research

### 2026-09-25 — azt-side answers (from a separate agent reading `azt/`)

- R1 Repos: azt runs without extras; `utilities/sister_repos.py` clones azt-collab,
  images_CAWL, lift_templates (shallow) into the checkout's PARENT every startup, and
  junctions the last two into azt. All optional → installer skips them. Consequence: the
  parent must be a suite folder, hence `...\Programs\AZT\azt`; today's desktop installs
  scatter these three loose on the (often OneDrive) desktop.
- R2 Deps: `ensure_venv()` uses `..\env` else `<azt>\env`, re-execs in it; `sync_requirements()`
  runs `pip install -f modulestoinstall -r requirements.txt` (offline then online); torch
  `--extra-index-url` is inside requirements.txt. Stamp: `env\azt_requirements.stamp`.
- R3 Launch: `transcriber.py` gone from root. Shortcut: venv `env\Scripts\pythonw.exe main.py`
  if venv exists, else base `pythonw.exe main.py` (re-exec keeps pythonw); start-in = azt dir.
- R4 Testing: still offered; `hard_checkout` now fetches `origin/testing` itself and reports
  failure. So plain `--depth 1` is correct; Kent ruled out fetching all branches.
- R5 Paths: nothing hard-codes Desktop; `mark_safe()` in vcs.py sets safe.directory at runtime.
- R6 Admin: azt needs none after install. Risks: first launch inherits elevation (venv/pip/
  clones as admin); over-the-shoulder admin → wrong profile for `$LOCALAPPDATA`/`$DESKTOP`.

### 2026-09-25 — Latest python patch (for PR2): yes, enough to build it

Checked live 2026-09-25:

- **PREFERRED (Kent's pointer): `https://www.python.org/downloads/latest/python<minor>/`**
  resolves to the latest release page for that minor (today: `python3.13/` → 3.13.15,
  `python3.14/` → 3.14.7). The page carries the verbatim link
  `https://www.python.org/ftp/python/<v>/python-<v>-amd64.exe` — so `inetc::get` the page,
  `${StrStr}` for `-amd64.exe`, back up to `/ftp/python/`, and that is the URL + version in
  one step, with the installer's existence implied by the link. If the latest release is
  security-only (no exe link on the page — 3.13 from 2026-10-01), do the FTP walk below.
- **NO patch pin (Kent 2026-09-25):** a pin is one more stale item, and anything it names
  is ≤ what the walk finds. Direction is *upgrading*, not pinning. Only the MINOR is
  named (one variable, per list 6). Security-only releases ship NO Windows exe; the walk
  lands on the minor's newest release that has one (for 3.13: its last bugfix release).
- **Offline:** no network ⇒ no lookup; the existing "installer file already beside the
  exe" check must then match `python-<minor>.*-amd64.exe` by wildcard, since no exact
  filename is known in advance.
- Kent to confirm by hand: `https://www.python.org/ftp/python/3.13.15/python-3.13.15-amd64.exe`
  (what `downloads/latest/python3.13/` links today); after 2026-10-01, that a 3.13.16 dir
  (if any) has no `-amd64.exe` and 3.13.15's still does.
- **Live test case: 3.12 (security-only since 2025).** `downloads/latest/python3.12/` →
  3.12.14, no `-amd64.exe` link; page text: "Python 3.12.10 was the last full bugfix
  release of Python 3.12 with binary installers." FTP has 3.12.0–3.12.14; the walk must
  step 14→13→12→11 (source-only) and land on
  `https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe`. Use as the PR2 test.
- **Kent 2026-09-25: bump the MINOR, don't walk back.** No exe on `latest/python<minor>/`
  ⇒ that minor is security-only ⇒ newer maintained minors exist ⇒ try `<minor+1>`
  rather than walking back to the last maintenance release. Kent 2026-09-25: **there is
  no python version ceiling** in azt. (Conflicts with list 6's "ADR 0005 floor/ceiling"
  wording — reconcile with azt.) The only practical limit is whether `requirements.txt`
  installs on the new minor (e.g. a torch pin without wheels for it) — that's azt's to
  keep current, not the exe's to guard.
- **RISK: a client with a NEWER python than the target (2026-09-25).** Real, not theoretical:
  - `checkVersion` treats installed ≥ desired as "OK, skip install" (exit 0). A machine
    with 3.14 on PATH (python.org's default download today; also the Store / Install
    Manager defaults to newest) skips the 3.13 install entirely.
  - The venv is then built by whatever `python` is — 3.14 — and `pip -r` fails on
    `torch==2.7.1` (no cp314 wheel).
  - The `.py` file-association launch goes through the `py` launcher, which picks the
    NEWEST installed python unless told otherwise.
  - Fix shape: "installed" means the target MINOR is present (minors coexist side by side),
    not "anything ≥"; build the venv explicitly (`py -3.13 -m venv`); once the venv exists,
    azt's `ensure_venv()` re-execs into it regardless of launcher.
  - With no ceiling, this risk reduces to: does `requirements.txt` install on the
    client's newer minor? If yes, a newer python is fine; if no, it's an azt
    requirements bug, surfaced by the exe's upfront pip (list 2) at install time.
  - TODAY it is "no" for 3.14: `torch==2.7.1` has no cp314 wheel (checked earlier; Kent
    2026-09-25). So the risk is live now, until azt moves the torch pin.
- **FTP walk (second step): `https://www.python.org/ftp/python/`** directory listing.
  Entries are `<a href="3.13.15/">3.13.15/</a>`; today 3.13.0–3.13.15, 3.14.0–3.14.7.
  NSIS: `inetc::get` the listing to a file, scan for `href="$minor.` and keep the highest
  patch (numeric compare — `3.13.9` < `3.13.15`, so string sort is wrong; `VersionCompare`
  from WordFunc.nsh, already included, handles it).
- **A directory is NOT proof of an installer.** Before using a patch, probe
  `.../ftp/python/<v>/python-<v>-amd64.exe` (`inetc::head`); walk down until one exists.
  This matters soon: 3.13 goes security-only 2026-10-01 (endoflife.date), and security-only
  releases ship SOURCE ONLY — so 3.13.16+ dirs will exist without a Windows `.exe`.
  Confirmed present today: `python-3.13.15-amd64.exe`, `python-3.14.7-amd64.exe`.
- **Fallback:** keep the pinned `$pythonversion` + URL for offline / failed lookup.
- Also seen: `windows-<v>.json` in each patch dir (Windows metadata); not needed.
- Not recommended as the source:
  - `endoflife.date/api/python/3.13.json` → `{"latest":"3.13.15",...}` — trivially parsed,
    but third-party, and "latest" can name a source-only release.
  - `python.org/api/v2/downloads/release/` — unsorted, large, needs JSON parsing in NSIS.
  - `.../api/v2/downloads/release_file/` — every file of every release (500+), keyed by
    release id, no version string; needs `release/` lookup first + `?release=<id>`.
    Its one win: `sha256_sum` per file → possible LATER hardening (verify the downloaded
    python installer), not a reason to use it for version discovery.
- Note for later minors: the classic `.exe` installer is being superseded by the Python
  Install Manager; still shipped for 3.14 (verified). Re-check when azt moves past 3.14.
