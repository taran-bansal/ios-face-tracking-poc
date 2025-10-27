#!/bin/bash
echo "Setting up GitHub remote for POC repository..."

# Replace YOUR_USERNAME with your actual GitHub username
# Replace YOUR_REPO_NAME with your desired repository name (e.g., ios-face-tracking-poc)
echo "Please enter your GitHub username:"
read username

echo "Please enter your desired repository name (default: ios-face-tracking-poc):"
read repo_name

if [ -z "$repo_name" ]; then
    repo_name="ios-face-tracking-poc"
fi

echo "Creating GitHub repository..."
gh repo create "$repo_name" --public --source=. --remote=origin --push

echo "Repository setup complete!"
echo "Your repository is now available at: https://github.com/$username/$repo_name"
