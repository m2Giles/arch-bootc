set unstable

just := just_executable()
podman := require('podman')
sudoif := if `id -u` != '0' { 'sudo' } else { '' }

build:
    {{ sudoif }} {{ podman }} build --security-opt label=disable --security-opt seccomp=unconfined --cap-add=all --device=/dev/fuse -t archlinux-bootc -f Containerfile .
