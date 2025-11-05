ARG BASE_IMAGE=rockylinux:9
FROM ${BASE_IMAGE}

COPY requirements/dnf.txt /tmp/dnf.txt
COPY requirements/pip.txt /tmp/pip.txt

# Clean up default systemd targets
RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/basic.target.wants/* \
    /lib/systemd/system/anaconda.target.wants/*

# Install general requirements
RUN dnf install -y dnf-plugins-core epel-release findutils && \
    xargs -a /tmp/dnf.txt dnf install -y

# Install Python 3.13 explicitly (max version for ansible compatibility)
RUN dnf install -y python3.13 python3.13-pip python3.13-devel && \
    alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1 && \
    alternatives --set python3 /usr/bin/python3.13 || true

# Install YAML dev lib (only exists in Rocky 8)
RUN dnf install -y libyaml-devel || true

# If running on Rocky 8, install Docker CE
RUN if grep -q 'release 8' /etc/redhat-release; then \
        echo "Rocky 8 detected: Installing Docker CE" && \
        dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo && \
        dnf makecache && \
        dnf install -y docker-ce docker-ce-cli containerd.io && \
        systemctl enable docker; \
    else \
        echo "Skipping Docker install on non-Rocky 8 base"; \
    fi && \
    dnf clean all

# Install Python requirements using Python 3.13
RUN python3.13 -m pip install --upgrade pip setuptools wheel && \
    python3.13 -m pip install --no-cache-dir --ignore-installed --index-url https://pypi.org/simple -r /tmp/pip.txt

# Disable sudo requiretty
RUN sed -i -e 's/^\(Defaults\s*requiretty\)/#--- \1/' /etc/sudoers

# Default inventory for Ansible
RUN mkdir -p /etc/ansible && \
    echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts

VOLUME ["/sys/fs/cgroup"]
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
