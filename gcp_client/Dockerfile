FROM ubuntu:22.04

COPY ./linectmpi-9ea7c5efdb6c.json /home/
COPY ./cloud_shell.py /home/

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
    && gcloud auth activate-service-account --key-file=/home/linectmpi-9ea7c5efdb6c.json --project=linectmpi

CMD ["sh", "-c", "export GOOGLE_APPLICATION_CREDENTIALS=/home/linectmpi-9ea7c5efdb6c.json && /bin/bash"]
