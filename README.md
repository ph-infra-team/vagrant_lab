# Vagrant Lab Automation

Enterprise runbook for inspecting and managing Vagrant-based lab infrastructure from Ansible.

This repository targets shared bare-metal lab hosts that run Vagrant workloads under a common lab directory. The current active automation performs Vagrant status discovery and identifies powered-off VMs per host. Optional reload and audit reporting tasks exist in the role but are currently disabled in `roles/vagrant-lab-manage/tasks/main.yml`.

## Scope

Current active behavior:

- Connect to lab hosts over SSH.
- Query Vagrant status on each configured lab host.
- Build a per-host list of VMs in `poweroff` state.

Available but currently disabled:

- Reload powered-off VMs.
- Generate an audit report under `/tmp`.

Supporting playbooks:

- Provision and inspect the Vagrant lab.
- Test SSH connectivity to lab hosts.
- Report Vagrant global status from each lab host.

Out of scope:

- Creating Vagrantfiles
- Installing hypervisors
- Installing Vagrant on lab hosts
- Destroying VMs
- Managing production infrastructure

## Repository Layout

```text
vagrant_lab/
|-- README.md
|-- provision-vagrant-lab.yml
|-- test-infra-connect.yml
|-- collections/
|   `-- requirements.yml
|-- inventory/
|   `-- vagrant-hosts.ini
`-- roles/
    `-- vagrant-lab-manage/
        |-- defaults/
        |   `-- main.yml
        |-- vars/
        |   `-- main.yml
        |-- meta/
        |   `-- runtime.yml
        |-- tasks/
        |   |-- main.yml
        |   |-- status_check.yml
        |   |-- conditional_reload.yml
        |   `-- reporting.yml
        `-- templates/
            `-- lab_report.j2
```

| Path | Purpose |
| --- | --- |
| `provision-vagrant-lab.yml` | Main local playbook that installs required collections and runs `vagrant-lab-manage`. |
| `test-infra-connect.yml` | Connectivity and Vagrant visibility test for hosts in the `bare_metal` inventory group. |
| `inventory/vagrant-hosts.ini` | SSH inventory for lab hosts. |
| `collections/requirements.yml` | Collection dependency list. Currently requires `community.vagrant`. |
| `roles/vagrant-lab-manage/defaults/main.yml` | Default lab directory, host list, and target VM settings. |
| `roles/vagrant-lab-manage/tasks/status_check.yml` | Active Vagrant status discovery task set. |
| `roles/vagrant-lab-manage/tasks/conditional_reload.yml` | Optional powered-off VM reload task set. Disabled by default. |
| `roles/vagrant-lab-manage/tasks/reporting.yml` | Optional audit report task set. Disabled by default. |

## Architecture

The automation is launched from localhost and delegates Vagrant operations to each configured lab host.

Execution flow in the active path:

1. `provision-vagrant-lab.yml` runs on `localhost`.
2. Required collections are installed from `collections/requirements.yml`.
3. The `vagrant-lab-manage` role runs.
4. `status_check.yml` executes `community.vagrant.vagrant` with `state: list` against each host in `infra_hosts`.
5. The role builds `poweroff_vms_by_host`, keyed by host name.

Current `tasks/main.yml`:

```yaml
- import_tasks: status_check.yml
# - import_tasks: conditional_reload.yml
# - import_tasks: reporting.yml
```

This means the default run is discovery-only.

## Prerequisites

Control node requirements:

- Python 3
- Ansible Core
- `ansible-galaxy`
- SSH access to each lab host

Lab host requirements:

- Vagrant installed
- Vagrant lab directory exists, currently `/proj/vagrant/vagrant-lab`
- Python 3 available at `/usr/bin/python3`
- SSH user can run Vagrant commands in the lab directory
- Required provider or hypervisor already installed and configured

Install collection dependencies:

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

Check Ansible:

```bash
ansible --version
ansible-galaxy --version
```

## Inventory

Current inventory file:

```text
inventory/vagrant-hosts.ini
```

Current group:

```ini
[bare_metal]
infra01 ansible_host=192.168.1.149 ansible_user=midhtechadmin ansible_port=22
infra02 ansible_host=192.168.1.74  ansible_user=midhtechadmin ansible_port=22
```

Group defaults:

```ini
[bare_metal:vars]
ansible_connection=ssh
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
ansible_python_interpreter=/usr/bin/python3
```

Enterprise note: disabling strict host key checking is convenient for labs but should be reviewed before use on shared or regulated networks.

## Variables

Default variables are defined in:

```text
roles/vagrant-lab-manage/defaults/main.yml
```

Current defaults:

```yaml
lab_dir: /proj/vagrant/vagrant-lab
infra_hosts:
  - hostname: infra01
    lab_dir: /proj/vagrant/vagrant-lab
  - hostname: infra02
    lab_dir: /proj/vagrant/vagrant-lab
target_vms: []
```

| Variable | Purpose |
| --- | --- |
| `lab_dir` | Default Vagrant lab directory. |
| `infra_hosts` | List of lab hosts and their Vagrant working directories. |
| `target_vms` | Reserved targeting list. Current active task path discovers all powered-off VMs. |

The host names in `infra_hosts` must match inventory host aliases when delegation is used.

## Running

Run from the repository root:

```bash
cd /home/harip/workspace/ansible/local_midh/vagrant_lab
```

Install collections:

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

Test SSH connectivity and Vagrant visibility:

```bash
ansible-playbook -i inventory/vagrant-hosts.ini test-infra-connect.yml
```

Run the active discovery workflow:

```bash
ansible-playbook -i inventory/vagrant-hosts.ini provision-vagrant-lab.yml
```

Override lab hosts at runtime:

```bash
ansible-playbook -i inventory/vagrant-hosts.ini provision-vagrant-lab.yml \
  -e '{"infra_hosts":[{"hostname":"infra01","lab_dir":"/proj/vagrant/vagrant-lab"}]}'
```

## Optional Reload Workflow

`roles/vagrant-lab-manage/tasks/conditional_reload.yml` is intended to reload powered-off VMs only. It is disabled by default.

Before enabling it:

- Confirm the powered-off VM list is correct.
- Confirm no team is intentionally keeping those VMs stopped.
- Confirm reload capacity on the lab host.
- Review the task implementation in a test run.

Enable by uncommenting this line in `roles/vagrant-lab-manage/tasks/main.yml`:

```yaml
- import_tasks: conditional_reload.yml
```

Then run:

```bash
ansible-playbook -i inventory/vagrant-hosts.ini provision-vagrant-lab.yml
```

Operational caution: reloading lab VMs can consume CPU, memory, disk IO, and IP leases on shared bare-metal hosts.

## Optional Reporting

`roles/vagrant-lab-manage/tasks/reporting.yml` is disabled by default. When enabled, it renders:

```text
/tmp/vagrant_lab_report_<epoch>.txt
```

from:

```text
roles/vagrant-lab-manage/templates/lab_report.j2
```

Enable by uncommenting this line in `roles/vagrant-lab-manage/tasks/main.yml`:

```yaml
- import_tasks: reporting.yml
```

## Validation

Syntax check:

```bash
ansible-playbook -i inventory/vagrant-hosts.ini provision-vagrant-lab.yml --syntax-check
ansible-playbook -i inventory/vagrant-hosts.ini test-infra-connect.yml --syntax-check
```

List tasks:

```bash
ansible-playbook -i inventory/vagrant-hosts.ini provision-vagrant-lab.yml --list-tasks
```

Validate inventory:

```bash
ansible-inventory -i inventory/vagrant-hosts.ini --list
```

Ping lab hosts:

```bash
ansible bare_metal -i inventory/vagrant-hosts.ini -m ping
```

## Enterprise Operating Standards

### Change Control

- Review all inventory changes through merge requests.
- Review changes to `infra_hosts`, lab paths, reload behavior, and SSH options.
- Treat reload enablement as an operational change, not a documentation-only change.
- Record reload runs when shared lab capacity or team workloads may be affected.

### Safety

- Default workflow must remain discovery-first.
- Do not add VM destroy, halt, or force reload behavior without explicit approval.
- Do not target production hosts from this repository.
- Keep lab host access scoped to authorized operators.
- Avoid running reload across all hosts during peak lab usage.

### Access Control

- Use managed SSH keys or enterprise identity where possible.
- Avoid personal unmanaged SSH keys on shared automation runners.
- Confirm the SSH user has only the permissions required for lab management.
- Review disabled host key checking before use outside an isolated lab network.

### Auditability

Capture the following for operational runs:

- Operator or automation account
- Git commit
- Target inventory
- Playbook command
- List of affected hosts
- Powered-off VM list before reload
- Reload results, if reload is enabled
- Report artifact path, if reporting is enabled

## Troubleshooting

### SSH Connection Failed

Check:

- `ansible_host`
- `ansible_user`
- SSH key or password access
- Firewall access to port `22`
- Host key policy

### Vagrant Command Failed

Check:

- Vagrant is installed on the delegated host.
- The SSH user can execute Vagrant.
- `lab_dir` exists.
- The lab directory contains a valid Vagrant environment.
- The provider or hypervisor is healthy.

### No VMs Found

Check:

- `vagrant global-status --prune` output on the lab host.
- `community.vagrant.vagrant` collection behavior.
- Correct `lab_dir` value for each host.
- Whether VMs are running, suspended, or not created.

### Report Not Generated

Check:

- `reporting.yml` is imported from `tasks/main.yml`.
- Facts are available for `ansible_date_time`.
- Local `/tmp` is writable.

### Reload Did Not Run

Check:

- `conditional_reload.yml` is imported from `tasks/main.yml`.
- `poweroff_vms_by_host` contains VMs for the host.
- Inventory aliases match `infra_hosts[*].hostname`.
- The Vagrant VM names match the discovered names.

## Maintenance Notes

- Keep `infra_hosts` aligned with `inventory/vagrant-hosts.ini`.
- Keep default behavior non-destructive.
- Document any new task file in this README.
- Add CI lint and syntax checks before using this from shared automation.
- Keep lab paths configurable through variables instead of hardcoding new paths in tasks.
