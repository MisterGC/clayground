#!/bin/bash
# Script to run Jekyll with the correct Ruby version

# First sync plugin documentation
echo "Syncing plugin documentation..."
./sync-plugin-docs.sh
echo ""

export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
echo "Using Ruby: $(which ruby)"
echo "Ruby version: $(ruby --version)"
echo ""
echo "Starting Jekyll server..."
echo ""
echo "The site will be available at:"
echo "  → http://localhost:4000"
echo ""
# Use empty baseurl for local development
bundle exec jekyll serve --baseurl ""