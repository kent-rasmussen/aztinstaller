# Bring aztinstaller current

- **Scope & relationships:** <https://github.com/MaggieCampo/aztinstaller> (write access
  to <https://github.com/MaggieCampo/>), plus whatever in azt's own install path has to
  change to make the installer honest again. Local clone: `AZT/aztinstaller/`.
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

1. **Multiple repos download.** AZT is no longer one clone — the suite spans azt,
   azt-collab (the client is located at runtime via `_ensure_client_importable`), and the
   shared image set. The installer needs to fetch the right set, at the right versions,
   into the right relative layout.
2. **Installation from `requirements.txt`.** Rather than whatever pinned/handmade list
   the installer carries now. Watch the CPU-only torch index URL — `torch==2.7.1+cpu`
   needs `--extra-index-url`, which a naive `pip install -r` won't supply.
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
6. *(to add)*

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

Not started. First action is to inventory what the installer does today, against what a
current install actually needs — the list above is the starting point, not the survey.

## Notes

- Filed 2026-08-25 from Kent, at second position in the Function block.
- Write access is to the MaggieCampo org, not to Kent's own account — check the auth path
  before assuming a push works.

## Research
