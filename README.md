# Android RBE on BuildBuddy

Remote build execution (RBE) for AOSP / LineageOS trees using BuildBuddy and
reclient. The installer puts reclient in `/opt/reclient` and writes the RBE
environment to `/etc/profile.d/rbe_env.sh`, so every `m` / `mka` build uses RBE
automatically.

## Requirements

- Ubuntu 22.04 / 24.04
- sudo
- A BuildBuddy API key (Remote Execution enabled on your org)
- reclient `linux-amd64` binaries (not included, see below)

## Setup

1. Clone:

   ```bash
   git clone https://github.com/MufasaXz/rbe.git
   cd rbe
   ```

2. Put the reclient binaries in `rbe-client/` (`reproxy`, `rewrapper`,
   `bootstrap`, `remotetool`, ...). They are ~350 MB, so they are not in this
   repo. The installer needs `./rbe-client/` to exist.

3. Add your BuildBuddy API key in `install_rbe.sh` (get it from
   <https://app.buildbuddy.io/> → Quickstart):

   ```sh
   export BUILDBUDDY_API_KEY="your-key-here"
   export RBE_remote_headers="x-buildbuddy-api-key=your-key-here"
   ```

4. Install:

   ```bash
   chmod +x install_rbe.sh
   ./install_rbe.sh
   ```

5. Open a new shell (or `source /etc/profile.d/rbe_env.sh`) and build with
   `m` / `mka`.

## Verify

```bash
echo "$USE_RBE"                      # 1
/opt/reclient/reproxy --version
```

## Troubleshooting

- `Unauthenticated ... Unable to authenticate with RBE` → the API key is missing
  or wrong. Check `BUILDBUDDY_API_KEY` and `RBE_remote_headers`, then
  `source /etc/profile.d/rbe_env.sh`.
- To turn RBE off and build locally: `export USE_RBE=0`

## Credits

- reclient: <https://github.com/bazelbuild/reclient>
- BuildBuddy: <https://www.buildbuddy.io/>
