#!/bin/bash

SNAPSHOT_NAME="daily-snapshot-$(date +%Y%m%d-%H%M%S)"

# List of VMs to snapshot (exactly as shown in `VBoxManage list vms`)
VM_LIST=(
  "artifactory.example.com"
  "jenkins.example.com"
  "dns.example.com"
  "prometheus.example.com"
  "grafana.example.com"
  "esmaster.example.com"
  "esdata1.example.com"
  "esdata2.example.com"
  "kibana.example.com"
  "logstash.example.com"
  "mysqldb.example.com"
  "mongodb.example.com"
  "controller.example.com"
  "hub.example.com"
  "eda.example.com"
  "gitlabrunner.example.com"
  "postgresdb.example.com"
  "jagent1.example.com"
  "gitlab.example.com"
  "awx.example.com"
  "vault.example.com"
  "ocmaster.example.com"
  "ocworker1.example.com"
  "ocworker2.example.com"
  "secopstools.example.com"
)

for vm in "${VM_LIST[@]}"; do
  echo "📸 Creating snapshot for: $vm"
  VBoxManage snapshot "$vm" take "$SNAPSHOT_NAME" --live || echo "❌ Snapshot failed for $vm"
done

echo "✅ Snapshot process complete: $SNAPSHOT_NAME"
