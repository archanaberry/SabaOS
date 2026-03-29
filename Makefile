SYSROOT ?= sysroot
ISO ?= /tmp/fishix.iso
DISK ?= fishix.qcow2

# Kernel Repository Integration
FISHIX_REPO = https://github.com/archanaberry/Fishix
FISHIX_DIR = $(abspath ..)/Fishix

NPROC := $(patsubst -j%,%,$(filter -j%,$(MAKEFLAGS)))
ifeq ($(NPROC),)
NPROC := 1
endif

.PHONY: all kernel run iso-clean setup-kernel terminal

all: kernel

run: ovmf/OVMF.fd $(ISO) $(DISK)
	qemu-system-x86_64 -cdrom $(ISO) -m 16G -serial stdio \
		-no-reboot -no-shutdown -smp 1 -machine q35 -cpu host \
		-bios ovmf/OVMF.fd \
        -drive file=$(DISK),if=virtio \
		-netdev user,id=net0 -device virtio-net,netdev=net0 \
		-device qemu-xhci,id=xhci \
		-device usb-kbd,id=usbkbd -device usb-mouse,id=usbmouse \
 		-enable-kvm -display sdl,gl=on -s
#		-trace usb_xhci_* -D /tmp/fishix-qemu-xhci.log \
#		-object filter-dump,id=f1,netdev=net0,file=dump.pcap

# Automatically clone kernel if missing and ensure it is symlinked
setup-kernel:
	@if [ ! -d "$(FISHIX_DIR)" ]; then \
		echo "Fishix kernel not found in $(FISHIX_DIR). Cloning..."; \
		git clone $(FISHIX_REPO) $(FISHIX_DIR); \
	fi
	@if [ ! -L kernel ]; then \
		if [ -d kernel ]; then \
			if [ ! -d kernel/.git ]; then \
				echo "Backing up existing kernel directory..."; \
				mv kernel kernel_backup; \
			fi; \
		fi; \
		echo "Creating symlink to $(FISHIX_DIR)..."; \
		ln -sf $(FISHIX_DIR) kernel; \
	fi

kernel: setup-kernel kernel/build
	cd kernel && meson compile --jobs $(NPROC) -C build

kernel/build:
	cd kernel && meson setup build

limine:
	git clone --depth 1 --branch v10.x-binary https://codeberg.org/Limine/Limine limine
	cd limine && make

ovmf/OVMF.fd:
	mkdir -p ovmf
	cd ovmf && curl -o OVMF.fd https://retrage.github.io/edk2-nightly/bin/RELEASEX64_OVMF.fd

$(ISO): kernel limine
	./distro-files/makeiso.sh $(ISO) $(SYSROOT)

$(DISK):
	qemu-img create -f qcow2 $(DISK) 16G

iso-clean:
	rm -rf $(ISO)

# Launch in Kitty terminal with Fish shell
terminal: setup-kernel
	kitty --hold fish -c "echo '--- Fishix Dev Environment ---'; make; exec fish"

# Alias for ease of use
fish: terminal
