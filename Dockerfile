FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

RUN apt update
RUN apt install software-properties-common -y
RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt update
RUN apt-get update

ARG DEBIAN_FRONTEND=noninteractive

RUN apt install python3.11-full -y
RUN apt install python3.11-venv -y
RUN apt install python3.11-dev -y
RUN rm /usr/bin/python3
RUN ln -s python3.11 /usr/bin/python3
RUN python3 --version
RUN apt-get install -y curl
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 && pip install --upgrade pip

# Copy the Apache Beam worker dependencies from the Beam Python 3.11 SDK image.
COPY --from=apache/beam_python3.11_sdk:2.61.0 /opt/apache/beam /opt/apache/beam

RUN pip install --no-cache-dir -vvv apache-beam[gcp]==2.61.0
RUN pip install openai>=1.52.2 vllm>=0.6.3
RUN pip install triton>=3.1.0
RUN apt install libcairo2-dev pkg-config python3-dev -y
RUN pip install pycairo
RUN pip check

RUN python3 -c 'from huggingface_hub import HfFolder; HfFolder.save_token("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")'

ENV TPU_SKIP_MDS_QUERY=1
ENV TPU_HOST_BOUNDS=1,1,1
ENV TPU_WORKER_HOSTNAMES=localhost
ENV TPU_WORKER_ID=0
ENV TPU_ACCELERATOR_TYPE=tpu-v5p-slice
ENV TPU_CHIPS_PER_HOST_BOUNDS=2,2,1

# Set the entrypoint to Apache Beam SDK worker launcher.
ENTRYPOINT [ "/opt/apache/beam/boot" ]