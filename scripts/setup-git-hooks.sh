#!/bin/bash

# Script to set up Git hooks for the project
# This script creates symbolic links from the .git/hooks directory to our custom hooks

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
HOOKS_DIR="$REPO_ROOT/.git/hooks"
CUSTOM_HOOKS_DIR="$REPO_ROOT/scripts/git-hooks"

echo "Setting up Git hooks..."

# Create symbolic links for each hook
for hook in "$CUSTOM_HOOKS_DIR"/*; do
  if [ -f "$hook" ]; then
    hook_name=$(basename "$hook")
    ln -sf "$hook" "$HOOKS_DIR/$hook_name"
    chmod +x "$HOOKS_DIR/$hook_name"
    echo "✅ Installed: $hook_name"
  fi
done

echo "Git hooks setup complete! 🎉"
