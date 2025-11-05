ARG BASE_IMAGE=alpine:3.22.2
ARG PYTHON_VERSION=3.13
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION

# Copy package requirement files
COPY requirements/apk.txt /tmp/apk.txt
COPY requirements/pip.txt /tmp/pip.txt

# Install system and build dependencies - use Python version from build arg (max 3.13)
RUN apk add --no-cache \
    bash \
    curl \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-dev \
    py3-pip \
    gcc \
    musl-dev \
    libffi-dev \
    cargo \
    make && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3

# Create and activate virtualenv using specified Python version
# Filter out pyats (not available for Alpine/musl) before installing
RUN python${PYTHON_VERSION} -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    pip install --upgrade pip setuptools wheel && \
    grep -v '^pyats$' /tmp/pip.txt > /tmp/pip-filtered.txt && \
    pip install --no-cache-dir -r /tmp/pip-filtered.txt

# Make venv available in PATH
ENV PATH="/opt/venv/bin:$PATH"

# Clean up system build deps
RUN apk del gcc musl-dev libffi-dev cargo make && \
    rm -rf /root/.cache /var/cache/apk/*

# Set Ansible localhost inventory file
RUN mkdir -p /etc/ansible && \
    echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts

# Alpine does not use systemd
CMD ["/bin/sh"]
