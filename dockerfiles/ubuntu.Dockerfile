ARG BASE_IMAGE=ubuntu:oracular-20250619
ARG PYTHON_VERSION=system
FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
ARG PYTHON_VERSION

COPY requirements/apt.txt /tmp/apt.txt
COPY requirements/pip.txt /tmp/pip.txt

# System dependencies
# Install Python version based on PYTHON_VERSION build arg (max 3.13 to avoid Ansible compatibility issues)
RUN apt-get update && \
    xargs -a /tmp/apt.txt apt-get install -y --no-install-recommends && \
    if [ "$PYTHON_VERSION" != "system" ]; then \
        apt-get install -y --no-install-recommends software-properties-common && \
        add-apt-repository -y ppa:deadsnakes/ppa && \
        apt-get update && \
        apt-get install -y --no-install-recommends python${PYTHON_VERSION} python${PYTHON_VERSION}-venv python${PYTHON_VERSION}-dev && \
        update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1; \
    fi && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man

# Create and activate virtual environment
RUN if [ "$PYTHON_VERSION" != "system" ]; then \
        python${PYTHON_VERSION} -m venv /opt/venv; \
    else \
        python3 -m venv /opt/venv; \
    fi && \
    # Ensure python symlink exists (some venvs only have python3)
    if [ ! -f /opt/venv/bin/python ]; then \
        ln -sf /opt/venv/bin/python3 /opt/venv/bin/python; \
    fi
ENV PATH="/opt/venv/bin:$PATH"

# Install pip packages into venv
RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r /tmp/pip.txt

COPY service-wrapper /usr/local/bin/service-wrapper
RUN chmod +x /usr/local/bin/service-wrapper && \
    ln -sf /usr/local/bin/service-wrapper /sbin/initctl && \
    ln -sf /usr/local/bin/service-wrapper /sbin/start && \
    ln -sf /usr/local/bin/service-wrapper /sbin/stop && \
    ln -sf /usr/local/bin/service-wrapper /sbin/restart && \
    ln -sf /usr/local/bin/service-wrapper /sbin/status && \
    ln -sf /usr/local/bin/service-wrapper /usr/local/bin/systemctl && \
    ln -sf /usr/local/bin/service-wrapper /usr/local/bin/service && \
    echo "All fake service commands linked"

# Set Ansible localhost inventory file and configure interpreter
RUN mkdir -p /etc/ansible && \
    echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts && \
    /opt/venv/bin/python3 -c "with open('/etc/ansible/ansible.cfg', 'w') as f: f.write('[defaults]\ninterpreter_python=auto_silent\n')"

# Create symlinks so Ansible can find the venv Python interpreter
# This ensures Ansible uses the venv Python and can find packages installed via pip
RUN ln -sf /opt/venv/bin/python3 /usr/local/bin/python3-ansible && \
    ln -sf /opt/venv/bin/pip3 /usr/local/bin/pip3-ansible

# Remove unnecessary getty and udev targets that result in high CPU usage when using
# multiple containers with Molecule (https://github.com/ansible/molecule/issues/1104)
RUN rm -f /lib/systemd/system/systemd*udev* \
  && rm -f /lib/systemd/system/getty.target

VOLUME ["/sys/fs/cgroup"]
CMD ["/lib/systemd/systemd"]