# Linux Mint VM with noVNC

This project runs the official Linux Mint Cinnamon ISO in a QEMU virtual
machine and provides its display in a browser using noVNC. The virtual disk
and downloaded ISO are stored in a persistent Docker volume.

## Start

```sh
docker compose up --build -d
```

The first start downloads the Linux Mint 22.3 ISO (about 3 GB) and verifies
its SHA-256 checksum against the Linux Mint mirror checksum file. Allow a few
minutes for the download.

Open [http://localhost:6080/vnc.html?autoconnect=true](http://localhost:6080/vnc.html?autoconnect=true).
In GitHub Codespaces, open forwarded port **6080** in the Ports panel and keep
its visibility **Private**. noVNC does not add its own login, so do not expose
this port publicly.

## Install Mint

The first boot opens the Mint live desktop. Start **Install Linux Mint** from
the desktop and install it to the virtual disk. When installation finishes,
restart the VM; QEMU boots the installed system from disk before falling back
to the ISO.

## Configure

Set these environment variables before starting Compose to adjust resources:

| Variable | Default | Description |
| --- | --- | --- |
| `MEMORY_MB` | `4096` | VM memory in MiB |
| `CPUS` | `2` | Number of virtual CPUs |
| `DISK_SIZE` | `64G` | Capacity of the VM's virtual disk on first start |
| `NOVNC_PORT` | `6080` | Host port for the noVNC web interface |

The VM uses KVM when `/dev/kvm` is available; otherwise it falls back to slower
software emulation. Changes to the VM disk persist in the `mint-data` Docker
volume. Removing that volume deletes the VM and its downloaded ISO.

To stop the VM, run `docker compose down`.
