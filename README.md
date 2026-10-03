# Android RBE on BuildBuddy

Offload the heavy parts of an AOSP / LineageOS build — C/C++ compiles, `R8`,
linking, and the like — to **BuildBuddy's remote execution cluster**, so your
machine stops pegging all its cores and the build finishes much sooner.

This repo contains a single installer (`install_rbe.sh`) that drops a patched
**reclient** into `/opt/reclient` and writes a machine-wide RBE environment file
to `/etc/profile.d/rbe_env.sh`. Every new shell — and therefore every `m` / `mka`
build — picks it up automatically. No per-tree changes required.

> **No API key is included.** You must supply your own BuildBuddy key (see
> [step 2](#2-add-your-api-key)). The installer ships with it blank on purpose.

---

## Why this exists

AOSP's build system ships RBE support out of the box (`USE_RBE=1`), but wiring it
to a third-party backend like BuildBuddy is fiddly:

- reclient needs to be installed system-wide and on `PATH` via its env file.
- BuildBuddy authenticates with a custom header, not Google RPC credentials.
- Most tools need a `remote_local_fallback` strategy so a remote hiccup degrades
  to a local compile instead of breaking the build.

This installer handles all three in one shot, then leaves a config you can tune
with plain environment variables.

---

## What's in here

```
rbe/
├── README.md          # you are here
├── install_rbe.sh     # the installer (API key left blank)
└── .gitignore         # keeps the (large) client binaries out of git
```

The `rbe-client/` folder with the actual reclient binaries is **not** committed
(it is ~350 MB). See [step 1](#1-get-the-reclient-binaries).

---

## How it works

reclient is a three-part machine:

| Binary | Role |
|---|---|
| `bootstrap` | Starts the long-lived proxy with the right flags |
| `reproxy` | Local gRPC proxy; talks to the remote backend, owns the caches |
| `rewrapper` | Wraps each compile/link command and asks `reproxy` to run it remotely |

AOSP's build system exports `RBE_<flag>` environment variables, and reclient's
`bootstrap` translates every one of them into `--<flag>` for `reproxy` /
`rewrapper`. That is why the entire configuration in
`/etc/profile.d/rbe_env.sh` is just a list of `export RBE_...=...` lines — there
is no separate config file to edit.

Authentication to BuildBuddy is done with the `x-buildbuddy-api-key` header, which
is attached to every RPC through `RBE_remote_headers`. Because of that we also
turn off reclient's own credential machinery:

```sh
export RBE_use_rpc_credentials=false
export RBE_service_no_auth=true
export RBE_remote_headers="x-buildbuddy-api-key=<YOUR_KEY>"
```

---

## Requirements

- Ubuntu 22.04 / 24.04 (or a close derivative)
- `sudo` privileges (installs to `/opt/reclient` and `/etc/profile.d/`)
- A BuildBuddy account with **Remote Execution** enabled on your org
- The reclient binaries for `linux-amd64` (see below)
- An AOSP / LineageOS tree you already know how to build (`m` / `mka`)

---

## 1. Get the reclient binaries

You need a `linux-amd64` reclient build containing at least `reproxy`,
`rewrapper`, and `bootstrap`. The reference build for this setup is reclient
**`0.185.0.db415f21`** (the `gomaip` / `buildbuddyfix` flavour).

Clone this repo, then place the binaries in a `rbe-client/` folder next to the
installer:

```bash
git clone https://github.com/MufasaXz/rbe.git
cd rbe

# Put the reclient binaries here so that ./rbe-client/ exists:
#   rbe-client/reproxy
#   rbe-client/rewrapper
#   rbe-client/bootstrap
#   rbe-client/remotetool
#   ... (the rest of the linux-amd64 client)
```

You can obtain the client from either of these:

- **An existing repo that already carries `rbe-client/`** — e.g. the upstream
  tutorial repositories (`Sanjis-Android-Playground/rbe`,
  `Rares6567/new_rbe_fix`). Copy their `rbe-client/` folder in.
- **A Chromium CIPD package** (`infra/rbe/client/linux-amd64`) fetched with the
  `cipd` tool, then unpacked into `rbe-client/`.

The installer refuses to run until `./rbe-client/` exists.

---

## 2. Add your API key

Open `install_rbe.sh` and fill in the two blanks near the top of the generated
env block:

```sh
export RBE_service="remote.buildbuddy.io:443"
export BUILDBUDDY_API_KEY=""                        # <-- your key
export RBE_remote_headers="x-buildbuddy-api-key="   # <-- your key again
```

Get the key from your BuildBuddy **Quickstart** page (log in at
<https://app.buildbuddy.io/>, then open *Quickstart*). It is the value after
`--remote_header=x-buildbuddy-api-key=`.

For a personal subdomain instance (`https://<you>.buildbuddy.io`), change
`RBE_service` to `<you>.buildbuddy.io:443`.

> If you would rather not edit the script, you can leave it blank and export the
> three variables yourself before running it — the installer's heredoc will
> overwrite them, so editing the script is the reliable path.

---

## 3. Run the installer

```bash
chmod +x install_rbe.sh
./install_rbe.sh
```

It will:

1. copy `rbe-client/*` into `/opt/reclient/`,
2. write `/etc/profile.d/rbe_env.sh`,
3. load that env file into the current shell (and every new one).

Open a new shell (or run `source /etc/profile.d/rbe_env.sh`) and check:

```bash
echo "$USE_RBE"              # 1
/opt/reclient/reproxy --version
```

Then build as usual — `m`, `mka`, `lunch`/`m` — and RBE is used automatically.

---

## 4. Verify

You do not need to run a full build to confirm RBE works. The bundled
`remotetool` can talk to the backend directly.

**Remote cache (upload):**

```bash
mkdir -p /tmp/rbe_updir/sub && echo hi > /tmp/rbe_updir/sub/f.txt
/opt/reclient/remotetool \
  --service=remote.buildbuddy.io:443 \
  --service_no_auth=true \
  --remote_headers="x-buildbuddy-api-key=<YOUR_KEY>" \
  --operation=upload_dir --path=/tmp/rbe_updir --logtostderr
```

**Remote execution:**

```bash
rm -rf /tmp/rbe_action && mkdir -p /tmp/rbe_action/input
printf 'arguments: "/bin/echo"\narguments: "hello-rbe"\n' > /tmp/rbe_action/cmd.textproto
printf '# action\n' > /tmp/rbe_action/ac.textproto

/opt/reclient/remotetool \
  --service=remote.buildbuddy.io:443 \
  --service_no_auth=true \
  --remote_headers="x-buildbuddy-api-key=<YOUR_KEY>" \
  --operation=execute_action --action_root=/tmp/rbe_action --path=/tmp/rbe_out \
  --logtostderr
```

A working setup prints `hello-rbe` and ends with `ExitCode:0 Status:Success`.

---

## Configuration reference

All of this lives in `/etc/profile.d/rbe_env.sh`.

| Variable | Purpose |
|---|---|
| `USE_RBE` | Master switch for AOSP's RBE support |
| `RBE_service` | Backend `host:port` (execution **and** cache) |
| `RBE_remote_headers` | Extra headers, e.g. the BuildBuddy API key |
| `RBE_use_rpc_credentials` | `false` — we use a header, not RPC creds |
| `RBE_service_no_auth` | `true` — skip reclient's own auth |
| `NINJA_REMOTE_NUM_JOBS` | Remote job ceiling (2000 here) |
| `RBE_<TOOL>_EXEC_STRATEGY` | `remote`, `local`, or `remote_local_fallback` |
| `RBE_remote_download_mode` | `minimal` downloads only needed outputs |

`remote_local_fallback` is the safe default: if a remote action fails, it is
re-run locally, so the worst case is a slower build — not a broken one.

---

## Tuning (optional)

Speed knobs that help on large trees:

```sh
# Deduplicating, batched transfers -> fewer round-trips.
export RBE_use_unified_downloads=true
export RBE_use_unified_uploads=true

# Dependency-scan cache: skip re-scanning unchanged files on incremental builds.
export RBE_enable_deps_cache=true
export RBE_deps_cache_max_mb=4096

# More parallel CAS transfer RPCs (default 500).
export RBE_cas_concurrency=1000
```

---

## Troubleshooting

**`Unauthenticated ... Unable to authenticate with RBE`**
Your API key is missing or wrong. Confirm `BUILDBUDDY_API_KEY` and
`RBE_remote_headers` both contain the key, then `source /etc/profile.d/rbe_env.sh`.

**Distinguishing a bad key from a backend problem.** Send the key by hand with
`grpcurl` (or `remotetool`) and read the error:

- `Unauthenticated: Invalid API key "x***z"` → the key is wrong/revoked.
- `Unavailable: there was an issue with your request - please contact support` →
  BuildBuddy *recognises* the key but rejects the request. That is an
  account/org-side issue (plan, RBE enablement, quota, IP rules) — no local
  change fixes it; contact BuildBuddy support.

**Builds still fail after RBE starts.** Check `out/error.log` and the per-build
reproxy log under `out/soong/rbe/`. If reproxy cannot start at all, every
`rewrapper` action dies before `remote_local_fallback` can help. Temporarily
disable RBE to keep building:

```sh
export USE_RBE=0     # or NOSTART_RBE=1 for a single build
```

---

## Security notes

- **Never commit your API key.** This repo deliberately ships it blank. Anyone
  with the key can run work against your BuildBuddy org.
- Keep secret-signing steps local. `SIGNAPK` is pinned to `local` here so release
  signing keys are never uploaded to a third-party CAS.
- The remote CAS is a third party — treat anything you send as leaving your
  machine.

---

## Credits

- reclient: <https://github.com/bazelbuild/reclient>
- BuildBuddy: <https://www.buildbuddy.io/>
- Upstream AOSP RBE tutorials that inspired this setup
  (`Sanjis-Android-Playground/rbe`, `Rares6567/new_rbe_fix`).
