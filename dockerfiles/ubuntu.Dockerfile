ARG BASE_IMAGE=ubuntu:oracular-20250619
FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive

COPY requirements/apt.txt /tmp/apt.txt
COPY requirements/pip.txt /tmp/pip.txt

# System dependencies
RUN apt-get update && \
    xargs -a /tmp/apt.txt apt-get install -y --no-install-recommends && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man

# Create and activate virtual environment
RUN python3 -m venv /opt/venv
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

# Set Ansible localhost inventory file
RUN mkdir -p /etc/ansible
RUN echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts

# Remove unnecessary getty and udev targets that result in high CPU usage when using
# multiple containers with Molecule (https://github.com/ansible/molecule/issues/1104)
RUN rm -f /lib/systemd/system/systemd*udev* \
  && rm -f /lib/systemd/system/getty.target

VOLUME ["/sys/fs/cgroup"]
CMD ["/lib/systemd/systemd"]