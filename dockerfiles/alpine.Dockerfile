ARG BASE_IMAGE=alpine:3.22.2
ARG PYTHON_VERSION=system
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION

# Copy package requirement files
COPY requirements/apk.txt /tmp/apk.txt
COPY requirements/pip.txt /tmp/pip.txt

# Install system and build dependencies - use Python version from build arg (max 3.13)
# If PYTHON_VERSION is "system" or the requested version isn't available, use system python3
RUN apk add --no-cache \
    bash \
    curl \
    py3-pip \
    gcc \
    musl-dev \
    libffi-dev \
    cargo \
    make

# Install Python - try requested version, fallback to system python3
RUN if [ "$PYTHON_VERSION" != "system" ]; then \
        apk add --no-cache python${PYTHON_VERSION} python${PYTHON_VERSION}-dev 2>/dev/null && \
        ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
        echo "${PYTHON_VERSION}" > /tmp/python_version || \
        (apk add --no-cache python3 python3-dev && \
         python3 -c "import sys; print('{}.{}'.format(sys.version_info.major, sys.version_info.minor))" > /tmp/python_version); \
    else \
        apk add --no-cache python3 python3-dev && \
        python3 -c "import sys; print('{}.{}'.format(sys.version_info.major, sys.version_info.minor))" > /tmp/python_version; \
    fi

# Create and activate virtualenv using installed Python version
# Filter out pyats (not available for Alpine/musl) before installing
RUN PYTHON_VER=$(cat /tmp/python_version) && \
    python${PYTHON_VER} -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    pip install --upgrade pip setuptools wheel && \
    grep -v '^pyats$' /tmp/pip.txt > /tmp/pip-filtered.txt && \
    pip install --no-cache-dir -r /tmp/pip-filtered.txt && \
    rm -f /tmp/python_version

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
