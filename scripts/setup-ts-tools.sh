#!/bin/bash

# Script to set up TypeScript formatting tools
echo "Setting up TypeScript formatting tools..."

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "ERROR: npm is not installed. Please install Node.js and npm first."
    exit 1
fi

# Install and Prettier globally
echo "Installing Prettier globally..."
npm install -g prettier

# Create Prettier config if it doesn't exist in the repository root
REPO_ROOT="$(git rev-parse --show-toplevel)"
if [ ! -f "$REPO_ROOT/.prettierrc" ]; then
    echo "Creating Prettier configuration in repository root..."
    cat > "$REPO_ROOT/.prettierrc" << 'EOL'
{
  "semi": true,
  "trailingComma": "all",
  "singleQuote": true,
  "printWidth": 100,
  "tabWidth": 2
}
EOL
fi

echo "TypeScript formatting tools setup complete!"
