ARG BASE_IMAGE=rockylinux:9
FROM ${BASE_IMAGE}

# Copy requirement files
COPY requirements/dnf.txt /tmp/dnf.txt
COPY requirements/pip.txt /tmp/pip.txt

# Clean up unnecessary systemd targets
RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/basic.target.wants/* \
    /lib/systemd/system/anaconda.target.wants/*

# Install base packages and requirements from dnf.txt
RUN dnf install -y dnf-plugins-core epel-release && \
    xargs -a /tmp/dnf.txt dnf install -y

# Install correct YAML development package based on Rocky version
RUN if grep -q 'release 9' /etc/redhat-release; then \
        echo "Rocky 9 detected: installing libyaml" && dnf install -y libyaml; \
    else \
        echo "Rocky 8 detected: installing libyaml-devel" && dnf install -y libyaml-devel; \
    fi

# Add Docker CE repo and install Docker engine
RUN dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo && \
    sed -i 's/\$releasever/8/g' /etc/yum.repos.d/docker-ce.repo && \
    dnf makecache && \
    dnf install -y docker-ce docker-ce-cli containerd.io && \
    systemctl enable docker && \
    dnf clean all

# Upgrade pip and install Python packages
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    pip3 install --no-cache-dir --ignore-installed --index-url https://pypi.org/simple -r /tmp/pip.txt

# Disable requiretty for sudo
RUN sed -i -e 's/^\(Defaults\s*requiretty\)/#--- \1/' /etc/sudoers

# Provide a default Ansible inventory
RUN mkdir -p /etc/ansible && \
    echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts

# Enable systemd and cgroup support
VOLUME ["/sys/fs/cgroup"]
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
