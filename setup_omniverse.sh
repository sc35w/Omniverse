#!/usr/bin/env bash

# ============================================================
# FAST OMNIVERSE / ISAAC SIM / ROS 2 HUMBLE SETUP
# Ubuntu 22.04 / Google Colab / NVIDIA GPU
#
# Features:
#   - Skips already-installed software
#   - Minimal ROS 2 Humble
#   - Isaac Sim 6.0.1
#   - ROS-compatible Empy
#   - Native OSQP only if missing
#   - Does NOT delete build/install/log
#   - Incremental colcon build
# ============================================================

set -e

WORKSPACE="/content/Omniverse"
REPO="https://github.com/sc35w/Omniverse.git"

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
        git \
        build-essential \
        cmake \
        python3-pip \
        >/dev/null


    # Enable Universe
    add-apt-repository universe -y \
        >/dev/null 2>&1 || true


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


    # Minimal ROS installation
    apt-get install -y -qq \
        ros-humble-ros-base \
        >/dev/null

fi


# ------------------------------------------------------------
# IMPORTANT:
# ROS setup.bash may reference unset variables.
# Never source it while nounset is active.
# ------------------------------------------------------------

set +u

export AMENT_TRACE_SETUP_FILES=""

source /opt/ros/humble/setup.bash

set -u


echo
echo "ROS_DISTRO=$ROS_DISTRO"
echo "ROS_VERSION=$ROS_VERSION"


# ------------------------------------------------------------
# Colcon
# ------------------------------------------------------------

if command -v colcon >/dev/null 2>&1; then

    echo "colcon already installed -> SKIP"

else

    echo "Installing colcon..."

    set +u

    apt-get install -y -qq \
        python3-colcon-common-extensions \
        >/dev/null

    set -u

fi


echo "ROS2=$(which ros2)"
echo "COLCON=$(which colcon)"


# ============================================================
# 3. ROSDEP
# ============================================================

echo
echo "[3/7] ROS dependency tools"
echo "------------------------------------------------------------"


if command -v rosdep >/dev/null 2>&1; then

    echo "rosdep already installed -> SKIP"

else

    echo "Installing rosdep..."

    apt-get update -qq

    apt-get install -y -qq \
        python3-rosdep \
        >/dev/null

fi


# Initialize rosdep if needed

if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then

    echo "Initializing rosdep..."

    rosdep init 2>/dev/null || true

fi


# ============================================================
# 4. ISAAC SIM
# ============================================================

echo
echo "[4/7] Isaac Sim 6.0.1"
echo "------------------------------------------------------------"


if python3 -c "import isaacsim" >/dev/null 2>&1; then

    echo "Isaac Sim already installed -> SKIP"

else

    echo "Isaac Sim not found -> installing 6.0.1..."

    python3 -m pip install \
        "isaacsim[all,extscache]==6.0.1.0" \
        --extra-index-url https://pypi.nvidia.com \
        --disable-pip-version-check

fi


# ============================================================
# 5. EMPY
# ============================================================

echo
echo "[5/7] Empy"
echo "------------------------------------------------------------"


# ROS Humble's rosidl_adapter needs BUFFERED_OPT.

if /usr/bin/python3 -c \
    "import em; assert hasattr(em,'BUFFERED_OPT')" \
    >/dev/null 2>&1; then

    echo "ROS Empy compatible -> SKIP"

else

    echo "Installing ROS-compatible Empy..."

    apt-get update -qq

    apt-get install -y -qq \
        python3-empy \
        >/dev/null

fi


set +u

/usr/bin/python3 -c "
import em
print('Empy module :', em.__file__)
print('Empy version:', getattr(em,'__version__','unknown'))
print('BUFFERED_OPT:', hasattr(em,'BUFFERED_OPT'))
"

set -u


# ============================================================
# 6. NATIVE OSQP
# ============================================================

echo
echo "[6/7] Native OSQP"
echo "------------------------------------------------------------"


export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"

ldconfig


if find \
    /usr/local/lib \
    /usr/lib \
    /usr/lib/x86_64-linux-gnu \
    -maxdepth 1 \
    -name "libosqp.so*" \
    2>/dev/null | grep -q .; then

    echo "Native OSQP already installed -> SKIP"

else

    echo "Native OSQP not found -> building..."

    cd /tmp


    if [ ! -d /tmp/osqp ]; then

        git clone \
            --depth 1 \
            https://github.com/osqp/osqp.git

    else

        echo "OSQP source already exists -> SKIP clone"

    fi


    cd /tmp/osqp


    cmake \
        -S . \
        -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local


    cmake \
        --build build \
        -j2


    cmake \
        --install build


    ldconfig

fi


export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"


echo
echo "OSQP library:"

find \
    /usr/local/lib \
    /usr/lib \
    /usr/lib/x86_64-linux-gnu \
    -maxdepth 1 \
    -name "libosqp.so*" \
    2>/dev/null || true


# ============================================================
# 7. OMNIVERSE WORKSPACE
# ============================================================

echo
echo "[7/7] Omniverse workspace"
echo "------------------------------------------------------------"


# ------------------------------------------------------------
# Clone repository only when missing
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
echo "Current commit:"
git log -1 --oneline


# ------------------------------------------------------------
# ROS environment
# ------------------------------------------------------------

set +u

export AMENT_TRACE_SETUP_FILES=""

source /opt/ros/humble/setup.bash

set -u


# ------------------------------------------------------------
# OSQP library
# ------------------------------------------------------------

export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"


# ------------------------------------------------------------
# rosdep
# ------------------------------------------------------------

echo
echo "Updating rosdep..."

rosdep update \
    --rosdistro humble \
    2>/dev/null || true


echo
echo "Checking workspace dependencies..."

rosdep install \
    --from-paths src \
    --ignore-src \
    --rosdistro humble \
    -r \
    -y


# ------------------------------------------------------------
# Build
# ------------------------------------------------------------

echo
echo "Building workspace..."

colcon build \
    --symlink-install


# ------------------------------------------------------------
# Source workspace
# ------------------------------------------------------------

if [ -f install/setup.bash ]; then

    set +u

    export AMENT_TRACE_SETUP_FILES=""

    source install/setup.bash

    set -u

fi


# ============================================================
# FINAL VERIFICATION
# ============================================================

echo
echo "============================================================"
echo " OMNIVERSE READY"
echo "============================================================"

echo
echo "ROS_DISTRO = $ROS_DISTRO"
echo "ROS2       = $(which ros2)"
echo "COLCON     = $(which colcon)"
echo "WORKSPACE  = $WORKSPACE"

echo
echo "ROS packages:"
colcon list

echo
echo "============================================================"
echo " SETUP COMPLETE"
echo "============================================================"
