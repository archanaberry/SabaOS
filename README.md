<div align="center">

# 🌊 Saba OS — Sameko Saba 🐟🐈
### by Fishix (Wayland)

**An independent experimental LINUX-like operating system**

![status](https://img.shields.io/badge/status-experimental-orange)
![kernel](https://img.shields.io/badge/kernel-Fishix-blue)
![display](https://img.shields.io/badge/display-Wayland-purple)
![architecture](https://img.shields.io/badge/arch-x86__64-lightgrey)
![license](https://img.shields.io/badge/license-MIT-green)

</div>

---

## ✨ About

**Saba OS — Sameko Saba** is an **independent operating system** built on the **Fishix kernel**, designed to explore modern desktop architecture with a Wayland-first approach.

Saba OS is **NOT a Linux distribution** and **NOT based on Void Linux or any existing distro**.

The system is developed as its own ecosystem, including:

- custom system layout
- independent userspace direction
- future native package manager (**sabapm**)
- experimental LINUX-like environment

External systems may be used temporarily for bootstrapping during development only.

---
![](docs/sameko.png)
---

## 🧱 System Overview

| Component | Technology |
|-----------|------------|
| Kernel | Fishix |
| OS Type | Independent LINUX-like |
| Display Protocol | Wayland |
| Bootloader | Limine |
| Architecture | x86_64 |
| Language | C++ / ASM |
| Graphics | DRM + Framebuffer |
| Input | USB (xHCI) + PS/2 |
| Networking | virtio-net (UDP) |

---

## Essential coreutils
1. fish shell
2. kitty
3. dinit
4. weston
5. wayland
6. sway
7. yad
8. musl

---

## 📂 Repository Structure

```

SabaOS/
├── kernel/          # Fishix kernel source
├── distro-files/    # System image builder & root layout
├── docs/            # Technical documentation
├── Makefile         # Unified build workflow
├── dev.fish         # Developer helper tools
└── qemu-prof.sh     # QEMU execution script

````

### Key Areas

- **kernel/** — core operating system kernel
- **distro-files/** — OS construction tools
- **docs/wayland/** — Wayland integration research
- **docs/drm/** — graphics subsystem
- **docs/dma/** — memory management notes

---

## 🚀 Features (Current)

- Independent OS architecture
- Wayland-oriented graphics design
- DRM graphics subsystem
- Virtual filesystem (VFS, tmpfs, procfs)
- ELF userspace execution
- USB & PS/2 input devices
- virtio networking
- Runs on real hardware and QEMU

> SMP support is not yet implemented (single-core scheduler).

---

## 🔧 Building

### Build system

```bash
make -j$(nproc)
````

### Build ISO & run

```bash
SYSROOT=sysroot ISO=/tmp/sabaos.iso make run
```

---

## 🧪 Development Bootstrap (Temporary)

During development, an external userspace may be used **only as a bootstrap environment**.

This does **not** represent the final Saba OS design.

Future releases will introduce:

```
sabapm — native Saba OS package manager
```

---

## 🎯 Project Goals

* Create a fully independent desktop OS
* Develop a Wayland-native environment
* Replace legacy Linux assumptions
* Build a clean experimental UNIX platform
* Introduce native package ecosystem (sabapm)

---

## 📸 Progress

![Screenshot](/screenshot.png?raw=true "Saba OS progress")

---

## 🤝 Contributing

Saba OS is an experimental research project.

Contributions, testing, and architectural discussions are welcome.

---

## 📜 License

MIT License — see [LICENSE](LICENSE)

Attributions listed in [NOTICE.md](NOTICE.md).

---

<div align="center">

**Saba OS — Sameko Saba 🌊**
Independent system powered by Fishix

</div>
