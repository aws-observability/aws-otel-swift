# Development Scripts

This directory contains scripts to help with development workflows.

## Complete Setup

The `setup-all.sh` script provides a convenient way to set up all development tools in one step.

To run the complete setup:

```bash
./setup-all.sh
```

This will execute both the Git hooks setup and TypeScript tools setup in sequence.

## Git Hooks

The `setup-git-hooks.sh` script sets up Git hooks for the project. These hooks help maintain code quality by automatically formatting and linting code before commits.

To set up the Git hooks individually:

```bash
./setup-git-hooks.sh
```

## TypeScript Tools

The `setup-ts-tools.sh` script installs Prettier globally and creates configuration files for TypeScript formatting.

To set up the TypeScript tools individually:

```bash
./setup-ts-tools.sh
```

This will:
1. Install Prettier globally
2. Create configuration file (.prettierrc)

No package.json file is required as the tools are installed globally.

## Pre-commit Hook

The pre-commit hook automatically formats and lints:
- Swift files using SwiftFormat and SwiftLint
- TypeScript files using Prettier

When you commit changes, the hook will:
1. Identify changed files by file type extension
2. Run appropriate formatters and linters
3. Add the formatted files back to staging
4. Complete the commit if all checks pass

## Requirements

- For Swift formatting: SwiftFormat and SwiftLint
- For TypeScript formatting: Node.js and npm with globally installed Prettier (can be installed by the setup script)
