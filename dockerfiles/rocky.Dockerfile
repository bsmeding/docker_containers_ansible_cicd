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

# Enable dev repo (CRB for Rocky 9, PowerTools for Rocky 8)
# Install OS and Docker requirements
# Install system packages
RUN dnf install -y dnf-plugins-core epel-release && \
    xargs -a /tmp/dnf.txt dnf install -y && \
    source /etc/os-release && \
    if [[ "$VERSION_ID" == "9" ]]; then \
        dnf install -y libyaml; \
    else \
        dnf install -y libyaml-devel; \
    fi && \
    dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo && \
    sed -i 's/\$releasever/8/g' /etc/yum.repos.d/docker-ce.repo && \
    dnf install -y docker-ce docker-ce-cli containerd.io && \
    dnf clean all && \
    systemctl enable docker

# Upgrade pip and install Python requirements
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    pip3 install --no-cache-dir --ignore-installed --index-url https://pypi.org/simple -r /tmp/pip.txt

# Disable requiretty in sudo
RUN sed -i -e 's/^\(Defaults\s*requiretty\)/#--- \1/' /etc/sudoers

# Set up local Ansible inventory
RUN mkdir -p /etc/ansible && \
    echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts

# Systemd + cgroups support
VOLUME ["/sys/fs/cgroup"]
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
