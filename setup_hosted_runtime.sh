#!/usr/bin/env bash
set -e

# ============================================================
# FAST OMNIVERSE / ISAAC SIM / ROS 2 HUMBLE SETUP
# Ubuntu 22.04
# Isaac Sim 6.0.1
# ROS 2 Humble
#
# Designed for temporary Google Colab runtimes.
# Skips anything already installed.
# Does NOT delete existing workspace builds.
# ============================================================

WORKSPACE="/content/Omniverse"
REPO="https://github.com/sc35w/Omniverse.git"

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

nvidia-smi --query-gpu=name,memory.total,driver_version \
    --format=csv,noheader


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
        git \
        build-essential \
        cmake \
        python3-pip \
        python3-rosdep \
        >/dev/null

    # ROS repository
    if [ ! -f /usr/share/keyrings/ros-archive-keyring.gpg ]; then

        curl -fsSL \
            https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
            -o /usr/share/keyrings/ros-archive-keyring.gpg

    fi

    echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu \
$(. /etc/os-release && echo "$UBUNTU_CODENAME") main" \
        > /etc/apt/sources.list.d/ros2.list

    apt-get update -qq

    # Minimal ROS installation.
    # Additional dependencies are resolved by rosdep later.
    apt-get install -y -qq \
        ros-humble-ros-base \
        python3-colcon-common-extensions \
        >/dev/null

fi

source /opt/ros/humble/setup.bash

echo "ROS_DISTRO=$ROS_DISTRO"
echo "ROS_VERSION=$ROS_VERSION"
echo "ROS2=$(which ros2)"
echo "COLCON=$(which colcon)"


# ============================================================
# 3. ISAAC SIM
# ============================================================

echo
echo "[3/7] Isaac Sim 6.0.1"
echo "------------------------------------------------------------"

if python3 -c "import isaacsim" >/dev/null 2>&1; then

    echo "Isaac Sim already installed -> SKIP"

else

    echo "Isaac Sim not found -> installing..."

    python3 -m pip install \
        "isaacsim[all,extscache]==6.0.1.0" \
        --extra-index-url https://pypi.nvidia.com \
        --disable-pip-version-check

fi


# ============================================================
# 4. EMPY
# ============================================================

echo
echo "[4/7] Empy / ROS interface generator"
echo "------------------------------------------------------------"

# ROS 2 Humble rosidl_adapter requires the old Empy API.
# Check the Python interpreter actually used by ROS.

if /usr/bin/python3 -c \
    "import em; assert hasattr(em,'BUFFERED_OPT')" \
    >/dev/null 2>&1; then

    echo "ROS Empy compatible -> SKIP"

else

    echo "Compatible Empy not found."

    # Try Ubuntu's ROS-compatible package first.
    apt-get update -qq

    apt-get install -y -qq \
        python3-empy \
        >/dev/null

fi


# Verify

/usr/bin/python3 -c "
import em
print('Empy:', getattr(em,'__version__','unknown'))
print('BUFFERED_OPT:', hasattr(em,'BUFFERED_OPT'))
"


# ============================================================
# 5. NATIVE OSQP
# ============================================================

echo
echo "[5/7] Native OSQP"
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


echo "OSQP:"
find \
    /usr/local/lib \
    /usr/lib \
    /usr/lib/x86_64-linux-gnu \
    -maxdepth 1 \
    -name "libosqp.so*" \
    2>/dev/null || true


# ============================================================
# 6. OMNIVERSE REPOSITORY
# ============================================================

echo
echo "[6/7] Omniverse repository"
echo "------------------------------------------------------------"

if [ -d "$WORKSPACE/.git" ]; then

    echo "Omniverse repository already exists -> SKIP clone"

else

    echo "Cloning Omniverse..."

    git clone \
        --depth 1 \
        "$REPO" \
        "$WORKSPACE"

fi


cd "$WORKSPACE"

echo
echo "Current commit:"
git log -1 --oneline


# ============================================================
# 7. BUILD
# ============================================================

echo
echo "[7/7] ROS 2 workspace"
echo "------------------------------------------------------------"

source /opt/ros/humble/setup.bash

cd "$WORKSPACE"

export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"


# ------------------------------------------------------------
# rosdep
# ------------------------------------------------------------

if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then

    echo "Initializing rosdep..."

    rosdep init 2>/dev/null || true

fi

rosdep update \
    --rosdistro humble \
    2>/dev/null || true


echo
echo "Installing missing ROS dependencies..."

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
    source install/setup.bash
fi


# ============================================================
# FINAL
# ============================================================

echo
echo "============================================================"
echo " OMNIVERSE READY"
echo "============================================================"

echo
echo "ROS:"
echo "  ROS_DISTRO = $ROS_DISTRO"
echo "  ROS2       = $(which ros2)"
echo "  COLCON     = $(which colcon)"

echo
echo "Workspace:"
echo "  $WORKSPACE"

echo
echo "Packages:"
colcon list

echo
echo "============================================================"
echo " SETUP COMPLETE"
echo "============================================================"
