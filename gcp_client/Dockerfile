FROM ubuntu:22.04

COPY ./linectmpi-fcfdc9557818.json /home/
COPY ./cloud_shell.py /home/
COPY ./parameter.py /home

RUN yes | apt update \
    && yes | apt install curl \
    && yes | apt install openssh-client \
    && apt-get update && apt-get install -y python3

RUN cd /home \
    && curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-428.0.0-linux-x86_64.tar.gz \
    && tar -xf google-cloud-cli-428.0.0-linux-x86_64.tar.gz \
    && yes | ./google-cloud-sdk/install.sh \
    && export PATH=$PATH:/home/google-cloud-sdk/bin \
    && echo 'export PATH=$PATH:/home/google-cloud-sdk/bin' >> /root/.bashrc\
    && gcloud config set core/disable_usage_reporting true \
    && gcloud config set component_manager/disable_update_check true \
    && gcloud auth activate-service-account --key-file=/home/linectmpi-fcfdc9557818.json --project=linectmpi

CMD ["sh", "-c", "export GOOGLE_APPLICATION_CREDENTIALS=/home/linectmpi-fcfdc9557818.json && /bin/bash"]
