FROM quay.io/centos-bootc/centos-bootc:stream10 as bootc

FROM docker.io/archlinux:latest AS builder

RUN <<'EOF'
set -eoux pipefail
pacman --noconfirm -Syu arch-install-scripts ostree
sed -i -e 's|^NoExtract.*||g' /etc/pacman.conf
mkdir /newroot
pacstrap -K /newroot \
    amd-ucode \
    base \
    bash-completion \
    btrfs-progs \
    buildah \
    clevis \
    composefs \
    cryptsetup \
    distrobox \
    dosfstools \
    dracut \
    ffmpeg \
    flatpak \
    fzf \
    grub \
    gptfdisk \
    htop \
    imagemagick \
    intel-media-driver \
    intel-media-sdk \
    intel-ucode \
    just \
    libva-utils \
    linux \
    linux-firmware \
    mesa \
    mokutil \
    networkmanager \
    opensc \
    ostree \
    p11-kit \
    pam-u2f \
    pcsclite \
    pcsc-tools \
    pipewire \
    pipewire-alsa \
    pipewire-jack \
    pipewire-pulse \
    plymouth \
    podman \
    polkit \
    sbsigntools \
    skopeo \
    squashfs-tools \
    sudo \
    tmux \
    tree \
    vdpauinfo \
    vim \
    vpl-gpu-rt \
    vulkan-intel \
    vulkan-radeon \
    vulkan-virtio \
    wireguard-tools \
    wireplumber \
    xfsprogs \
    yubikey-manager

export DRACUT_NO_XATTR=1
KVER="$(pacman -r /newroot -Q linux | cut -d ' ' -f2)"
KVER="${KVER/.a/-a}"
arch-chroot /newroot dracut --no-hostonly --kver $KVER --reproducible --nostrip --zstd --add ostree -f "/lib/modules/$KVER/initramfs.img"
chmod 0600 /newroot/lib/modules/$KVER/initramfs.img
EOF

RUN <<'EOF'
for dir in home mnt opt srv; do
rmdir /newroot/var/$dir || true
mv /newroot/$dir /newroot/var/
ln -s var/$dir /newroot/$dir
done

mv /newroot/root /newroot/var/roothome
ln -s var/roothome /newroot/root

cat > /newroot/usr/lib/tmpfiles.d/ostree-integration.conf <<'EEOF'
d /var/log/journal 0755 root root -
L /var/home - - - - ../sysroot/home
d /var/opt 0755 root root -
d /var/srv 0755 root root -
d /var/roothome 0700 root root -
d /var/usrlocal 0755 root root -
d /var/usrlocal/bin 0755 root root -
d /var/usrlocal/etc 0755 root root -
d /var/usrlocal/games 0755 root root -
d /var/usrlocal/include 0755 root root -
d /var/usrlocal/lib 0755 root root -
d /var/usrlocal/man 0755 root root -
d /var/usrlocal/sbin 0755 root root -
d /var/usrlocal/share 0755 root root -
d /var/usrlocal/src 0755 root root -
d /var/mnt 0755 root root -
d /run/media 0755 root root -
EEOF

cat > /newroot/usr/lib/ostree/prepare-root.conf <<'EEOF'
[composefs]
enabled = yes
[sysroot]
readonly = true
EEOF

mv /newroot/var/lib/pacman /newroot/usr/lib/pacman
sed -i 's|^#DBPath.*|DBPath      = /usr/lib/pacman|' /newroot/etc/pacman.conf

rm -rf /newroot/var/
rm -rf /newroot/usr/etc
rm -rf /newroot/boot
mkdir -p /newroot/boot
mkdir -p /newroot/var/tmp
chmod 1777 /newroot/var/tmp
EOF

# COPY --from=bootc /usr/share/doc/bootc-base-imagectl/ /newroot/usr/share/doc/bootc-base-imagectl/
# COPY --from=bootc /usr/libexec/bootc-base-imagectl /newroot/usr/bin/bootc-base-imagectl
COPY --from=bootc /usr/bin/bootc /newroot/usr/bin/
COPY --from=bootc /usr/lib/bootc /newroot/usr/lib/bootc

RUN <<'EOF'
set -eoux pipefail
mkdir -p /newroot/sysroot/ostree
ln -s sysroot/ostree /newroot/ostree
ostree --repo=/repo init --mode=bare
ostree --repo=/repo commit --orphan --tree=dir=/newroot --no-xattrs
rm /repo/.lock
mv /repo /newroot/sysroot/ostree/
EOF

FROM scratch
COPY --from=builder /newroot /
LABEL ostree.bootable 1
LABEL containers.bootc 1

RUN bootc container lint --fatal-warnings
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
