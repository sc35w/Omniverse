#!/usr/bin/env bash

# ============================================================
# FAST OMNIVERSE SETUP
#
# Ubuntu 22.04
# Python 3.12
# ROS 2 Humble
# Isaac Sim 6.0.1
# NVIDIA T4 / Google Colab
#
# Workspace:
#   /content/Omniverse
#
# Repository:
#   https://github.com/sc35w/Omniverse
# ============================================================

set -e

WORKSPACE="/content/Omniverse"
REPO="https://github.com/sc35w/Omniverse.git"
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
echo "[1/8] GPU"
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
echo "[2/8] ROS 2 Humble"
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
        >/dev/null

    # Enable Universe
    add-apt-repository universe -y \
        >/dev/null 2>&1 || true

    # --------------------------------------------------------
    # ROS key
    # --------------------------------------------------------

    if [ ! -f /usr/share/keyrings/ros-archive-keyring.gpg ]; then

        curl -fsSL \
            https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
            -o /usr/share/keyrings/ros-archive-keyring.gpg

    fi

    # --------------------------------------------------------
    # ROS repository
    # --------------------------------------------------------

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") main" \
        > /etc/apt/sources.list.d/ros2.list

    apt-get update -qq

    # Minimal ROS installation
    apt-get install -y -qq \
        ros-humble-ros-base \
        >/dev/null

fi


# ------------------------------------------------------------
# ROS environment
#
# IMPORTANT:
# ROS Humble setup.bash can reference unset variables.
# Therefore NEVER source it with "set -u".
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
echo "[3/8] ROS build tools"
echo "------------------------------------------------------------"


if command -v colcon >/dev/null 2>&1; then

    echo "colcon already installed -> SKIP"

else

    echo "Installing colcon..."

    apt-get update -qq

    apt-get install -y -qq \
        python3-colcon-common-extensions \
        >/dev/null

fi


if command -v rosdep >/dev/null 2>&1; then

    echo "rosdep already installed -> SKIP"

else

    echo "Installing rosdep..."

    apt-get update -qq

    apt-get install -y -qq \
        python3-rosdep \
        >/dev/null

fi


echo "COLCON=$(which colcon)"
echo "ROSDEP=$(which rosdep)"


# ============================================================
# 4. EMPY
# ============================================================

echo
echo "[4/8] Empy"
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
# 5. NATIVE OSQP 0.6.3
# ============================================================

echo
echo "[5/8] Native OSQP 0.6.3"
echo "------------------------------------------------------------"


# ------------------------------------------------------------
# Make /usr/local/lib visible
# ------------------------------------------------------------

export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"

echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf

ldconfig 2>/dev/null || true


# ------------------------------------------------------------
# Check native library
# ------------------------------------------------------------

OSQP_NATIVE_OK="no"

if find \
    /usr/local/lib \
    /usr/lib \
    /usr/lib/x86_64-linux-gnu \
    -maxdepth 1 \
    -name "libosqp.so*" \
    2>/dev/null | grep -q .; then

    OSQP_NATIVE_OK="yes"

fi


if [ "$OSQP_NATIVE_OK" = "yes" ]; then

    echo "Native libosqp.so already exists -> SKIP"

else

    echo "Native libosqp.so not found."
    echo "Installing OSQP 0.6.3..."

    rm -rf /tmp/osqp-0.6.3

    # IMPORTANT:
    # --recurse-submodules is required because OSQP 0.6.3
    # depends on QDLDL source.

    git clone \
        --recurse-submodules \
        --branch v0.6.3 \
        https://github.com/osqp/osqp.git \
        /tmp/osqp-0.6.3

    cd /tmp/osqp-0.6.3

    # Ensure all submodules exist
    git submodule update --init --recursive

    # Verify QDLDL
    if [ ! -f \
        lin_sys/direct/qdldl/qdldl_sources/CMakeLists.txt ]; then

        echo
        echo "ERROR: QDLDL source was not downloaded."
        echo "OSQP cannot be built."
        exit 1

    fi

    echo "QDLDL source -> OK"

    rm -rf build

    mkdir build

    cd build

    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DBUILD_SHARED_LIBS=ON \
        -DUNITTESTS=OFF \
        -DDEMO=OFF \
        -DCOVERAGE=OFF \
        -DPROFILING=OFF

    cmake --build . -j2

    cmake --install .

fi


# ------------------------------------------------------------
# Refresh linker
# ------------------------------------------------------------

echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf

ldconfig 2>/dev/null || true

export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"


echo
echo "Native OSQP:"

find \
    /usr/local/lib \
    /usr/lib \
    /usr/lib/x86_64-linux-gnu \
    -maxdepth 1 \
    -name "libosqp.so*" \
    2>/dev/null || true


# ============================================================
# 6. ISAAC SIM 6.0.1
# ============================================================

echo
echo "[6/8] Isaac Sim $ISAAC_VERSION"
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
    echo "Installing Isaac Sim $ISAAC_VERSION"
    echo
    echo "Using:"
    echo "  isaacsim==$ISAAC_VERSION"
    echo
    echo "NOT using:"
    echo "  [all,extscache]"
    echo

    python3 -m pip install \
        "isaacsim==${ISAAC_VERSION}" \
        --extra-index-url https://pypi.nvidia.com \
        --disable-pip-version-check

fi


# ============================================================
# 7. OMNIVERSE REPOSITORY
# ============================================================

echo
echo "[7/8] Omniverse workspace"
echo "------------------------------------------------------------"


if [ -d "$WORKSPACE/.git" ]; then

    echo "Repository already exists -> SKIP clone"

else

    echo "Cloning:"
    echo "$REPO"

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


# ============================================================
# 8. ROS DEPENDENCIES + BUILD
# ============================================================

echo
echo "[8/8] ROS dependencies + build"
echo "------------------------------------------------------------"


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
# Only update if cache doesn't exist.
# ------------------------------------------------------------

if [ ! -d /root/.ros/rosdep/sources.cache ]; then

    echo "rosdep database not found -> updating..."

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
# CMake / OSQP environment
# ------------------------------------------------------------

export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"

export CMAKE_PREFIX_PATH="/usr/local:${CMAKE_PREFIX_PATH:-}"


# ------------------------------------------------------------
# Build
#
# IMPORTANT:
# Never delete build/install/log.
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
# FINAL VERIFICATION
# ============================================================

echo
echo "============================================================"
echo " OMNIVERSE ENVIRONMENT READY"
echo "============================================================"


echo
echo "ROS:"
echo "ROS_DISTRO = $ROS_DISTRO"
echo "ROS_VERSION = $ROS_VERSION"
echo "ROS2       = $(which ros2)"
echo "COLCON     = $(which colcon)"


echo
echo "OSQP:"
ldconfig -p 2>/dev/null | grep osqp || true


echo
echo "Isaac Sim:"

set +e

python3 - <<'PY'
try:
    import isaacsim
    print("Isaac Sim: OK")
    print("Location:", isaacsim.__file__)
except Exception as e:
    print("Isaac Sim import failed:", e)
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
