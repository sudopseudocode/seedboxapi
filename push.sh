#!/bin/bash -x

# - https://medium.com/@komalminhas.96/a-step-by-step-guide-to-build-and-push-your-own-docker-images-to-dockerhub-709963d4a8bc
# - https://docs.docker.com/build/building/multi-platform

#docker build -t myanonamouse/seedboxapi:`date +%Y%m%d-%H%M` -t myanonamouse/seedboxapi:latest .
#docker push --platform linux/arm/v7,linux/arm64/v8,linux/amd64 -a myanonamouse/seedboxapi
docker buildx build --platform linux/arm/v7,linux/arm64/v8,linux/amd64 --push -t myanonamouse/seedboxapi:`date -u +%Y%m%d-%H%M` -t myanonamouse/seedboxapi:latest .
