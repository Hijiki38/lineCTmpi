#syntax=docker/dockerfile:1
FROM sl:7
COPY . /app
RUN cd app \
    && yum -y install gcc-gfortran.x86_64 \
    && yum -y install gcc-c++ \
    && yum -y install wget \
    && yum -y install perl \
    && yum -y install make \
    && yum -y install sudo
RUN chmod -R 777 /app
RUN wget https://www.open-mpi.org/software/ompi/v4.0/downloads/openmpi-4.0.7.tar.gz --no-check-certificate \
    && tar xvf openmpi-4.0.7.tar.gz
RUN cd openmpi-4.0.7 \
    && mkdir /opt/openMPI \
    && ./configure --prefix=/opt/openMPI CC=gcc CXX=g++ F77=gfortran FC=gfortran \
    && make \
    && make install
RUN echo PATH=/opt/openMPI/bin:\$PATH >> ~/.bashrc \
    && echo LD_LIBRARY_PATH=/opt/openMPI/lib:\$LD_LIBRARY_PATH >> ~/.bashrc \
    && echo MANPATH=/opt/openMPI/share/man:\$MANPATH >> ~/.bashrc \
    && echo export PATH LD_LIBRARY_PATH MANPATH >> ~/.bashrc \
    && . ~/.bashrc
RUN useradd -s /bin/bash user \
    && usermod -aG wheel user
USER user
WORKDIR /app
#CMD ["./startup.sh"]
