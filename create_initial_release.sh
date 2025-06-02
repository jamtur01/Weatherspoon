#!/bin/bash

# Script to create the initial v1.0.0 release

# Make sure the build script is executable
chmod +x ./build.sh

echo "Creating initial v1.0.0 release for Weatherspoon..."

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Error: git is not installed. Please install git and try again."
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    echo "Error: Not in a git repository. Please run this script from the root of your git repository."
    exit 1
fi

# Check if there are uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "There are uncommitted changes. Please commit or stash them before creating a release."
    exit 1
fi

# Commit the version files if they're not already committed
if git status --porcelain | grep -q "VERSION\|Info.plist\|README.md\|.github/\|build.sh"; then
    echo "Committing version files..."
    git add VERSION Resources/Info.plist README.md .github/ build.sh
    git commit -m "Add versioning and GitHub release workflow"
fi

# Ensure the repository is pushed to GitHub
echo "Pushing changes to GitHub..."
git push origin HEAD

# Create and push the tag
echo "Creating tag v1.0.0..."
git tag v1.0.0

echo "Pushing tag to GitHub..."
git push origin v1.0.0

echo "Done! GitHub Actions will now build and create the release."
echo "Check the Actions tab on your GitHub repository to monitor progress."