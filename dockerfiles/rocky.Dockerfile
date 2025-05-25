ARG BASE_IMAGE=rockylinux:9
FROM ${BASE_IMAGE}

COPY requirements/dnf.txt /tmp/dnf.txt
COPY requirements/pip.txt /tmp/pip.txt

# Clean systemd default service links
RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/basic.target.wants/* \
    /lib/systemd/system/anaconda.target.wants/*

# Enable CRB or PowerTools depending on version
RUN dnf install -y dnf-plugins-core && \
    if grep -q 'release 8' /etc/redhat-release; then \
        dnf config-manager --enable powertools; \
    else \
        dnf config-manager --set-enabled crb; \
    fi

# Install EPEL and system packages
RUN dnf install -y epel-release && \
    dnf install -y $(cat /tmp/dnf.txt) && \
    dnf clean all

# Install Docker engine
RUN dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo && \
    dnf install -y docker-ce docker-ce-cli containerd.io && \
    systemctl enable docker

# Upgrade pip and install Python packages
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    pip3 install --no-cache-dir --ignore-installed --index-url https://pypi.org/simple -r /tmp/pip.txt

# Disable requiretty
RUN sed -i -e 's/^\(Defaults\s*requiretty\)/#--- \1/'  /etc/sudoers

# Set local inventory
RUN mkdir -p /etc/ansible && \
    echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts

# Add support for systemd
VOLUME ["/sys/fs/cgroup"]
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
