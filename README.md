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

## 🛳 Available on Docker Hub

All images are pushed to [Docker Hub](https://hub.docker.com/u/bsmeding):

📦 [bsmeding/ansible_cicd_ubuntu2204](https://hub.docker.com/r/bsmeding/ansible_cicd_ubuntu2204)  
📦 [bsmeding/ansible_cicd_debian11](https://hub.docker.com/r/bsmeding/ansible_cicd_debian11)  
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