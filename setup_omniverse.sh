#!/usr/bin/env bash

# ============================================================
# FAST OMNIVERSE / ROS 2 HUMBLE / ISAAC SIM 6.0.1
# Google Colab - T4 optimized
#
# Designed to:
#   - SKIP things already installed
#   - NEVER reinstall ROS unnecessarily
#   - NEVER force-reinstall Python packages
#   - NEVER delete build/install/log
#   - Use incremental colcon builds
# ============================================================

set -e

WORKSPACE="/content/Omniverse"
ISAAC_VERSION="6.0.1.0"

echo "============================================================"
echo " FAST OMNIVERSE SETUP"
echo "============================================================"

# ------------------------------------------------------------
# 1. GPU
# ------------------------------------------------------------

echo
echo "[1/7] GPU"
echo "------------------------------------------------------------"

if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name,memory.total,driver_version \
        --format=csv,noheader
else
    echo "WARNING: nvidia-smi not available"
fi


# ------------------------------------------------------------
# 2. ROS 2 Humble
# ------------------------------------------------------------

echo
echo "[2/7] ROS 2 Humble"
echo "------------------------------------------------------------"

if [ -f /opt/ros/humble/setup.bash ]; then

    echo "ROS 2 Humble already installed -> SKIP"

else

    echo "ROS 2 Humble not found -> installing minimal ROS..."

    # Universe
    apt-get update -qq

    apt-get install -y -qq \
        software-properties-common \
        curl \
        gnupg2 \
        lsb-release \
        ca-certificates \
        > /dev/null

    add-apt-repository universe -y > /dev/null 2>&1 || true

    # ROS repository
    if [ ! -f /etc/apt/sources.list.d/ros2.list ]; then

        curl -sSL \
            https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
            -o /usr/share/keyrings/ros-archive-keyring.gpg

        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
        http://packages.ros.org/ros2/ubuntu \
        $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
        > /etc/apt/sources.list.d/ros2.list
    fi

    apt-get update -qq

    # MINIMAL ROS
    apt-get install -y -qq \
        ros-humble-ros-base \
        > /dev/null

fi


# ------------------------------------------------------------
# ROS environment
# ------------------------------------------------------------

# IMPORTANT:
# Do NOT use "set -u".
# ROS Humble setup.bash can reference unset variables.

set +u

source /opt/ros/humble/setup.bash

set -e

echo "ROS_DISTRO=$ROS_DISTRO"
echo "ROS_VERSION=$ROS_VERSION"
echo "ROS2=$(which ros2 || true)"


# ------------------------------------------------------------
# 3. colcon + required ROS build tools
# ------------------------------------------------------------

echo
echo "[3/7] Build tools"
echo "------------------------------------------------------------"

if command -v colcon >/dev/null 2>&1; then

    echo "colcon already installed -> SKIP"

else

    echo "Installing colcon..."

    apt-get update -qq

    apt-get install -y -qq \
        python3-colcon-common-extensions \
        > /dev/null

fi


# rosdep
if command -v rosdep >/dev/null 2>&1; then

    echo "rosdep already installed -> SKIP"

else

    echo "Installing rosdep..."

    apt-get install -y -qq \
        python3-rosdep \
        > /dev/null

fi


# ------------------------------------------------------------
# 4. Python compatibility
# ------------------------------------------------------------

echo
echo "[4/7] Python / ROS compatibility"
echo "------------------------------------------------------------"

set +u

source /opt/ros/humble/setup.bash

set -e

# ROS Humble's rosidl_adapter requires Empy 3.x.
EMPY_OK=$(python3 - <<'PY'
try:
    import em
    print("yes" if hasattr(em, "BUFFERED_OPT") else "no")
except Exception:
    print("no")
PY
)

if [ "$EMPY_OK" = "yes" ]; then

    echo "Empy 3.x compatible -> SKIP"

else

    echo "Installing Empy 3.3.4..."

    python3 -m pip install \
        --no-cache-dir \
        "empy==3.3.4" \
        --disable-pip-version-check

fi


# ------------------------------------------------------------
# 5. OSQP
# ------------------------------------------------------------

echo
echo "[5/7] OSQP"
echo "------------------------------------------------------------"

if [ -f /usr/local/lib/libosqp.so ] || \
   find /usr/local/lib /usr/lib -name 'libosqp.so*' \
   2>/dev/null | grep -q osqp; then

    echo "Native OSQP already available -> SKIP"

else

    echo "Native OSQP not found."

    # Try Python OSQP first.
    if python3 -c "import osqp" >/dev/null 2>&1; then

        echo "Python OSQP already installed -> SKIP"

    else

        echo "Installing Python OSQP..."

        python3 -m pip install \
            --no-cache-dir \
            "osqp==1.0.5" \
            --disable-pip-version-check

    fi

fi


# ------------------------------------------------------------
# 6. Isaac Sim
# ------------------------------------------------------------

echo
echo "[6/7] Isaac Sim $ISAAC_VERSION"
echo "------------------------------------------------------------"

ISAAC_OK=$(python3 - <<'PY'
try:
    import isaacsim
    print("yes")
except Exception:
    print("no")
PY
)

if [ "$ISAAC_OK" = "yes" ]; then

    echo "Isaac Sim already installed -> SKIP"

else

    echo "Isaac Sim not found."

    echo
    echo "Installing MINIMAL Isaac Sim package..."
    echo "IMPORTANT: NOT installing [all,extscache]"
    echo

    python3 -m pip install \
        "isaacsim==${ISAAC_VERSION}" \
        --extra-index-url https://pypi.nvidia.com \
        --disable-pip-version-check

fi


# ------------------------------------------------------------
# 7. Repository + ROS build
# ------------------------------------------------------------

echo
echo "[7/7] Omniverse workspace"
echo "------------------------------------------------------------"


# Clone only if workspace does not exist
if [ -d "$WORKSPACE/.git" ]; then

    echo "Repository already exists -> SKIP clone"

else

    echo "Cloning Omniverse..."

    rm -rf "$WORKSPACE"

    git clone \
        https://github.com/vijethrai/Omniverse.git \
        "$WORKSPACE"

fi


cd "$WORKSPACE"


# ------------------------------------------------------------
# rosdep initialization
# ------------------------------------------------------------

set +u

source /opt/ros/humble/setup.bash

set -e

if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then

    echo "Initializing rosdep..."

    rosdep init 2>/dev/null || true

else

    echo "rosdep already initialized -> SKIP"

fi


# ------------------------------------------------------------
# rosdep update
#
# Only update if necessary.
# This avoids wasting startup time.
# ------------------------------------------------------------

if [ ! -f /root/.ros/rosdep/sources.cache/index-v4.yaml ]; then

    echo "Updating rosdep database..."

    rosdep update \
        --rosdistro humble \
        2>/dev/null || true

else

    echo "rosdep database exists -> SKIP update"

fi


# ------------------------------------------------------------
# Install workspace dependencies
# ------------------------------------------------------------

echo
echo "Installing missing ROS dependencies..."

rosdep install \
    --from-paths "$WORKSPACE" \
    --ignore-src \
    --rosdistro humble \
    -r -y


# ------------------------------------------------------------
# IMPORTANT:
# Do NOT delete build/install/log
# ------------------------------------------------------------

echo
echo "Building Omniverse workspace..."
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

set +u

source "$WORKSPACE/install/setup.bash"

set -e


# ------------------------------------------------------------
# Final verification
# ------------------------------------------------------------

echo
echo "============================================================"
echo " OMNIVERSE ENVIRONMENT READY"
echo "============================================================"

echo
echo "ROS:"
echo "ROS_DISTRO=$ROS_DISTRO"
echo "ROS_VERSION=$ROS_VERSION"
echo "ROS2=$(which ros2)"
echo "COLCON=$(which colcon)"

echo
echo "Isaac Sim:"

python3 - <<'PY'
try:
    import isaacsim
    print("Isaac Sim: OK")
    print("Location:", isaacsim.__file__)
except Exception as e:
    print("Isaac Sim import failed:", e)
PY

echo
echo "Workspace:"
echo "$WORKSPACE"

echo
echo "Packages:"

ros2 pkg list | grep -E \
'amr_msgs|perception|estimation|planning|control_lqr|control_mpc|localization|manipulation|safety|scenarios' \
|| true

echo
echo "============================================================"
echo " DONE"
echo "============================================================"
