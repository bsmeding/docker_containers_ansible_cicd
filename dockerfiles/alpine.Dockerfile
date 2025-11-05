ARG BASE_IMAGE=alpine:3.22.2
FROM ${BASE_IMAGE}

# Copy package requirement files
COPY requirements/apk.txt /tmp/apk.txt
COPY requirements/pip.txt /tmp/pip.txt

# Install system and build dependencies - explicitly use Python 3.13
RUN apk add --no-cache \
    bash \
    curl \
    python3.13 \
    python3.13-dev \
    py3-pip \
    gcc \
    musl-dev \
    libffi-dev \
    cargo \
    make && \
    ln -sf /usr/bin/python3.13 /usr/bin/python3

# Create and activate virtualenv using Python 3.13
# Filter out pyats (not available for Alpine/musl) before installing
RUN python3.13 -m venv /opt/venv && \
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
