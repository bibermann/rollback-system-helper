# BRTFS backup/restore on Arch linux

## Setup

Note: This section is not clean yet, these are just some notes.

https://www.dwarmstrong.org/archlinux-install/
- https://www.dwarmstrong.org/btrfs-snapshots-rollbacks/

https://wiki.archlinux.org/title/snapper

Requirement: inotify-tools

Documented as an optional dependency, 
and here https://github.com/Antynea/grub-btrfs#manual-installation
and here https://www.reddit.com/r/archlinux/comments/12zbvzg/comment/jhrus41/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button

In the blog
```bash
sudo systemctl enable --now grub-btrfs.path
```

is used, it must now be
```bash
sudo systemctl enable --now grub-btrfsd.service
```

### Docker

Note: Replace `YOUR_BTRFS_UUID` with the actual UUID.

Create BTRFS subvolume for docker data:
```bash
UUID=YOUR_BTRFS_UUID # find UUID using `lsblk -f`

# mount file system containing root subvolume
btrfs subvolume list /
sudo mkdir -p /mnt/btrfs
sudo mount UUID=$UUID /mnt/btrfs

# create subvolume within file system
sudo btrfs subvolume create /mnt/btrfs/@docker
sudo btrfs subvolume list /

# create docker subvolume
sudo mkdir -p /var/lib/docker
# this should be equivalent:
#sudo mkdir -p /mnt/btrfs/@/var/lib/docker
sudo btrfs subvolume create /mnt/btrfs/@docker
```

Add mount point to `/etc/fstab`:
```bash
# <file system>       <mount point>    <type>  <options>                                       <dump>  <pass>
# [...]
UUID=YOUR_BTRFS_UUID  /var/lib/docker  btrfs   subvol=/@docker,defaults,noatime,compress=zstd  0       0
```

Reboot, then:
```bash
# install docker
paru docker compose
systemctl enable docker # necessary?
systemctl start docker
sudo usermod -aG docker $USER
```

More information: 
- [Arch Wiki » Btrfs » Subvolumes](https://wiki.archlinux.org/title/Btrfs#Subvolumes)
- [Arch Wiki » Snapper » Suggested filesystem layout](https://wiki.archlinux.org/title/Snapper#Suggested_filesystem_layout)

## Rollback

`rollback-system.sh` is meant to be used from within a different system,
e.g. Ubuntu booted from USB.
