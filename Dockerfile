# FROM ubuntu:18.04
FROM trzeci/emscripten:sdk-tag-1.38.31-64bit

# SHELL ["/bin/bash", "-c"]

RUN apt-get update && apt-get install --no-install-recommends -y automake libtool cmake libglib2.0-dev closure-compiler

# RUN wget https://s3.amazonaws.com/mozilla-games/emscripten/releases/emsdk-portable.tar.gz && tar xzvf emsdk-portable.tar.gz

# RUN cd emsdk-portable && ./emsdk update && ./emsdk install latest && ./emsdk activate latest && source ./emsdk-env.sh

WORKDIR /src/ffmpeg.js

COPY . .

RUN git submodule init && git submodule update --recursive

CMD ["make", "clean", "all"]
