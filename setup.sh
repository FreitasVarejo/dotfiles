#!/bin/bash

# Ensure stow is installed
if ! command -v stow &> /dev/null; then
    echo "Stow is not installed. Please install it first."
    exit 1
fi

# Apply stow to all subdirectories that look like packages
echo "Applying dotfiles with stow..."
for dir in */; do
    pkg="${dir%/}"
    # Skip non-package directories if any (e.g. backup folders starting with _)
    if [[ "$pkg" == "_"* ]]; then
        continue
    fi
    
    echo "Stowing $pkg..."
    stow -R "$pkg" 2>/dev/null || stow "$pkg"
done

echo "Done! Dotfiles configured."
