ARG BASE_IMAGE=rockylinux:9
ARG PYTHON_VERSION=system
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION

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

# Install Python version based on PYTHON_VERSION build arg (max 3.13 for ansible compatibility)
RUN if [ "$PYTHON_VERSION" != "system" ]; then \
        (dnf install -y python${PYTHON_VERSION} python${PYTHON_VERSION}-pip python${PYTHON_VERSION}-devel 2>/dev/null && \
         alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1 && \
         alternatives --set python3 /usr/bin/python${PYTHON_VERSION} || true) || \
        (echo "Python ${PYTHON_VERSION} not available, using system Python" && \
         dnf install -y python3 python3-pip python3-devel); \
    else \
        dnf install -y python3 python3-pip python3-devel; \
    fi

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

# Create and activate virtual environment
RUN if [ "$PYTHON_VERSION" != "system" ] && command -v python${PYTHON_VERSION} >/dev/null 2>&1; then \
        python${PYTHON_VERSION} -m venv /opt/venv; \
    else \
        python3 -m venv /opt/venv; \
    fi
ENV PATH="/opt/venv/bin:$PATH"

# Install Python requirements
# Filter out pyats and molecule-plugins (not available for Rocky Linux 8) before installing
RUN grep -v -E '^(pyats|molecule-plugins)$' /tmp/pip.txt > /tmp/pip-filtered.txt && \
    pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r /tmp/pip-filtered.txt

# Disable sudo requiretty
RUN sed -i -e 's/^\(Defaults\s*requiretty\)/#--- \1/' /etc/sudoers

# Default inventory for Ansible and configure interpreter
RUN mkdir -p /etc/ansible && \
    echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts && \
    /opt/venv/bin/python3 -c "with open('/etc/ansible/ansible.cfg', 'w') as f: f.write('[defaults]\ninterpreter_python=/opt/venv/bin/python3\n')"

# Create symlinks so Ansible can find the venv Python interpreter
# This ensures Ansible uses the venv Python and can find packages installed via pip
RUN ln -sf /opt/venv/bin/python3 /usr/local/bin/python3-ansible && \
    ln -sf /opt/venv/bin/pip3 /usr/local/bin/pip3-ansible

VOLUME ["/sys/fs/cgroup"]
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
