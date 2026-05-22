#!/bin/bash

echo "🧨 Destroying all Vagrant machines known to this host..."
echo

# Prune stale entries first
vagrant global-status --prune > /dev/null

# Get all valid VM IDs (regardless of state)
vagrant global-status --prune | awk 'NR>2 && NF==5 { print $1 }' | while read id; do
  echo "⛔ Destroying VM with ID: $id"
  vagrant destroy -f "$id"
done

echo
echo "✅ All Vagrant machines destroyed successfully."

