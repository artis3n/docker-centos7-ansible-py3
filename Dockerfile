FROM centos:7
LABEL maintainer="Ari Kalfus"
ARG python_version=3.10.4

ENV container=docker
ENV pip_packages "ansible"

# Install systemd -- See https://hub.docker.com/_/centos/
RUN yum -y update; yum clean all; \
(cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;

# Install requirements.
RUN yum makecache fast \
 && yum -y install deltarpm epel-release initscripts \
 && yum -y update \
 && yum -y install \
     python \
     python-pip \
     sudo \
     which \
     gcc \
     openssl-devel \
     bzip2-devel \
     libffi-devel \
     make \
     openssl \
     openssl11 \
     openssl11-devel \
     readline \
     readline-devel \
 && yum clean all

 COPY ./md5sum.txt /tmp/

 # Build Python 3
 RUN mkdir /usr/local/openssl11 \
     && ln -s /usr/lib64/openssl11 /usr/local/openssl11/lib \
     && ln -s /usr/include/openssl11 /usr/local/openssl11/include \
     && curl -O https://www.python.org/ftp/python/$python_version/Python-$python_version.tgz \
     # Will block the image build if the checksum match fails
     && md5sum -c /tmp/md5sum.txt < Python-$python_version.tgz \
     && tar -xzf Python-$python_version.tgz \
     && cd Python-$python_version \
     && ./configure \
          --enable-optimizations \
          --with-ensurepip \
          --with-lto \
          --with-openssl=/usr/local/openssl11 --with-openssl-rpath=auto \
     && make \
     && make install \
     && ln -s /usr/local/bin/python3 /usr/bin/python3 \
     && cd .. && rm -rf Python-$python_version*

# Set up Python tools
RUN python3 -m pip install --upgrade pip setuptools wheel \
    && ln -s /usr/local/bin/pip3 /usr/bin/pip3

# Install Ansible via Pip.
RUN pip3 install $pip_packages

# Disable requiretty.
RUN sed -i -e 's/^\(Defaults\s*requiretty\)/#--- \1/'  /etc/sudoers

# Install Ansible inventory file.
RUN mkdir -p /etc/ansible
RUN echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts

VOLUME ["/sys/fs/cgroup"]
CMD ["/usr/lib/systemd/systemd"]
