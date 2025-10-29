# https://forums.developer.nvidia.com/t/how-to-install-torchaudio-base-on-the-image-nvcr-io-nvidia-pytorch-25-08-py3/346366/10
FROM nvcr.io/nvidia/pytorch:25.09-py3 AS torchaudio

RUN git clone -b release/2.9 https://github.com/pytorch/audio

WORKDIR /workspace/audio

RUN pip wheel -v -e . --no-use-pep517 --no-deps -w dist


# https://docs.nvidia.com/deeplearning/frameworks/pytorch-release-notes/rel-25-09.html
# https://catalog.ngc.nvidia.com/orgs/nvidia/containers/pytorch?version=25.09-py3
FROM nvcr.io/nvidia/pytorch:25.09-py3

ENV PIP_DISABLE_PIP_VERSION_CHECK="true"
ENV PIP_ROOT_USER_ACTION="ignore"

RUN rm -rf /workspace/*

RUN set -xe && \
  pip uninstall --yes pynvml && \
  pip install --no-deps torchsde

COPY --from=torchaudio /workspace/audio/dist/ /usr/local/src/wheel
RUN pip install --no-deps /usr/local/src/wheel/*.whl

RUN pip list --format freeze | grep torch > /etc/pip/constraint.txt

# Missing from requirements.txt?
RUN pip install trampoline av

ENV COMFY_CLI_VERSION=1.5.2
RUN pip install comfy-cli==${COMFY_CLI_VERSION}

RUN comfy --skip-prompt tracking disable

ENV COMFY_VERSION=0.3.66
RUN comfy --skip-prompt --workspace ./comfy install --skip-torch-or-directml --skip-requirement --nvidia --version ${COMFY_VERSION}

RUN set -xe && \
  grep -vE torch comfy/requirements.txt > requirements.txt && \
  pip install -r requirements.txt

RUN cat <<EOF > extra_model_paths.yaml
docker:
    base_path: /workspace/data
    download_model_base: /workspace/data/models
    is_default: true
    checkpoints: models/checkpoints/
    clip: |
        models/text_encoders/
        models/clip/
    clip_vision: models/clip_vision/
    configs: models/configs/
    controlnet: models/controlnet/
    diffusion_models: |
        models/diffusion_models
        models/unet
    embeddings: models/embeddings/
    loras: models/loras/
    upscale_models: models/upscale_models/
    vae: models/vae/
    custom_nodes: custom_nodes/
EOF

# TODO: set output and user?
RUN set -xe && \
  comfy set-default ./comfy --launch-extras="--extra-model-paths-config /workspace/extra_model_paths.yaml --user-directory /workspace/data/user --listen 0.0.0.0" && \
  mkdir -p /workspace/data/custom_nodes

EXPOSE 8188
VOLUME /workspace/data

CMD ["comfy", "launch"]

