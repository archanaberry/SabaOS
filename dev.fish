#!/usr/bin/fish

# Check for kitty
if not type -q kitty
    echo "Error: kitty not found. Please install it."
    exit 1
end

# Check for kernel
if not test -d ../Fishix
    echo "Fishix kernel missing in ../Fishix. Running setup..."
    make setup-kernel
end

# Launch kitty with fish shell
echo "Opening Fishix Dev Environment in Kitty..."
kitty --hold fish -c "echo '--- Fishix Development Shell ---'; make all; exec fish"
