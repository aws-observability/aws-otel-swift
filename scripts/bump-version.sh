#!/bin/bash

# AWS OpenTelemetry Swift SDK Version Bump Script
# This script bumps the version in AwsOpenTelemetryAgent.swift and README.md

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# File paths
AGENT_FILE="Sources/AwsOpenTelemetryCore/AwsOpenTelemetryAgent.swift"
README_FILE="README.md"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [major|minor|patch|VERSION] [--commit] [--tag] [--commit-tag]"
    echo ""
    echo "Options:"
    echo "  major        Bump major version (x.0.0)"
    echo "  minor        Bump minor version (x.y.0)"
    echo "  patch        Bump patch version (x.y.z)"
    echo "  VERSION      Set specific version (e.g., 2.1.3)"
    echo "  --commit     Automatically commit the version bump"
    echo "  --tag        Automatically create a git tag for the version"
    echo "  --commit-tag Automatically commit and tag the version bump"
    echo ""
    echo "Examples:"
    echo "  $0 patch                # 1.0.0 -> 1.0.1"
    echo "  $0 minor                # 1.0.0 -> 1.1.0"
    echo "  $0 major                # 1.0.0 -> 2.0.0"
    echo "  $0 1.2.3                # Set version to 1.2.3"
    echo "  $0 patch --commit-tag   # Bump patch version, commit and tag"
}

# Function to validate semantic version format
validate_version() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_color $RED "Error: Invalid version format. Expected format: x.y.z (e.g., 1.2.3)"
        return 1
    fi
    return 0
}

# Function to get current version
get_current_version() {
    if [[ ! -f "$AGENT_FILE" ]]; then
        print_color $RED "Error: $AGENT_FILE not found!"
        exit 1
    fi
    
    # Extract version from the Swift file
    local version=$(grep -o 'static let version = "[^"]*"' "$AGENT_FILE" | sed 's/static let version = "\(.*\)"/\1/')
    
    if [[ -z "$version" ]]; then
        print_color $RED "Error: Could not find version in $AGENT_FILE"
        exit 1
    fi
    
    echo "$version"
}

# Function to bump version
bump_version() {
    local current_version=$1
    local bump_type=$2
    
    # Split current version into parts
    IFS='.' read -ra VERSION_PARTS <<< "$current_version"
    local major=${VERSION_PARTS[0]}
    local minor=${VERSION_PARTS[1]}
    local patch=${VERSION_PARTS[2]}
    
    case $bump_type in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            print_color $RED "Error: Invalid bump type: $bump_type"
            exit 1
            ;;
    esac
    
    echo "${major}.${minor}.${patch}"
}

# Generic function to update version in any file
update_version_in_file() {
    local file_path=$1
    local old_pattern=$2
    local new_pattern=$3
    
    # Check if file exists (optional for some files)
    if [[ ! -f "$file_path" ]]; then
        if [[ "$file_path" == "$README_FILE" ]]; then
            print_color $YELLOW "Warning: $file_path not found, skipping README update"
            return 0
        else
            print_color $RED "Error: $file_path not found!"
            return 1
        fi
    fi
    
    # Create backup
    cp "$file_path" "${file_path}.backup"
    print_color $YELLOW "Created backup: ${file_path}.backup"
    
    # Update the version in the file
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/${old_pattern}/${new_pattern}/" "$file_path"
    else
        # Linux
        sed -i "s/${old_pattern}/${new_pattern}/" "$file_path"
    fi
    
    # Verify the change
    if grep -q "$new_pattern" "$file_path"; then
        print_color $GREEN "✓ Successfully updated $file_path"
        return 0
    else
        print_color $RED "✗ Failed to update $file_path. Rolling back..."
        mv "${file_path}.backup" "$file_path"
        return 1
    fi
}

# Function to update version in agent file
update_version_in_agent_file() {
    local old_version=$1
    local new_version=$2
    
    local old_pattern="static let version = \"$old_version\""
    local new_pattern="static let version = \"$new_version\""
    
    update_version_in_file "$AGENT_FILE" "$old_pattern" "$new_pattern"
}

# Function to update version in README file
update_version_in_readme_file() {
    local old_version=$1
    local new_version=$2
    
    local old_pattern="\.package(url: \"https:\/\/github\.com\/aws-observability\/aws-otel-swift\.git\", from: \"$old_version\")"
    local new_pattern="\.package(url: \"https:\/\/github\.com\/aws-observability\/aws-otel-swift\.git\", from: \"$new_version\")"
    
    update_version_in_file "$README_FILE" "$old_pattern" "$new_pattern"
}

# Function to commit and tag the version bump
commit_and_tag_version() {
    local version=$1
    local do_commit=$2
    local do_tag=$3
    
    if [[ "$do_commit" == true ]]; then
        print_color $BLUE "Committing version bump..."
        git add "$AGENT_FILE" "$README_FILE"
        git commit -m "chore(release): v$version"
        print_color $GREEN "✓ Committed version bump with message: 'chore(release): v$version'"
    fi
    
    if [[ "$do_tag" == true ]]; then
        print_color $BLUE "Creating git tag..."
        git tag "v$version"
        print_color $GREEN "✓ Created git tag: v$version"
    fi
}

# Main function
main() {
    local bump_arg=${1:-}
    local do_commit=false
    local do_tag=false
    
    # Parse arguments
    for arg in "$@"; do
        case $arg in
            --commit)
                do_commit=true
                ;;
            --tag)
                do_tag=true
                ;;
            --commit-tag)
                do_commit=true
                do_tag=true
                ;;
        esac
    done
    
    if [[ -z "$bump_arg" || "$bump_arg" == "--commit" || "$bump_arg" == "--tag" || "$bump_arg" == "--commit-tag" ]]; then
        show_usage
        exit 1
    fi
    
    if [[ "$bump_arg" == "-h" || "$bump_arg" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    # Check if we're in the right directory
    if [[ ! -f "$AGENT_FILE" ]]; then
        print_color $RED "Error: $AGENT_FILE not found!"
        print_color $YELLOW "Make sure you're running this script from the project root directory."
        exit 1
    fi
    
    # Get current version
    local current_version=$(get_current_version)
    print_color $BLUE "Current version: $current_version"
    
    local new_version
    
    # Determine new version
    case $bump_arg in
        major|minor|patch)
            new_version=$(bump_version "$current_version" "$bump_arg")
            ;;
        *)
            # Assume it's a specific version
            new_version=$bump_arg
            if ! validate_version "$new_version"; then
                exit 1
            fi
            ;;
    esac
    
    print_color $BLUE "New version: $new_version"
    
    # Confirm the change
    read -p "Do you want to update the version from $current_version to $new_version? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_color $YELLOW "Version bump cancelled."
        exit 0
    fi
    
    # Update the versions in both files
    local agent_success=false
    local readme_success=false
    
    # Update agent file
    if update_version_in_agent_file "$current_version" "$new_version"; then
        agent_success=true
    fi
    
    # Update README file  
    if update_version_in_readme_file "$current_version" "$new_version"; then
        readme_success=true
    fi
    
    # Check if at least one update was successful
    if [[ "$agent_success" == true ]]; then
        # Clean up backups if successful
        rm -f "${AGENT_FILE}.backup"
        rm -f "${README_FILE}.backup"
        
        print_color $GREEN "Version bump completed successfully!"
        print_color $BLUE "Files updated:"
        if [[ "$agent_success" == true ]]; then
            print_color $BLUE "  - $AGENT_FILE (SDK version)"
        fi
        if [[ "$readme_success" == true ]]; then
            print_color $BLUE "  - $README_FILE (package dependency)"
        fi
        
        # Commit and tag if requested
        if [[ "$do_commit" == true || "$do_tag" == true ]]; then
            commit_and_tag_version "$new_version" "$do_commit" "$do_tag"
        else
            print_color $BLUE "To commit and tag this version bump, you can:"
            print_color $BLUE "  1. Review the changes: git diff"
            print_color $BLUE "  2. Commit the version bump: git add . && git commit -m 'chore(release): v$new_version'"
            print_color $BLUE "  3. Create a git tag: git tag v$new_version"
            print_color $BLUE "Or run this script with --commit-tag option to do both automatically."
        fi
    else
        print_color $RED "Version bump failed!"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
