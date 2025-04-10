ARG BASE_IMAGE=rockylinux:9
FROM ${BASE_IMAGE}

COPY requirements/dnf.txt /tmp/dnf.txt
COPY requirements/pip.txt /tmp/pip.txt


# Install systemd -- See https://hub.docker.com/_/centos/
RUN rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;

# Use direct Rocky mirror list
# RUN sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/Rocky-*.repo && \
#     sed -i 's|^#baseurl=http://dl.rockylinux.org|baseurl=http://dl.rockylinux.org|g' /etc/yum.repos.d/Rocky-*.repo

# Detect Rocky version and enable the correct dev repo
RUN dnf install -y dnf-plugins-core && \
    if grep -q 'release 8' /etc/redhat-release; then \
        dnf config-manager --enable powertools; \
    else \
        dnf config-manager --set-enabled crb; \
    fi


# Install requirements
RUN dnf install -y epel-release && \
    dnf install -y $(cat /tmp/dnf.txt) && \
    dnf clean all

# Upgrade pip to latest version
RUN python3 -m pip install --upgrade pip setuptools wheel

# Upgrade pip to latest version and install packages
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    pip3 install --no-cache-dir --ignore-installed --index-url https://pypi.org/simple -r /tmp/pip.txt

# Disable requiretty
RUN sed -i -e 's/^\(Defaults\s*requiretty\)/#--- \1/'  /etc/sudoers

# Set localhost Ansible inventory file
RUN mkdir -p /etc/ansible
RUN echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts


VOLUME ["/sys/fs/cgroup"]
CMD ["/lib/systemd/systemd"]
