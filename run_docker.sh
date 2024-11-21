#!/bin/bash

function print_color {
    tput setaf $1
    echo "$2"
    tput sgr0
}

function print_error {
    print_color 1 "$1"
}

function print_info {
    print_color 2 "$1"
}

JP_QUERY=$(dpkg-query --show nvidia-l4t-core)
JP_VER=${JP_QUERY:16:6}

if [[ "$JP_VER" != "36.3.0" ]]; then
    print_error "This system currently not supported."
    print_error "L4T VERSION: $JP_VER"
    exit 1
fi

# Prevent running as root.
if [[ $(id -u) -eq 0 ]]; then
    print_error "This script cannot be executed with root privileges."
    print_error "Please re-run without sudo and follow instructions to configure docker for non-root user if needed."
    exit 1
fi

# Check if user can run docker without root.
RE="\<docker\>"
if [[ ! $(groups $USER) =~ $RE ]]; then
    print_error "User |$USER| is not a member of the 'docker' group and cannot run docker commands without sudo."
    print_error "Run 'sudo usermod -aG docker \$USER && newgrp docker' to add user to 'docker' group, then re-run this script."
    print_error "See: https://docs.docker.com/engine/install/linux-postinstall/"
    exit 1
fi

# Check if able to run docker commands.
if [[ -z "$(docker ps)" ]] ;  then
    print_error "Unable to run docker commands. If you have recently added |$USER| to 'docker' group, you may need to log out and log back in for it to take effect."
    print_error "Otherwise, please check your Docker installation."
    exit 1
fi

CONTAINER_NAME=cavedu_ros2

# Re-use existing container.
if [ "$(docker ps -a --quiet --filter status=running --filter name=$CONTAINER_NAME)" ]; then
    print_info "Attaching to running container: $CONTAINER_NAME"
    docker exec -i -t -e DISPLAY=$DISPLAY $CONTAINER_NAME /bin/bash
    exit 0
fi

if [ "$(docker ps -a --quiet --filter status=exited --filter name=$CONTAINER_NAME)" ]; then
    print_info "Starting container: $CONTAINER_NAME"
    docker start $CONTAINER_NAME
    print_info "Attaching to running container: $CONTAINER_NAME"
    docker exec -i -t -e DISPLAY=$DISPLAY $CONTAINER_NAME /bin/bash
    exit 0
fi

DOCKER_ARGS+=("-it")
DOCKER_ARGS+=("--rm")
DOCKER_ARGS+=("--privileged")
DOCKER_ARGS+=("--network host")
DOCKER_ARGS+=("--pid host")
DOCKER_ARGS+=("--runtime nvidia")
DOCKER_ARGS+=("-e DISPLAY")
DOCKER_ARGS+=("-e NVIDIA_VISIBLE_DEVICES=all")
DOCKER_ARGS+=("-e NVIDIA_DRIVER_CAPABILITIES=all")
DOCKER_ARGS+=("-e USER")
DOCKER_ARGS+=("-v /dev:/dev")
DOCKER_ARGS+=("-e FASTRTPS_DEFAULT_PROFILES_FILE=/usr/local/share/middleware_profiles/rtps_udp_profile.xml")
DOCKER_ARGS+=("-v /proc/device-tree/compatible:/proc/device-tree/compatible")
DOCKER_ARGS+=("-v /proc/device-tree/chosen:/proc/device-tree/chosen")
DOCKER_ARGS+=("-v /tmp/.X11-unix:/tmp/.X11-unix")
DOCKER_ARGS+=("-v $HOME/.Xauthority:/home/admin/.Xauthority")
DOCKER_ARGS+=("-v /usr/bin/tegrastats:/usr/bin/tegrastats")
DOCKER_ARGS+=("-v /usr/lib/aarch64-linux-gnu/tegra:/usr/lib/aarch64-linux-gnu/tegra")
DOCKER_ARGS+=("-v /usr/src/jetson_multimedia_api:/usr/src/jetson_multimedia_api")
DOCKER_ARGS+=("-v /usr/share/vpi3:/usr/share/vpi3")
DOCKER_ARGS+=("-v /etc/localtime:/etc/localtime:ro")

if [[ $(getent group jtop) ]]; then
    DOCKER_ARGS+=("-v /run/jtop.sock:/run/jtop.sock:ro")
    JETSON_STATS_GID="$(getent group jtop | cut -d: -f3)"
    DOCKER_ARGS+=("--group-add $JETSON_STATS_GID")
fi

print_info "Running $CONTAINER_NAME"
docker run \
    ${DOCKER_ARGS[@]} \
    --name "$CONTAINER_NAME" \
    --user="admin" \
    --entrypoint /usr/local/bin/scripts/ros_entrypoint.sh \
    tzushiancavedu/orinnano_amr:r36.3.0 \
    /bin/bash
