ARG BASE_IMAGE=debian:trixie
FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive

COPY requirements/apt.txt /tmp/apt.txt
COPY requirements/pip.txt /tmp/pip.txt

RUN apt-get update \
    && grep -v '^software-properties-common' /tmp/apt.txt | xargs apt-get install -y --no-install-recommends \
    && apt-get install -y --no-install-recommends python3.13 python3.13-venv python3.13-dev \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man \
    && apt-get clean

RUN sed -i 's/^\($ModLoad imklog\)/#\1/' /etc/rsyslog.conf

# Remove EXTERNALLY-MANAGED file for Python 3.13
RUN rm -f /usr/lib/python3.13/EXTERNALLY-MANAGED || \
    find /usr/lib/python3.13 -name "EXTERNALLY-MANAGED" -type f -delete || true

# Upgrade pip to latest version and install packages using Python 3.13
RUN python3.13 -m pip install --upgrade --ignore-installed pip setuptools wheel && \
    python3.13 -m pip install --no-cache-dir --break-system-packages --ignore-installed --index-url https://pypi.org/simple -r /tmp/pip.txt

# Set Ansible localhost inventory file
RUN mkdir -p /etc/ansible
RUN echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts

# Remove unnecessary getty and udev targets that result in high CPU usage when using
# multiple containers with Molecule (https://github.com/ansible/molecule/issues/1104)
RUN rm -f /lib/systemd/system/systemd*udev* \
  && rm -f /lib/systemd/system/getty.target

VOLUME ["/sys/fs/cgroup"]
CMD ["/lib/systemd/systemd"]