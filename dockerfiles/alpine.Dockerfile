ARG BASE_IMAGE=alpine:3.22.2
FROM ${BASE_IMAGE}

# Copy package requirement files
COPY requirements/apk.txt /tmp/apk.txt
COPY requirements/pip.txt /tmp/pip.txt

# Install system and build dependencies
RUN apk add --no-cache \
    bash \
    curl \
    python3 \
    python3-dev \
    gcc \
    musl-dev \
    libffi-dev \
    cargo \
    make

# Create and activate virtualenv
RUN python3 -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r /tmp/pip.txt

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
