#!/usr/bin/env bash
set -e

echo "======================================"
echo " Omniverse Hosted Runtime Setup"
echo "======================================"

# --------------------------------------------------
# 1. Basic configuration
# --------------------------------------------------

export DEBIAN_FRONTEND=noninteractive

ISAACSIM_ROOT="/usr/local/lib/python3.12/dist-packages/isaacsim"
ROS_HUMBLE_ROOT="/usr/local/lib/python3.12/dist-packages/isaacsim/exts/isaacsim.ros2.core/humble"

echo "[1/9] Checking GPU..."
nvidia-smi

# --------------------------------------------------
# 2. Clone/update project
# --------------------------------------------------

echo "[2/9] Getting Omniverse repository..."

if [ ! -d /content/Omniverse/.git ]; then
    git clone https://github.com/sc35w/Omniverse.git /content/Omniverse
else
    cd /content/Omniverse
    git pull --ff-only
fi

# --------------------------------------------------
# 3. Isaac Sim
# --------------------------------------------------

echo "[3/9] Checking Isaac Sim..."

if python3 -c "import isaacsim" >/dev/null 2>&1; then
    echo "Isaac Sim already installed."
else
    python3 -m pip install \
        "isaacsim[all,extscache]==6.0.1.0" \
        --extra-index-url https://pypi.nvidia.com
fi

# --------------------------------------------------
# 4. ROS 2 repository
# --------------------------------------------------

echo "[4/9] Checking ROS 2..."

if [ ! -f /opt/ros/humble/setup.bash ]; then

    apt-get update

    apt-get install -y \
        curl \
        gnupg2 \
        software-properties-common

    curl -fsSL \
        https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu jammy main" \
        > /etc/apt/sources.list.d/ros2.list

    apt-get update

    apt-get install -y \
        ros-humble-ros-base \
        ros-humble-ament-cmake \
        ros-humble-ament-lint-auto \
        ros-humble-rosidl-default-generators \
        ros-humble-rosidl-default-runtime \
        ros-humble-rclcpp \
        ros-humble-rclpy \
        ros-humble-geometry-msgs \
        ros-humble-nav-msgs \
        ros-humble-sensor-msgs \
        ros-humble-std-msgs \
        ros-humble-tf2 \
        ros-humble-tf2-ros \
        ros-humble-tf2-msgs \
        ros-humble-tf2-geometry-msgs \
        ros-humble-diagnostic-msgs \
        ros-humble-eigen3-cmake-module \
        libeigen3-dev
else
    echo "ROS 2 Humble already installed."
fi

# --------------------------------------------------
# 5. colcon
# --------------------------------------------------

echo "[5/9] Checking colcon..."

if ! command -v colcon >/dev/null 2>&1; then
    python3 -m pip install -U colcon-common-extensions
else
    echo "colcon already installed."
fi

# --------------------------------------------------
# 6. Empy compatibility
# --------------------------------------------------

echo "[6/9] Fixing Empy compatibility..."

python3 -m pip install --force-reinstall "empy==3.3.4"

# --------------------------------------------------
# 7. OSQP
# --------------------------------------------------

echo "[7/9] Checking OSQP..."

if [ ! -f /usr/local/lib/libosqp.so ]; then

    cd /tmp

    rm -rf osqp

    git clone --depth 1 \
        https://github.com/osqp/osqp.git

    cd osqp

    mkdir build
    cd build

    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        ..

    cmake --build . -j2

    cmake --install .

    ldconfig

else
    echo "OSQP already installed."
fi

# --------------------------------------------------
# 8. ROS environment
# --------------------------------------------------

echo "[8/9] Configuring ROS environment..."

source /opt/ros/humble/setup.bash

export ROS_DISTRO=humble

# Isaac Sim bundled Humble rclpy
export PYTHONPATH="${ROS_HUMBLE_ROOT}/rclpy:${PYTHONPATH}"

export LD_LIBRARY_PATH="${ROS_HUMBLE_ROOT}/lib:/usr/local/lib:${LD_LIBRARY_PATH}"

# --------------------------------------------------
# 9. Build workspace
# --------------------------------------------------

echo "[9/9] Building Omniverse workspace..."

cd /content/Omniverse

colcon build --symlink-install

echo ""
echo "======================================"
echo " SETUP COMPLETE"
echo "======================================"

echo "ROS_DISTRO: $ROS_DISTRO"
echo "ROS 2:      $(which ros2)"
echo "colcon:     $(which colcon)"
echo "Workspace:  /content/Omniverse"

echo ""
echo "Packages:"
colcon list
