#!/usr/bin/env bash
set -e

WORKSPACE="/content/Omniverse"
REPO="https://github.com/sc35w/Omniverse.git"

echo "=========================================="
echo " FAST OMNIVERSE SETUP"
echo "=========================================="

# --------------------------------------------------
# 1. GPU
# --------------------------------------------------

echo "[1/7] GPU"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader


# --------------------------------------------------
# 2. ROS 2 Humble - MINIMAL
# --------------------------------------------------

echo "[2/7] ROS 2 Humble"

if [ -f /opt/ros/humble/setup.bash ]; then

    echo "ROS 2 already installed -> SKIP"

else

    echo "Installing minimal ROS 2 Humble..."

    apt-get update -qq

    apt-get install -y -qq \
        curl \
        gnupg2 \
        git \
        build-essential \
        cmake \
        python3-pip \
        python3-rosdep \
        >/dev/null

    curl -fsSL \
        https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg

    echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu \
$(. /etc/os-release && echo "$UBUNTU_CODENAME") main" \
        > /etc/apt/sources.list.d/ros2.list

    apt-get update -qq

    # ONLY ROS base + build tools
    apt-get install -y -qq \
        ros-humble-ros-base \
        python3-colcon-common-extensions \
        >/dev/null

fi

source /opt/ros/humble/setup.bash


# --------------------------------------------------
# 3. Isaac Sim
# --------------------------------------------------

echo "[3/7] Isaac Sim"

if python3 -c "import isaacsim" >/dev/null 2>&1; then

    echo "Isaac Sim already installed -> SKIP"

else

    echo "Installing Isaac Sim 6.0.1..."

    python3 -m pip install \
        "isaacsim[all,extscache]==6.0.1.0" \
        --extra-index-url https://pypi.nvidia.com \
        --disable-pip-version-check

fi


# --------------------------------------------------
# 4. Empy
# --------------------------------------------------

echo "[4/7] Empy"

if /usr/bin/python3 -c \
    "import em; assert hasattr(em,'BUFFERED_OPT')" \
    >/dev/null 2>&1; then

    echo "Empy OK -> SKIP"

else

    echo "Installing Empy 3.3.4..."

    python3 -m pip install \
        "empy==3.3.4" \
        --ignore-installed \
        --no-cache-dir

fi


# --------------------------------------------------
# 5. OSQP
# --------------------------------------------------

echo "[5/7] OSQP"

if find /usr/local/lib /usr/lib \
    -name "libosqp.so*" \
    2>/dev/null | grep -q .; then

    echo "Native OSQP already installed -> SKIP"

else

    echo "Installing native OSQP..."

    cd /tmp

    if [ ! -d osqp ]; then
        git clone --depth 1 \
            https://github.com/osqp/osqp.git
    fi

    cd osqp

    cmake \
        -S . \
        -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local

    cmake --build build -j2

    cmake --install build

    ldconfig

fi

export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"


# --------------------------------------------------
# 6. Omniverse repository
# --------------------------------------------------

echo "[6/7] Omniverse repository"

if [ -d "$WORKSPACE/.git" ]; then

    echo "Repository already exists -> SKIP"

else

    git clone \
        --depth 1 \
        "$REPO" \
        "$WORKSPACE"

fi


# --------------------------------------------------
# 7. Build
# --------------------------------------------------

echo "[7/7] Building workspace"

cd "$WORKSPACE"

source /opt/ros/humble/setup.bash

export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"

# Only resolve dependencies if needed
if [ ! -d install ]; then

    echo "First build..."

    rosdep init 2>/dev/null || true
    rosdep update --rosdistro humble 2>/dev/null || true

    rosdep install \
        --from-paths src \
        --ignore-src \
        --rosdistro humble \
        -r -y

else

    echo "Existing build detected -> incremental build"

fi

colcon build --symlink-install

echo
echo "=========================================="
echo " READY"
echo "=========================================="

echo "ROS:       $(which ros2)"
echo "COLCON:    $(which colcon)"
echo "Workspace: $WORKSPACE"

source install/setup.bash

echo
echo "Packages:"
colcon list
