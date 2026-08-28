#!/usr/bin/env bash

# ============================================================
# FAST OMNIVERSE SETUP
# Ubuntu 22.04 / Google Colab / NVIDIA T4
#
# ROS 2 Humble
# Isaac Sim 6.0.1
# Omniverse ROS workspace
#
# IMPORTANT:
#   This script is optimized for repeated Colab sessions.
# ============================================================

set -e

WORKSPACE="/content/Omniverse"
REPO="https://github.com/sc35w/Omniverse.git""
ISAAC_VERSION="6.0.1.0"

export DEBIAN_FRONTEND=noninteractive


echo
echo "============================================================"
echo " FAST OMNIVERSE SETUP"
echo "============================================================"


# ============================================================
# 1. GPU
# ============================================================

echo
echo "[1/7] GPU"
echo "------------------------------------------------------------"

if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name,memory.total,driver_version \
        --format=csv,noheader
else
    echo "WARNING: NVIDIA GPU not detected"
fi


# ============================================================
# 2. ROS 2 HUMBLE
# ============================================================

echo
echo "[2/7] ROS 2 Humble"
echo "------------------------------------------------------------"

if [ -f /opt/ros/humble/setup.bash ]; then

    echo "ROS 2 Humble already installed -> SKIP"

else

    echo "ROS 2 Humble not found -> installing minimal ROS..."

    apt-get update -qq

    apt-get install -y -qq \
        curl \
        gnupg2 \
        lsb-release \
        software-properties-common \
        ca-certificates \
        git \
        build-essential \
        cmake \
        python3-pip \
        > /dev/null

    # Ubuntu Universe
    add-apt-repository universe -y \
        > /dev/null 2>&1 || true

    # ROS key
    if [ ! -f /usr/share/keyrings/ros-archive-keyring.gpg ]; then

        curl -fsSL \
            https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
            -o /usr/share/keyrings/ros-archive-keyring.gpg

    fi

    # ROS repository
    echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu \
$(. /etc/os-release && echo "$UBUNTU_CODENAME") main" \
        > /etc/apt/sources.list.d/ros2.list

    apt-get update -qq

    # Minimal ROS
    apt-get install -y -qq \
        ros-humble-ros-base \
        > /dev/null

fi


# ------------------------------------------------------------
# Source ROS safely
# ------------------------------------------------------------

set +u

source /opt/ros/humble/setup.bash

set -e


echo "ROS_DISTRO=$ROS_DISTRO"
echo "ROS_VERSION=$ROS_VERSION"
echo "ROS2=$(which ros2)"


# ============================================================
# 3. COLCON + ROSDEP
# ============================================================

echo
echo "[3/7] Build tools"
echo "------------------------------------------------------------"


if command -v colcon >/dev/null 2>&1; then

    echo "colcon already installed -> SKIP"

else

    echo "Installing colcon..."

    apt-get install -y -qq \
        python3-colcon-common-extensions \
        > /dev/null

fi


if command -v rosdep >/dev/null 2>&1; then

    echo "rosdep already installed -> SKIP"

else

    echo "Installing rosdep..."

    apt-get install -y -qq \
        python3-rosdep \
        > /dev/null

fi


echo "COLCON=$(which colcon)"
echo "ROSDEP=$(which rosdep)"


# ============================================================
# 4. EMPY
# ============================================================

echo
echo "[4/7] Empy"
echo "------------------------------------------------------------"


set +u

EMPY_OK=$(python3 - <<'PY'
try:
    import em
    print("yes" if hasattr(em, "BUFFERED_OPT") else "no")
except Exception:
    print("no")
PY
)

set -e


if [ "$EMPY_OK" = "yes" ]; then

    echo "ROS-compatible Empy -> SKIP"

else

    echo "Installing Empy 3.3.4..."

    python3 -m pip install \
        --no-cache-dir \
        "empy==3.3.4" \
        --disable-pip-version-check

fi


# ============================================================
# 5. OSQP
# ============================================================

echo
echo "[5/7] OSQP"
echo "------------------------------------------------------------"


export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"


if find \
    /usr/local/lib \
    /usr/lib \
    /usr/lib/x86_64-linux-gnu \
    -maxdepth 1 \
    -name "libosqp.so*" \
    2>/dev/null | grep -q .; then

    echo "Native OSQP already available -> SKIP"

elif python3 -c "import osqp" >/dev/null 2>&1; then

    echo "Python OSQP already installed -> SKIP"

else

    echo "OSQP not found -> installing Python OSQP..."

    python3 -m pip install \
        --no-cache-dir \
        "osqp==1.0.5" \
        --disable-pip-version-check

fi


# ============================================================
# 6. ISAAC SIM 6.0.1
# ============================================================

echo
echo "[6/7] Isaac Sim $ISAAC_VERSION"
echo "------------------------------------------------------------"


set +u

ISAAC_OK=$(python3 - <<'PY'
try:
    import isaacsim
    print("yes")
except Exception:
    print("no")
PY
)

set -e


if [ "$ISAAC_OK" = "yes" ]; then

    echo "Isaac Sim already installed -> SKIP"

else

    echo
    echo "Isaac Sim not found."
    echo "Installing Isaac Sim 6.0.1..."
    echo "No all/extscache bundle."
    echo

    python3 -m pip install \
        "isaacsim==6.0.1.0" \
        --extra-index-url https://pypi.nvidia.com \
        --disable-pip-version-check

fi


# ============================================================
# 7. WORKSPACE + BUILD
# ============================================================

echo
echo "[7/7] Omniverse workspace"
echo "------------------------------------------------------------"


# ------------------------------------------------------------
# Clone only if missing
# ------------------------------------------------------------

if [ -d "$WORKSPACE/.git" ]; then

    echo "Repository already exists -> SKIP clone"

else

    echo "Cloning Omniverse repository..."

    git clone \
        --depth 1 \
        "$REPO" \
        "$WORKSPACE"

fi


cd "$WORKSPACE"


echo
echo "Workspace:"
echo "$WORKSPACE"

echo
echo "Commit:"
git log -1 --oneline


# ------------------------------------------------------------
# ROS environment
# ------------------------------------------------------------

set +u

source /opt/ros/humble/setup.bash

set -e


# ------------------------------------------------------------
# rosdep initialization
# ------------------------------------------------------------

if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then

    echo "Initializing rosdep..."

    rosdep init 2>/dev/null || true

else

    echo "rosdep already initialized -> SKIP"

fi


# ------------------------------------------------------------
# rosdep database
#
# Don't update every startup.
# ------------------------------------------------------------

if [ ! -f /root/.ros/rosdep/sources.cache/index-v4.yaml ]; then

    echo "rosdep database missing -> updating..."

    rosdep update \
        --rosdistro humble \
        2>/dev/null || true

else

    echo "rosdep database exists -> SKIP update"

fi


# ------------------------------------------------------------
# Workspace dependencies
# ------------------------------------------------------------

echo
echo "Checking workspace dependencies..."

rosdep install \
    --from-paths src \
    --ignore-src \
    --rosdistro humble \
    -r \
    -y


# ------------------------------------------------------------
# BUILD
#
# IMPORTANT:
# DO NOT DELETE:
#   build/
#   install/
#   log/
#
# This allows incremental builds.
# ------------------------------------------------------------

echo
echo "Building workspace..."
echo "Incremental build enabled."

set +u

source /opt/ros/humble/setup.bash

set -e

colcon build \
    --symlink-install \
    --event-handlers console_direct+


# ------------------------------------------------------------
# Source workspace
# ------------------------------------------------------------

if [ -f "$WORKSPACE/install/setup.bash" ]; then

    set +u

    source "$WORKSPACE/install/setup.bash"

    set -e

fi


# ============================================================
# FINAL CHECK
# ============================================================

echo
echo "============================================================"
echo " OMNIVERSE ENVIRONMENT READY"
echo "============================================================"

echo
echo "ROS:"
echo "ROS_DISTRO = $ROS_DISTRO"
echo "ROS_VERSION = $ROS_VERSION"
echo "ROS2 = $(which ros2)"
echo "COLCON = $(which colcon)"

echo
echo "Isaac Sim:"

set +e

python3 - <<'PY'
import isaacsim

print("Isaac Sim: OK")
print("Location:", isaacsim.__file__)
PY

set -e


echo
echo "Workspace:"
echo "$WORKSPACE"

echo
echo "Packages:"

colcon list


echo
echo "============================================================"
echo " SETUP COMPLETE"
echo "============================================================"
