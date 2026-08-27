#!/usr/bin/env bash
set -e

WORKSPACE="/content/Omniverse"
REPO="https://github.com/sc35w/Omniverse.git"

echo "=========================================="
echo " Omniverse Runtime Setup"
echo "=========================================="

# --------------------------------------------------
# 1. GPU
# --------------------------------------------------

echo "[1/7] GPU"
nvidia-smi --query-gpu=name,memory.total,driver_version \
    --format=csv,noheader


# --------------------------------------------------
# 2. ROS 2 Humble
# --------------------------------------------------

echo "[2/7] ROS 2"

if [ -f /opt/ros/humble/setup.bash ]; then

    echo "ROS 2 Humble: already installed"

else

    echo "ROS 2 Humble: installing..."

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
        python3-rosdep

    curl -fsSL \
        https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg

    echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu \
$(. /etc/os-release && echo "$UBUNTU_CODENAME") main" \
        > /etc/apt/sources.list.d/ros2.list

    apt-get update -qq

    apt-get install -y -qq \
        ros-humble-ros-base \
        ros-humble-rclcpp \
        ros-humble-rclpy \
        ros-humble-std-msgs \
        ros-humble-geometry-msgs \
        ros-humble-sensor-msgs \
        ros-humble-nav-msgs \
        ros-humble-tf2 \
        ros-humble-tf2-ros \
        ros-humble-tf2-geometry-msgs \
        ros-humble-robot-state-publisher \
        ros-humble-xacro \
        ros-humble-ros2-control \
        ros-humble-ros2-controllers \
        ros-humble-controller-manager \
        python3-colcon-common-extensions

fi

source /opt/ros/humble/setup.bash

echo "ROS_DISTRO=$ROS_DISTRO"
echo "ros2=$(which ros2)"
echo "colcon=$(which colcon)"


# --------------------------------------------------
# 3. Isaac Sim
# --------------------------------------------------

echo "[3/7] Isaac Sim"

if python3 -c "import isaacsim" >/dev/null 2>&1; then

    echo "Isaac Sim: already installed"

else

    echo "Isaac Sim: installing..."

    python3 -m pip install \
        "isaacsim[all,extscache]==6.0.1.0" \
        --extra-index-url https://pypi.nvidia.com

fi


# --------------------------------------------------
# 4. Empy
# --------------------------------------------------

echo "[4/7] Empy"

if /usr/bin/python3 -c \
    "import em; assert hasattr(em,'BUFFERED_OPT')" \
    >/dev/null 2>&1; then

    echo "Empy: OK"

else

    echo "Installing compatible Empy..."

    python3 -m pip install \
        "empy==3.3.4" \
        --ignore-installed

fi


# --------------------------------------------------
# 5. OSQP
# --------------------------------------------------

echo "[5/7] OSQP"

if find /usr/local/lib /usr/lib/x86_64-linux-gnu \
    -maxdepth 1 \
    -name "libosqp.so*" \
    2>/dev/null | grep -q .; then

    echo "Native OSQP: already installed"

else

    echo "Native OSQP: building..."

    cd /tmp

    rm -rf osqp

    git clone --depth 1 \
        https://github.com/osqp/osqp.git

    cd osqp

    cmake \
        -S . \
        -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local

    cmake --build build -j"$(nproc)"

    cmake --install build

    ldconfig

fi

export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"


# --------------------------------------------------
# 6. Omniverse repository
# --------------------------------------------------

echo "[6/7] Omniverse repository"

if [ -d "$WORKSPACE/.git" ]; then

    echo "Repository: already present"

else

    echo "Cloning repository..."

    git clone "$REPO" "$WORKSPACE"

fi

cd "$WORKSPACE"

echo "Commit:"
git log -1 --oneline


# --------------------------------------------------
# 7. Build
# --------------------------------------------------

echo "[7/7] ROS workspace"

source /opt/ros/humble/setup.bash

cd "$WORKSPACE"

# Only build if install/setup.bash doesn't exist.
if [ -f install/setup.bash ]; then

    echo "Workspace already built."
    echo "Running incremental build..."

else

    echo "First build..."

fi

export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"

colcon build --symlink-install

source install/setup.bash


echo
echo "=========================================="
echo " READY"
echo "=========================================="

echo "ROS_DISTRO=$ROS_DISTRO"
echo "ROS2=$(which ros2)"
echo "COLCON=$(which colcon)"
echo "WORKSPACE=$WORKSPACE"

echo
echo "Packages:"
colcon list
