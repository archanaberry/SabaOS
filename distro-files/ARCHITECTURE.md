# SabaOS Architectural Guide
## Kernel-Agnostic Userspace Design (Fishix Edition)

---

## 🎯 Design Philosophy

**Premise:** SabaOS runs on Fishix kernel (80-95% Linux compatible), NOT bare Linux.

**Strategy:** Build userspace that works WITH Fishix's nature, not against it.

### ❌ Wrong Approach
```
SabaOS = Linux tools + Linux thinking + hope Fishix acts like Linux
          ↓ Result: Constant compatibility hacks
```

### ✅ Correct Approach  
```
SabaOS = POSIX personality layer + Linux compatibility as bonus
         ↓ Result: Sustainable, kernel-agnostic design
```

---

## 🐟 Why BusyBox 1.36.x for SabaOS

### Version Selection Rationale

| Aspect | Why 1.36.x | Not 1.37+ | Not <1.32 |
|--------|------------|----------|---------|
| **Stability** | LTS, proven in Alpine | Beta assumptions | Old, limited Fishix knowledge |
| **musl support** | Excellent testing | Less tested | Minimal |
| **Modularity** | Can disable Linux-only | Hardcoded Linux | Fewer options |
| **Size** | ~1.5-2.5 MB static | Bloat creep | Minimal but old |
| **Fishix compat** | Sweet spot | Over-optimized Linux | Minimal compat |

### What BusyBox Actually Is

BusyBox is a **Swiss Army Knife for embedded systems**:
- 📦 **Userspace tools** (ls, cp, grep, etc.)
- 🐚 **Shell** (ash - POSIX shell)
- 🔧 **Init system** (PID 1 replacement)
- 🔌 **Network utilities** (ping, wget, ifconfig)

❌ NOT: Linux kernel replacement  
❌ NOT: GLIBC dependency  
✅ YES: Works with any Unix-like kernel

---

## 🧬 SabaOS BusyBox Architecture

### Core Principle
> "Treat BusyBox as a POSIX personality layer, not a Linux toolbox"

### What We Enable (Portable POSIX)

```
✅ ENABLED (Fishix-safe)
├── Archive tools (tar, gzip, cpio)
├── Core utilities (cp, ls, grep, sed, awk)
├── Process management (ps, kill, top)
├── Networking (ping, wget, ifconfig, route)
├── Text processing (sed, awk, grep)
├── Shell (ash - POSIX)
└── Init system (PID 1)

❌ DISABLED (Linux-specific)
├── Console/TTY tools (setfont, loadkmap - tty-only Linux)
├── Kernel modules (insmod, modprobe - no modules in Fishix)
├── Linux syslog (CONFIG_FEATURE_SYSLOGD_CFG)
├── Linux /proc tools (sysctl, mdev)
├── SELINUX/security (Linux-only)
├── Linux ioctl features (tun, HID, etc.)
└── Login/user utilities (utmp/wtmp - Linux accounting)
```

### Fishix Hardware Assumption

Fishix kernel provides:
- ✅ POSIX syscalls (read, write, open, etc.)
- ✅ Process management (/proc for ps/top if available)
- ✅ Network stack (if configured)
- ✅ Basic filesystem

Fishix kernel **might not** provide:
- ❌ /sys filesystem (Linux-specific)
- ❌ Linux ioctl set (tty, net, storage)
- ❌ Netlink sockets (Linux IPC)
- ❌ Linux module system

---

## 🔧 Using `sabaos_busybox.defconfig`

### Step 1: Download BusyBox 1.36.x

```bash
cd /workspaces/SabaOS/sources/
wget https://busybox.net/downloads/busybox-1.36.1.tar.bz2
tar -xjf busybox-1.36.1.tar.bz2
cd busybox-1.36.1
```

### Step 2: Apply SabaOS Profile

```bash
# From distro-files directory
cp ../distro-files/sabaos_busybox.defconfig ./.config

cd busybox-1.36.1
cp /path/to/sabaos_busybox.defconfig .config

# Verify the config
make oldconfig
```

Or use our profile directly:

```bash
# Load SabaOS profile then customize
make KCONFIG_CONFIG=/path/to/sabaos_busybox.defconfig menuconfig
```

### Step 3: Build Static Binary

```bash
CFLAGS="-O2 -static" make -j$(nproc)

# Result: ./busybox (single binary)
ls -lh busybox
# -rwxr-xr-x  1 kb  kb  1.8M busybox (example size)
```

### Step 4: Install to Chroot

```bash
make CONFIG_PREFIX=/mnt/saba_os install
```

This creates:
```
/mnt/saba_os/
├── bin/
│   └── busybox → symlinks to utilities
├── sbin/
│   ├── init → busybox
│   └── halt/poweroff/reboot → busybox
└── usr/
    └── bin/ → symlinks
```

---

## 📊 Defconfig Breakdown

### ✅ Always Enabled (POSIX Core)

```bash
# Core utilities - portable across kernels
CONFIG_CP=y
CONFIG_LS=y
CONFIG_GREP=y
CONFIG_FIND=y
CONFIG_SED=y
CONFIG_AWK=y
CONFIG_TAR=y

# Process tools - work with any /proc
CONFIG_PS=y
CONFIG_TOP=y
CONFIG_KILL=y

# Network - pure socket-based
CONFIG_PING=y
CONFIG_WGET=y
CONFIG_TELNET=y
```

### ❌ Always Disabled (Linux Ioctl/Syscall)

```bash
# These call specific Linux ioctl()
CONFIG_SETFONT=n           # ioctl(KDSETFONT)
CONFIG_LOADKMAP=n          # ioctl(KDSKBMAP)
CONFIG_CHVT=n              # ioctl(VT_ACTIVATE)

# These need Linux /proc layout
CONFIG_SYSLOG=n            # klogctl() syscall
CONFIG_LSMOD=n             # /proc/modules parsing
CONFIG_MDEV=n              # /proc/devices parsing

# These need Linux user accounting
CONFIG_FEATURE_UTMP=n      # utmp file format
CONFIG_FEATURE_WTMP=n      # wtmp file format
```

### 🔄 Depends on Fishix Capabilities

```bash
# ✅ Enable if Fishix has /proc:
CONFIG_PS=y               # reads /proc/*/stat
CONFIG_TOP=y              # reads /proc/stat
CONFIG_FREE=y             # reads /proc/meminfo
CONFIG_UPTIME=y           # reads /proc/uptime

# ⚠️  Disable if Fishix lacks /proc:
# Just remove CONFIG_PS, CONFIG_TOP, etc.
```

---

## 🚀 Three-Phase Roadmap for SabaOS

### Phase 1: Alive (Bootable Kernel + Userspace)

**Goal:** SabaOS boots to a shell prompt

**Components:**
- ✅ Fishix kernel
- ✅ musl libc (static)
- ✅ BusyBox 1.36.x (static, minimal config)
- ✅ ash shell
- ✅ Init system (busybox init)

**Deliverable:**
```
Fishix Kernel v0.1
    ↓
musl libc 1.2.5 (static)
    ↓
BusyBox 1.36.1 (static, ~1.8 MB)
    ├── /bin/busybox → symlinks
    ├── /sbin/init
    └── /bin/ash
    ↓
SabaOS v0.1 Bootable Image
```

**System looks like:**
```bash
# Boot sequence
Fishix Kernel init
  ↓
/sbin/init (busybox init from /etc/inittab)
  ↓
spawn /bin/ash (shell)
  ↓
prompt> _
```

**Success metrics:**
- Kernel boots without panic
- busybox loads PID 1 successfully
- Shell prompt appears
- Basic commands work (ls, cp, grep, etc.)

---

### Phase 2: Linux Illusion (Compatibility Layer)

**Goal:** BusyBox commands that expect Linux env still work

**Problem this solves:**

Many BusyBox utilities check for Linux-specific files/ioctls:
```c
// Example: ps command
#ifdef __linux__
    parse /proc/*/stat      // Linux layout
#else
    fallback_method()       // POSIX alternative
#endif
```

Fishix is 80-95% compatible but not 100%.

**Solution:** Shimming layer

**What we build:**

1. **Pseudo /proc generator**
   ```bash
   # If Fishix provides native /proc:
   use it directly
   
   # If Fishix doesn't:
   create /proc via tmpfs
   populate from Fishix-specific syscalls
   ```

2. **Basic ioctl shim**
   ```bash
   # Fishix syscall → map to Linux expectation
   Example: Fishix tty_getwinsize() → expose as Linux TIOCGWINSZ
   ```

3. **Pseudo /dev populated**
   ```bash
   /dev/null, /dev/zero, /dev/random
   /dev/tty, /dev/console (if Fishix provides)
   ```

**Deliverable:**
```
BusyBox + Compatibility Layer
├── Pseudo /proc (if needed)
├── ioctl shim (if needed)
└── Pseudo /dev (basic)
```

**Example: Custom /etc/inittab**

```bash
::sysinit:/sbin/rc.init     # Our init script
::respawn:/sbin/getty tty0  # If Fishix tty works
::ctrlaltdel:/sbin/init 6   # Reboot on Ctrl-Alt-Del
```

---

### Phase 3: Identity (SabaOS Native Tooling)

**Goal:** SabaOS has own personality, not just "Linux clone"

**Components we add:**

1. **Saba Utilities** (SabaOS-specific tools)
   ```bash
   /sbin/saba-init          # Replace busybox init
   /sbin/saba-mount         # Custom mount helper
   /sbin/saba-config        # Configuration manager
   /bin/saba-shell          # Fish-compatible shell
   ```

2. **Fish Package Manager** (.fpk format)
   ```bash
   /bin/fpk                 # Package manager
   /etc/fpk.conf            # Package config
   /var/lib/fpk/            # Package database
   ```

3. **Berry Language Support**
   ```bash
   /usr/bin/berry           # Berry interpreter (small, fast)
   /usr/lib/berry/          # Berry stdlib
   
   # Use for scripts instead of bash
   ```

4. **SabaOS-specific /etc/**
   ```bash
   /etc/saba/               # SabaOS config
   /etc/inittab.saba        # Custom init
   /etc/profile.saba        # Shell env
   /etc/hostname            # System identity
   ```

**Deliverable:**
```
SabaOS v1.0 Full System
├── Kernel: Fishix (native)
├── Libc: musl (native)
├── Utilities: BusyBox (POSIX subset)
├── SabaOS utilities (native C)
├── Package manager (fpk)
└── Shell: Choice of ash or Fish
```

---

## 🔑 Key Insights for SabaOS Success

### ✅ DO

1. **Think POSIX first**
   - Count on: open, read, write, fork, exec
   - Don't count on: specific Linux ioctls, /sys

2. **Treat BusyBox as POSIX provider**
   - Enable based on "will it work on Unix?"
   - Not "is this feature cool?"

3. **Embrace Fishix differences**
   - Don't hack around them
   - Let Fishix be Fishix

4. **Use static linking**
   - Single busybox binary
   - No glibc ABI dependencies
   - Easy debugging

### ❌ DON'T

1. **Don't try to make Fishix look like Linux**
   - It's not. Don't pretend.
   - Users will know.

2. **Don't bloat BusyBox**
   - Every feature = more Linux assumptions
   - Keep minimal, focused

3. **Don't skip the shimming layer**
   - Phase 2 (Linux illusion) is critical
   - Smooth the rough edges

4. **Don't fork BusyBox**
   - Use defconfig wisely
   - Upstream compatibility = long-term win

---

## 📈 Size Targets

| Component | Size (static) | Notes |
|-----------|---------------|-------|
| musl libc | ~600 KB | Minimal C library |
| BusyBox 1.36 | ~1.5-2.5 MB | Full POSIX setup with init |
| Fishix kernel | 5-15 MB | Highly depends on config |
| **Total** | **~8-20 MB** | Bootable SabaOS v0.1 |

For comparison:
- Alpine Linux: ~150 MB (musl + busybox + pkgs)
- SabaOS: **20 MB** objective (ultra-minimal)

---

## 🛠️ Testing BusyBox Config

### Before building full system:

```bash
# Test just the busybox portion
cd /tmp/test-busybox
cp /workspaces/SabaOS/distro-files/sabaos_busybox.defconfig .config
cd busybox-1.36.1

# Build and test
CFLAGS="-static -O2" make -j4
./busybox --help | head -20

# Test key commands
./busybox ls
./busybox grep --help
./busybox ash --version

# Verify no Linux-only features got compiled
ldd ./busybox   # Should say "not a dynamic executable"
file ./busybox  # Should say "statically linked"
```

---

## 🔗 Next Steps

1. **Validate defconfig** with BusyBox 1.36.1
2. **Test boot sequence** with kernel selector
3. **Document Fishix ABI** (phase 2 prep)
4. **Build compat shim** (phase 2)
5. **Plan SabaOS utilities** (phase 3)

---

## 📚 References

- **BusyBox 1.36.x**: https://busybox.net/
- **musl libc**: https://musl.libc.org/
- **Fishix Kernel**: https://github.com/tunis4/Fishix
- **POSIX.1-2017**: https://pubs.opengroup.org/onlinepubs/9699919799/

---

**Document Version:** 1.0  
**SabaOS Phase:** 1 (Alive)  
**Last Updated:** March 30, 2026  
**Philosophy:** Kernel-agnostic, POSIX-first, sustainable
