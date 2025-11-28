# 🐳 Ansible CI/CD Docker Images

This repository provides prebuilt Docker images for **Ansible-based CI/CD pipelines**, built on multiple Linux distributions with Python and commonly used Ansible dependencies.

## 🧩 Supported Base Images

Each image is built for a specific OS to match production environments or CI runner needs:

- `ubuntu2004` → Ubuntu 20.04
- `ubuntu2204` → Ubuntu 22.04
- `debian11` → Debian Bullseye
- `debian12` → Debian Bookworm
- `rockylinux8` → Rocky Linux 8
- `rockylinux9` → Rocky Linux 9
- `alpine3.20` → Alpine 3.20
- `alpine3.21` → Alpine 3.21

Each image is tagged as:
```
bsmeding/ansible_cicd_<tag>:latest
```

---

## 📦 Included Software

Each image includes:

- ✅ **Ansible** (version dynamically chosen per OS compatibility)
- ✅ Python 3 with `pip`, `setuptools`, `wheel`
- ✅ Common Python Ansible modules:
  - `pynautobot`, `pynetbox`
  - `yamllint`, `cryptography`, `jmespath`, `netaddr`, `pywinrm`
- ✅ Systemd support for Molecule testing (Debian/Ubuntu-based only)

Alpine images are optimized for minimal footprint, while Debian/Rocky images offer compatibility with more complex Ansible roles and Python modules.

---

## 🛠 Use Cases

These images are great for:

- 🔁 **CI/CD pipelines** (GitHub Actions, GitLab CI, etc.)
- 🧪 **Molecule testing** of Ansible roles
- 🚀 Quick local Ansible testing
- 🧰 Bootstrapping automation tooling in containerized workflows

---

## 📦 Usage in GitHub Actions

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: bsmeding/ansible_cicd_ubuntu2204:latest
    steps:
      - uses: actions/checkout@v4
      - run: ansible-playbook playbook.yml
```

---

## 🧪 Molecule Testing

These images are optimized for **Molecule** testing of Ansible roles. The images include systemd support and are pre-configured with Ansible and common dependencies.

### Basic Molecule Configuration

Create a `molecule/default/molecule.yml` file in your Ansible role:

```yaml
---
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: "bsmeding/ansible_cicd_${MOLECULE_DISTRO:-ubuntu2204}:latest"
    command: ${MOLECULE_DOCKER_COMMAND:-"/lib/systemd/systemd"}
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    cgroupns_mode: host
    tmpfs:
      - /run
      - /run/lock
    environment:
      container: docker
    privileged: true
    pre_build_image: true
    
provisioner:
  name: ansible
  config_options:
    defaults:
      gather_facts: true
      remote_tmp: /tmp/.ansible
      roles_path: "../../../"
```

### Key Configuration Options

- **`command: /lib/systemd/systemd`** - Overrides the default bash CMD to enable systemd (required for service management)
- **`privileged: true`** - Required for systemd to function properly
- **`cgroupns_mode: host`** - Allows systemd to manage cgroups
- **`volumes: /sys/fs/cgroup:/sys/fs/cgroup:rw`** - Mounts cgroup filesystem for systemd

### Testing Multiple Distributions

Use environment variables to test different distributions:

```bash
# Test on Ubuntu 22.04
MOLECULE_DISTRO=ubuntu2204 molecule test

# Test on Debian 12
MOLECULE_DISTRO=debian12 molecule test

# Test on Rocky Linux 9
MOLECULE_DISTRO=rockylinux9 molecule test
```

### Advanced Configuration (Docker-in-Docker)

For roles that need Docker (e.g., deploying containers), add Docker socket access:

```yaml
platforms:
  - name: instance
    image: bsmeding/ansible_cicd_${MOLECULE_DISTRO:-ubuntu2204}:latest
    command: /lib/systemd/systemd
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - /var/run/docker.sock:/var/run/docker.sock
    cgroupns_mode: host
    privileged: true
    pre_build_image: true
    environment:
      DOCKER_HOST: unix:///var/run/docker.sock
    capabilities:
      - SYS_ADMIN
      - NET_ADMIN
      - SYS_CHROOT
      # ... additional capabilities as needed
```

### Ansible Interpreter Configuration

The images are pre-configured with the correct Python interpreter path (`/opt/venv/bin/python`). When you install additional packages via `pip install` in your CI/CD pipeline, they will be automatically available to Ansible since everything runs in the same virtual environment.

**Note:** Alpine images use `/bin/sh` as the default CMD and don't support systemd. Use Debian/Ubuntu/Rocky images for roles that require systemd.

---

## 🛳 Available on Docker Hub

All images are pushed to [Docker Hub](https://hub.docker.com/u/bsmeding):

📦 [bsmeding/ansible_cicd_ubuntu2204](https://hub.docker.com/r/bsmeding/ansible_cicd_ubuntu2204)  
📦 [bsmeding/ansible_cicd_debian13](https://hub.docker.com/r/bsmeding/ansible_cicd_debian13)  
... and more!

---


## 🙌 Contributions

Feel free to open issues or PRs if:

- A new base image version is available
- You want additional packages
- You find bugs or build failures

---

## 📜 License

MIT

---

## 👤 Maintainer

**[bsmeding](https://github.com/bsmeding)** — Built for reproducible Ansible pipelines and fast Molecule testing.