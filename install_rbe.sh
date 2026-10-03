#!/usr/bin/env bash
set -e

echo "=============================================="
echo "      BuildBuddy RBE Setup for Ubuntu"
echo "=============================================="

# --- 0. Sanity check: the reclient binaries must be present ---
# This repo does NOT ship the reclient binaries (they are ~350 MB).
# Put the "rbe-client/" folder (linux-amd64) next to this script first.
# See the README section "1. Get the reclient binaries".
if [ ! -d "./rbe-client" ]; then
    echo "[ERROR] rbe-client/ folder not found in the current directory!"
    echo
    echo "  This installer does not ship the reclient binaries. Get them first:"
    echo "    - grab a linux-amd64 'reclient' build (reproxy, rewrapper, bootstrap,"
    echo "      remotetool, ...), or"
    echo "    - clone a repo that already contains an rbe-client/ folder."
    echo
    echo "  Then place the folder next to this script so ./rbe-client exists."
    exit 1
fi

# --- 1. Install reclient into /opt/reclient ---
echo "[INFO] Installing reclient into /opt/reclient ..."

sudo rm -rf /opt/reclient
sudo mkdir -p /opt/reclient

sudo cp -r ./rbe-client/* /opt/reclient/
sudo chmod -R 755 /opt/reclient

echo "[OK] reclient installed."


# --- 2. Create RAM directory for Git optimization (optional) ---
#echo "[INFO] Creating /dev/shm/git-tmp ..."
#sudo mkdir -p /dev/shm/git-tmp
#sudo chmod 1777 /dev/shm/git-tmp


# --- 3. Create global environment file ---
echo "[INFO] Generating /etc/profile.d/rbe_env.sh ..."

sudo tee /etc/profile.d/rbe_env.sh > /dev/null <<'EOF'
# --- Enable CCACHE
export USE_CCACHE=1

# --- Enable RBE and General Settings ---
export USE_RBE=1

export RBE_QUIET=1
export RBE_display=0
export RBE_diagnostics=0
export RBE_errorlog=0

export NINJA_REMOTE_NUM_JOBS=2000

# ---------------------------------------------------------------------------
# BuildBuddy service + API key
#
#   PUT YOUR OWN API KEY BELOW. Get it from your BuildBuddy Quickstart page:
#       https://app.buildbuddy.io/   ->   Quickstart
#
#   If these stay empty, every RBE action fails with:
#       Unauthenticated ... Unable to authenticate with RBE
# ---------------------------------------------------------------------------
export RBE_service="remote.buildbuddy.io:443"
export BUILDBUDDY_API_KEY=""
export RBE_remote_headers="x-buildbuddy-api-key="

# Authentication: reclient authenticates with the x-buildbuddy-api-key header
# above (not with Google RPC credentials), so disable the built-in auth paths.
export RBE_use_rpc_credentials=false
export RBE_service_no_auth=true

# Unified uploads/downloads
export RBE_use_unified_downloads=true
export RBE_use_unified_uploads=true

# Execution Strategies for Android tools
for tool in R8 D8 JAVAC JAR ZIP TURBINE SIGNAPK CXX CXX_LINKS ABI_LINKER CLANG_TIDY METALAVA LINT; do
    eval "export RBE_${tool}_EXEC_STRATEGY=remote_local_fallback"
    eval "export RBE_${tool}=1"
done

# Resource pools
export RBE_JAVA_POOL=default
export RBE_METALAVA_POOL=default
export RBE_LINT_POOL=default

# Completely disable remote Java toolchain (unreliable)
export RBE_JAVAC=0
export RBE_JAR=0
export RBE_D8=0
export RBE_TURBINE=0

export RBE_javac=0
export RBE_jar=0
export RBE_d8=0
export RBE_turbine=0

export RBE_JAVAC_EXEC_STRATEGY=local
export RBE_JAR_EXEC_STRATEGY=local

# Tools that are ALWAYS local-only
export RBE_HIDDENAPI=0
export RBE_HIDDENAPI_EXEC_STRATEGY=local
export RBE_METALAVA=0
export RBE_METALAVA_EXEC_STRATEGY=local
export RBE_LINT=0
export RBE_LINT_EXEC_STRATEGY=local
export RBE_ZIP=0
export RBE_ZIP_EXEC_STRATEGY=local
export RBE_SIGNAPK=0
export RBE_SIGNAPK_EXEC_STRATEGY=local

# Heavy tasks that SHOULD remain remote
export RBE_CXX=1
export RBE_CXX_EXEC_STRATEGY=remote_local_fallback
export RBE_CXX_LINKS=1
export RBE_CXX_LINKS_EXEC_STRATEGY=remote_local_fallback
export RBE_R8=1
export RBE_R8_EXEC_STRATEGY=remote_local_fallback

# Safe RBE settings
export RBE_use_unified_downloads=false
export RBE_use_unified_uploads=false
export RBE_remote_download_mode=minimal

# Keep ABI tools local
export RBE_LOCAL_ONLY_REGEX="header-abi-diff|create_reference_dumps"
export RBE_HEADER_ABI_DIFF_EXEC_STRATEGY=local
export RBE_ABI_LINKER_EXEC_STRATEGY=local

# Do NOT hardcode RBE_instance
# (optional) auto versioning if you want strict separation
# export RBE_instance="android${PLATFORM_VERSION}"

# Git optimization (optional)
# export GIT_ALTERNATE_OBJECT_DIRECTORIES=/dev/shm/git-tmp
EOF

sudo chmod +x /etc/profile.d/rbe_env.sh
echo "[OK] RBE environment installed."


# --- 4. Load into current shell ---
echo "[INFO] Loading RBE environment..."
source /etc/profile.d/rbe_env.sh || true

echo "=============================================="
echo "    RBE setup complete!"
echo "=============================================="
echo
echo "Verify with:"
echo "  echo \$USE_RBE"
echo "  /opt/reclient/reproxy --version"
echo
echo "You may need to reopen your terminal."
echo
echo "[INFO] Attempting to load RBE environment..."

# If script is being sourced, this WILL persist
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    source /etc/profile.d/rbe_env.sh
    echo "[OK] RBE environment loaded into current shell."
else
    # Script executed normally (most common case)
    source /etc/profile.d/rbe_env.sh || true
    echo
    echo "⚠️  RBE environment installed but NOT active in this shell."
    echo "➡️  Run the following command to activate it:"
    echo
    echo "    source /etc/profile.d/rbe_env.sh"
    echo
    echo "➡️  Or simply open a new terminal / Byobu session."
    echo
fi
