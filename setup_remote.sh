#!/bin/bash
echo "🚀 Setting up GitHub remote for your iOS Face Tracking POC"
echo ""

# Get GitHub username
echo "Please enter your GitHub username:"
read username

if [ -z "$username" ]; then
    echo "❌ GitHub username is required!"
    exit 1
fi

# Get repository name
echo "Please enter your desired repository name (default: ios-face-tracking-poc):"
read repo_name

if [ -z "$repo_name" ]; then
    repo_name="ios-face-tracking-poc"
fi

echo "📡 Setting up remote repository..."
echo "Repository: https://github.com/$username/$repo_name"

# Add remote
git remote add origin "https://github.com/$username/$repo_name.git"

echo "🔄 Fetching from remote..."
git fetch origin

echo "📤 Pushing to GitHub..."
git push -u origin main

echo ""
echo "✅ SUCCESS! Your repository is now live at:"
echo "🔗 https://github.com/$username/$repo_name"
echo ""
echo "📱 Ready to test on iOS devices!"
echo "   Make sure camera permissions are enabled in Settings > Privacy & Security > Camera"
