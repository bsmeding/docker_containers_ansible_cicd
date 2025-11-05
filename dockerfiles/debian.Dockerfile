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
        apt-get install -y --no-install-recommends python${PYTHON_VERSION} python${PYTHON_VERSION}-venv python${PYTHON_VERSION}-dev && \
        update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1; \
    fi \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man \
    && apt-get clean

RUN sed -i 's/^\($ModLoad imklog\)/#\1/' /etc/rsyslog.conf

# Remove EXTERNALLY-MANAGED file for the installed Python version
RUN if [ "$PYTHON_VERSION" != "system" ]; then \
        PYTHON_VER="$PYTHON_VERSION"; \
    else \
        PYTHON_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"); \
    fi && \
    rm -f /usr/lib/python${PYTHON_VER}/EXTERNALLY-MANAGED || \
    find /usr/lib/python${PYTHON_VER} -name "EXTERNALLY-MANAGED" -type f -delete || true

# Upgrade pip to latest version and install packages
RUN if [ "$PYTHON_VERSION" != "system" ]; then \
        python${PYTHON_VERSION} -m pip install --upgrade --ignore-installed pip setuptools wheel && \
        python${PYTHON_VERSION} -m pip install --no-cache-dir --break-system-packages --ignore-installed --index-url https://pypi.org/simple -r /tmp/pip.txt; \
    else \
        python3 -m pip install --upgrade --ignore-installed pip setuptools wheel && \
        python3 -m pip install --no-cache-dir --break-system-packages --ignore-installed --index-url https://pypi.org/simple -r /tmp/pip.txt; \
    fi

# Set Ansible localhost inventory file
RUN mkdir -p /etc/ansible
RUN echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts

# Remove unnecessary getty and udev targets that result in high CPU usage when using
# multiple containers with Molecule (https://github.com/ansible/molecule/issues/1104)
RUN rm -f /lib/systemd/system/systemd*udev* \
  && rm -f /lib/systemd/system/getty.target

VOLUME ["/sys/fs/cgroup"]
CMD ["/lib/systemd/systemd"]