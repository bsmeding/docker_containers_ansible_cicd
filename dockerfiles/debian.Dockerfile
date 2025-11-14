ARG BASE_IMAGE=debian:trixie
ARG PYTHON_VERSION=system
FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
ARG PYTHON_VERSION

COPY requirements/apt.txt /tmp/apt.txt
COPY requirements/pip.txt /tmp/pip.txt

RUN apt-get update \
    && grep -v '^software-properties-common' /tmp/apt.txt | xargs apt-get install -y --no-install-recommends \
    && if [ "$PYTHON_VERSION" != "system" ]; then \
        (apt-get install -y --no-install-recommends python${PYTHON_VERSION} python${PYTHON_VERSION}-venv python${PYTHON_VERSION}-dev 2>/dev/null && \
         update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1) || \
        (echo "Python ${PYTHON_VERSION} not available, using system Python" && \
         apt-get install -y --no-install-recommends python3 python3-venv python3-dev); \
    else \
        apt-get install -y --no-install-recommends python3 python3-venv python3-dev; \
    fi \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man \
    && apt-get clean

RUN sed -i 's/^\($ModLoad imklog\)/#\1/' /etc/rsyslog.conf

# Create and activate virtual environment
RUN if [ "$PYTHON_VERSION" != "system" ] && command -v python${PYTHON_VERSION} >/dev/null 2>&1; then \
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

# Set Ansible localhost inventory file and configure interpreter
RUN mkdir -p /etc/ansible && \
    echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts && \
    /opt/venv/bin/python3 -c "with open('/etc/ansible/ansible.cfg', 'w') as f: f.write('[defaults]\ninterpreter_python=/opt/venv/bin/python\n')"

# Create symlinks so Ansible can find the venv Python interpreter
# This ensures Ansible uses the venv Python and can find packages installed via pip
RUN ln -sf /opt/venv/bin/python3 /usr/local/bin/python3-ansible && \
    ln -sf /opt/venv/bin/pip3 /usr/local/bin/pip3-ansible

# Remove unnecessary getty and udev targets that result in high CPU usage when using
# multiple containers with Molecule (https://github.com/ansible/molecule/issues/1104)
RUN rm -f /lib/systemd/system/systemd*udev* \
  && rm -f /lib/systemd/system/getty.target

VOLUME ["/sys/fs/cgroup"]
# Default CMD keeps container running for local testing
# CI/CD systems will override this with their own commands
# For Molecule testing, override with: docker run --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro --tmpfs /run --tmpfs /run/lock bsmeding/ansible_cicd_debian:latest /lib/systemd/systemd
CMD ["sleep", "infinity"]