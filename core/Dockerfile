#syntax=docker/dockerfile:1
FROM rockylinux:8
ARG cpus=1
COPY . /app
RUN dnf -y update \
    && dnf -y install \
        gcc-gfortran \
        gcc-c++ \
        wget \
        perl \
        make \
        sudo \
        procps-ng \
        tar \
        gzip \
    && dnf clean all
RUN chmod -R 777 /app \
    && chmod -R 777 /app/share
RUN wget https://www.open-mpi.org/software/ompi/v4.0/downloads/openmpi-4.0.7.tar.gz --no-check-certificate \
    && tar xvf openmpi-4.0.7.tar.gz
RUN cd openmpi-4.0.7 \
    && mkdir -p /opt/openMPI \
    && ./configure --prefix=/opt/openMPI CC=gcc CXX=g++ F77=gfortran FC=gfortran \
    && make -j"${cpus}" \
    && make -j"${cpus}" install
#以下のパス設定はコンテナに反映されておらず、.ymlで同じことをしているため不要かもしれない
#RUN echo PATH=/opt/openMPI/bin:\$PATH >> ~/.bashrc \ 
#    && echo LD_LIBRARY_PATH=/opt/openMPI/lib:\$LD_LIBRARY_PATH >> ~/.bashrc \
#    && echo MANPATH=/opt/openMPI/share/man:\$MANPATH >> ~/.bashrc \
#    && echo export PATH LD_LIBRARY_PATH MANPATH >> ~/.bashrc \
#    && . ~/.bashrc
RUN useradd -s /bin/bash user \
    && usermod -aG wheel user
USER user
WORKDIR /app
#CMD ["./startup.sh"]
