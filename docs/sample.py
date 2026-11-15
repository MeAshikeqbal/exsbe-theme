#!/usr/bin/env python3
"""Sample data for the README screenshots (docs/shoot.sh).

Writes what `exsbe-pve status`, `exsbe-jellyfin status` and `podman ps` would print, for a
made-up home lab, so the screenshots show every widget populated without any real names,
addresses or projects. Times are relative to now. Usage: sample.py OUT_DIR
"""
import json
import subprocess
import sys
import time
from pathlib import Path

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
now = int(time.time())
GiB, TiB = 1 << 30, 1 << 40

# --- Proxmox ------------------------------------------------------------------------------------
nodes = [
    {"name": "pve-1", "status": "online", "ip": "192.0.2.11", "cpu": 0.12, "mem": 18.4 * GiB, "maxmem": 47 * GiB, "uptime": 9 * 86400},
    {"name": "pve-2", "status": "online", "ip": "192.0.2.12", "cpu": 0.31, "mem": 9.6 * GiB, "maxmem": 15.5 * GiB, "uptime": 9 * 86400},
    {"name": "pve-3", "status": "online", "ip": "192.0.2.13", "cpu": 0.05, "mem": 6.2 * GiB, "maxmem": 15.5 * GiB, "uptime": 2 * 86400},
]
G = lambda vmid, name, node, typ, mem, maxmem, cpu=0.02, tags="", status="running": {
    "vmid": vmid, "name": name, "type": typ, "node": node, "status": status, "cpu": cpu if status == "running" else 0,
    "mem": mem * GiB if status == "running" else 0, "maxmem": maxmem * GiB, "uptime": 3 * 86400 if status == "running" else 0,
    "tags": tags, "template": False}
guests = [
    G(100, "adguard", "pve-1", "lxc", 0.2, 0.5, 0.01, "dns;helper"),
    G(101, "proxy", "pve-1", "lxc", 0.3, 1, 0.01, "nginx;helper"),
    G(102, "vaultwarden", "pve-1", "lxc", 0.1, 0.5, 0.00, "vault;helper"),
    G(103, "home-assistant", "pve-1", "qemu", 2.9, 4, 0.04, "automation"),
    G(104, "immich", "pve-1", "lxc", 5.1, 6, 0.08, "photos;helper"),
    G(105, "paperless", "pve-1", "lxc", 1.4, 2, 0.01, "docs;helper"),
    G(200, "jellyfin", "pve-2", "lxc", 3.2, 4, 0.22, "media;helper"),
    G(201, "arr", "pve-2", "lxc", 2.1, 6, 0.03, "media;helper"),
    G(202, "frigate", "pve-2", "lxc", 3.9, 5, 0.17, "nvr;helper"),
    G(203, "minecraft", "pve-2", "lxc", 0, 8, tags="games", status="stopped"),
    G(300, "gitea", "pve-3", "lxc", 0.6, 2, 0.01, "git;helper"),
    G(301, "grafana", "pve-3", "lxc", 0.9, 2, 0.02, "monitoring;helper"),
    G(302, "win11", "pve-3", "qemu", 0, 8, tags="desktop", status="stopped"),
]
storage = [
    {"name": "pbs", "type": "pbs", "used": 412 * GiB, "total": 1.8 * TiB, "status": "available"},
    {"name": "pve-1/local-zfs", "type": "zfspool", "used": 96 * GiB, "total": 449 * GiB, "status": "available"},
    {"name": "pve-2/local-zfs", "type": "zfspool", "used": 61 * GiB, "total": 110 * GiB, "status": "available"},
    {"name": "pve-2/tank", "type": "zfspool", "used": 2.9 * TiB, "total": 3.6 * TiB, "status": "available"},
    {"name": "pve-3/local-zfs", "type": "zfspool", "used": 18 * GiB, "total": 220 * GiB, "status": "available"},
]
pve = {
    "cluster": "homelab", "quorate": True, "endpoint": "https://192.0.2.11:8006",
    "nodes": nodes, "guests": guests, "storage": storage,
    # a failed run that a later run fixed: shown as a warning, not an outage
    "backup": {"last": now - 5 * 3600, "lastStatus": "OK",
               "failed": [{"node": "pve-2", "upid": "UPID:sample", "status": "job errors", "id": "", "end": now - 7 * 3600}]},
    "pbs": {"url": "https://192.0.2.20:8007", "stores": [{"name": "backups", "used": 412 * GiB, "total": 1.8 * TiB}],
            "jobs": [{"kind": "verify", "id": "v-1", "store": "backups", "state": "OK", "end": now - 16 * 3600, "next": now + 8 * 3600},
                     {"kind": "prune", "id": "p-1", "store": "backups", "state": "OK", "end": now - 40 * 60, "next": now + 20 * 60}],
            "failed": []},
}
(out / "pve.json").write_text(json.dumps(pve))
(out / "pve.out").write_text(json.dumps(pve) + "\n\n@@TS@@\nRunning\n")

# --- Jellyfin -----------------------------------------------------------------------------------
def poster(name, top, bottom, title):
    path = out / f"{name}.png"
    subprocess.run(["magick", "-size", "210x315", f"gradient:{top}-{bottom}", "-gravity", "south", "-fill", "#f2f2f4",
                    "-font", "Inter-Variable", "-pointsize", "22", "-annotate", "+0+28", title, str(path)],
                   check=False, capture_output=True)
    return f"file://{path}"

jellyfin = {
    "web": "https://jellyfin.example", "transcoding": 1, "online": ["alex", "sam", "kids"],
    "sessions": [
        {"id": "s1", "itemId": "i1", "title": "The Long Coast", "subtitle": "2023 · Documentary",
         "image": poster("poster-coast", "#3b5770", "#14161c", "The Long Coast"),
         "user": "alex", "device": "Living room TV", "client": "Jellyfin Android TV", "paused": False,
         "position": 2470, "runtime": 5940, "method": "DirectPlay", "transcode": None,
         "source": {"video": "HEVC 4K HDR", "audio": "EAC3 5.1", "bitrate": "38 Mbit/s", "container": "mkv", "subtitle": ""},
         "where": {"kind": "lan", "label": "Home", "detail": "living-room-tv"}},
        {"id": "s2", "itemId": "i2", "title": "Night Shift", "subtitle": "S02E05 · The Quiet Hours",
         "image": poster("poster-night", "#5a3f63", "#17141c", "Night Shift"),
         "user": "sam", "device": "Phone", "client": "Jellyfin iOS", "paused": False,
         "position": 912, "runtime": 2710, "method": "Transcode",
         "transcode": {"video": "H264", "audio": "AAC", "bitrate": "6 Mbit/s", "hw": "nvenc", "fps": 92,
                       "reasons": ["VideoCodecNotSupported", "ContainerBitrateExceedsLimit"]},
         "source": {"video": "HEVC 1080p", "audio": "AC3 5.1", "bitrate": "14 Mbit/s", "container": "mkv", "subtitle": "English (SRT)"},
         "where": {"kind": "tailscale", "label": "Tailscale", "detail": "sam-phone · away"}},
    ],
}
(out / "jellyfin.json").write_text(json.dumps(jellyfin))

# --- Podman -------------------------------------------------------------------------------------
def C(name, image, state, status, code=0, ports=(), compose=None, box=False, age=3600):
    labels = {}
    if compose:
        labels["com.docker.compose.project"] = compose
    if box:
        labels["manager"] = "distrobox"
    return {"Id": name + "-id", "Names": [name], "Image": image, "State": state, "Status": status, "ExitCode": code,
            "StartedAt": now - age, "ExitedAt": (now - age) if state == "exited" else -62135596800,
            "Ports": [{"host_port": h, "container_port": c} for h, c in ports] or None, "Labels": labels,
            "PodName": "", "IsInfra": False}
podman = [
    C("blog-web", "localhost/blog-web:latest", "running", "Up 3 hours", ports=[(8080, 8080)], compose="blog", age=3 * 3600),
    C("blog-db", "docker.io/library/postgres:17-alpine", "running", "Up 3 hours (healthy)", ports=[(5432, 5432)], compose="blog", age=3 * 3600),
    C("blog-cache", "docker.io/library/redis:7-alpine", "running", "Up 3 hours", ports=[(6379, 6379)], compose="blog", age=3 * 3600),
    C("minio", "quay.io/minio/minio:latest", "exited", "Exited (1) 20 minutes ago", code=1, ports=[(9000, 9000), (9001, 9001)], age=20 * 60),
    C("pg-test", "docker.io/library/postgres:18-alpine", "exited", "Exited (0) 2 days ago", ports=[(55432, 5432)], age=2 * 86400),
    C("fedora-dev", "registry.fedoraproject.org/fedora-toolbox:43", "running", "Up 5 hours", box=True, age=5 * 3600),
    C("arch", "docker.io/library/archlinux:latest", "exited", "Exited (143) 1 week ago", code=143, box=True, age=7 * 86400),
]
(out / "podman.out").write_text(json.dumps(podman) + "\n@@PODS@@\n[]\n")
print(out)
