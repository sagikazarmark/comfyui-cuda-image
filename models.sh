#!/bin/bash

aria2c \
  -c \
  -x16 -s16 \
  --max-tries=10 --retry-wait=5 \
  --auto-file-renaming=false \
  --check-integrity=true \
  --allow-overwrite=false \
  --follow-metalink=true \
  -i models.txt

