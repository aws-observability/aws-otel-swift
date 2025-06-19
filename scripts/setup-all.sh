#!/bin/bash

# Master setup script that runs all setup scripts
# Created to simplify the development environment setup process

# Find the repository root directory
REPO_ROOT="$(git rev-parse --show-toplevel)"
SCRIPTS_DIR="$REPO_ROOT/scripts"

echo "Starting complete development environment setup..."
echo "-----------------------------------------------------"
echo "Repository root: $REPO_ROOT"
echo "Scripts directory: $SCRIPTS_DIR"

# Ensure all scripts have execute permissions
chmod +x "$SCRIPTS_DIR/setup-git-hooks.sh"
chmod +x "$SCRIPTS_DIR/setup-ts-tools.sh"

# Run the Git hooks setup script
echo "Setting up Git hooks..."
"$SCRIPTS_DIR/setup-git-hooks.sh"

# Run the TypeScript tools setup script
echo "Setting up TypeScript tools..."
"$SCRIPTS_DIR/setup-ts-tools.sh"

echo "All setup complete! Your development environment is ready."
