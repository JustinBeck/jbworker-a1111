# ---------------------------------------------------------------------------- #
#                         Stage 1: Download the models                         #
# ---------------------------------------------------------------------------- #
FROM alpine/git:2.36.2 as download

COPY builder/clone.sh /clone.sh

# Clone the repos and clean unnecessary files
RUN . /clone.sh taming-transformers https://github.com/CompVis/taming-transformers.git 24268930bf1dce879235a7fddd0b2355b84d7ea6 && \
    rm -rf data assets **/*.ipynb

RUN . /clone.sh stable-diffusion-stability-ai https://github.com/Stability-AI/stablediffusion.git 47b6b607fdd31875c9279cd2f4f16b92e4ea958e && \
    rm -rf assets data/**/*.png data/**/*.jpg data/**/*.gif

RUN . /clone.sh CodeFormer https://github.com/sczhou/CodeFormer.git c5b4593074ba6214284d6acd5f1719b6c5d739af && \
    rm -rf assets inputs

RUN . /clone.sh BLIP https://github.com/salesforce/BLIP.git 48211a1594f1321b00f14c9f7a5b4813144b2fb9 && \
    . /clone.sh k-diffusion https://github.com/crowsonkb/k-diffusion.git 5b3af030dd83e0297272d861c19477735d0317ec && \
    . /clone.sh clip-interrogator https://github.com/pharmapsychotic/clip-interrogator 2486589f24165c8e3b303f84e9dbbea318df83e8

#RUN wget -O /model.safetensors https://civitai.com/api/download/models/15236
#ADD mdjrny-v4.ckpt /
#ADD anything-v4.5-pruned.ckpt /
#ADD model_disney.safetensors /
#ADD model_rev.safetensors /
ADD darkSushiMix.safetensors /
#ADD model2.safetensors /

# ---------------------------------------------------------------------------- #
#                        Stage 3: Build the final image                        #
# ---------------------------------------------------------------------------- #
FROM python:3.10.9-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    LD_PRELOAD=libtcmalloc.so \
    ROOT=/stable-diffusion-webui \
    PYTHONUNBUFFERED=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && \
    apt install -y \
    fonts-dejavu-core rsync git jq moreutils aria2 wget libgoogle-perftools-dev procps && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

RUN --mount=type=cache,target=/cache --mount=type=cache,target=/root/.cache/pip \
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

RUN --mount=type=cache,target=/root/.cache/pip \
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git reset --hard 89f9faa63388756314e8a1d96cf86bf5e0663045 && \
    pip install -r requirements_versions.txt

COPY --from=download /repositories/ ${ROOT}/repositories/
#COPY --from=download /mdjrny-v4.ckpt /stable-diffusion-webui/models/Stable-diffusion/mdjrny-v4.ckpt
#COPY --from=download /anything-v4.5-pruned.ckpt /stable-diffusion-webui/models/Stable-diffusion/anything-v4.5-pruned.ckpt
#COPY --from=download /model_disney.safetensors /stable-diffusion-webui/models/Stable-diffusion/model_disney.safetensors
#OPY --from=download /model_rev.safetensors /stable-diffusion-webui/models/Stable-diffusion/model_rev.safetensors
COPY --from=download /darkSushiMix.safetensors /stable-diffusion-webui/models/Stable-diffusion/darkSushiMix.safetensors
#COPY --from=download /model2.safetensors /stable-diffusion-webui/models/Stable-diffusion/model2.safetensors

RUN mkdir ${ROOT}/interrogate && cp ${ROOT}/repositories/clip-interrogator/data/* ${ROOT}/interrogate
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r ${ROOT}/repositories/CodeFormer/requirements.txt

# Install Python dependencies (Worker Template)
COPY builder/requirements.txt /requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip && \
    pip install --upgrade -r /requirements.txt --no-cache-dir && \
    rm /requirements.txt

ARG SHA=89f9faa63388756314e8a1d96cf86bf5e0663045
RUN --mount=type=cache,target=/root/.cache/pip \
    cd stable-diffusion-webui && \
    git fetch && \
    git reset --hard ${SHA} && \
    pip install -r requirements_versions.txt

ADD src .

COPY builder/cache.py /stable-diffusion-webui/cache.py
#RUN cd /stable-diffusion-webui && python cache.py --use-cpu=all --ckpt /stable-diffusion-webui/models/Stable-diffusion/mdjrny-v4.ckpt
#RUN cd /stable-diffusion-webui && python cache.py --use-cpu=all --ckpt /stable-diffusion-webui/models/Stable-diffusion/anything-v4.5-pruned.ckpt && python cache.py --use-cpu=all --ckpt /stable-diffusion-webui/models/Stable-diffusion/anything-v4.5-pruned.ckpt
#RUN cd /stable-diffusion-webui && python cache.py --use-cpu=all --ckpt /stable-diffusion-webui/models/Stable-diffusion/model_disney.safetensors && python cache.py --use-cpu=all --ckpt /stable-diffusion-webui/models/Stable-diffusion/model_disney.safetensors
#RUN cd /stable-diffusion-webui && python cache.py --use-cpu=all --ckpt /stable-diffusion-webui/models/Stable-diffusion/model_rev.safetensors && python cache.py --use-cpu=all --ckpt /stable-diffusion-webui/models/Stable-diffusion/model_rev.safetensors
RUN cd /stable-diffusion-webui && python cache.py --use-cpu=all --ckpt /stable-diffusion-webui/models/Stable-diffusion/darkSushiMix.safetensors && python cache.py --use-cpu=all --ckpt /stable-diffusion-webui/models/Stable-diffusion/darkSushiMix.safetensors
#RUN cd /stable-diffusion-webui && python cache.py --use-cpu=all --ckpt /stable-diffusion-webui/models/Stable-diffusion/model2.safetensors && python cache.py --use-cpu=all --ckpt /stable-diffusion-webui/models/Stable-diffusion/model2.safetensors
# Cleanup section (Worker Template)
RUN apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

RUN chmod +x /start.sh
CMD /start.sh
