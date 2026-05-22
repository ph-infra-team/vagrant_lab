#!/bin/bash
VM_NAME=$1
SNAPSHOT_NAME=$2

if [[ -z "$VM_NAME" || -z "$SNAPSHOT_NAME" ]]; then
  echo "Usage: $0 <vm-name> <snapshot-name>"
  exit 1
fi

cd $VM_NAME || exit
vagrant snapshot restore "$SNAPSHOT_NAME"
