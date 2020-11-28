ARG NODE_VERSION=15.3

###
# @base
# Setup base image with default node/env/config
###
FROM node:$NODE_VERSION-slim AS base

ARG ROOT_DIR=/usr/src
ARG NODE_ENV=dev

ENV ROOT_DIR=$ROOT_DIR
ENV NODE_ENV=$NODE_ENV
ENV PATH=$PATH:$ROOT_DIR/node_modules/.bin

# # Installs latest Chromium package.
RUN apt-get update \
    && apt-get install -y wget gnupg \
    && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
    && apt-get update \
    && apt-get install -y google-chrome-stable fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf libxss1 sudo \
      --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Tell Puppeteer to skip installing Chrome. We'll be using the installed package.
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome

# Add user so we don't need --no-sandbox.
RUN addgroup chrome && useradd -g chrome chrome \
    && mkdir -p /home/chrome/Downloads /app /Users \
    && chown -R chrome:chrome /home/chrome \
    && chown -R chrome:chrome /Users \
    && chown -R chrome:chrome $ROOT_DIR

WORKDIR $ROOT_DIR

###
# @base => @installed
# Build image with dev npm modules
###
FROM base AS installed

# Set up .npmrc
ARG NPM_MAX_SOCKETS=50
RUN echo "registry=https://registry.npmjs.org/" > ~/.npmrc && \
    echo "maxsockets=${NPM_MAX_SOCKETS}" >> ~/.npmrc && \
    echo "progress=true" >> ~/.npmrc

# Install app dependencies
ADD package.json package-lock.json ./

###
# @installed => @dev
# Add source to installed modules for dev image
# (Source is added after install to avoid rebuilding unnecessarily)
###
FROM installed AS dev
USER root
RUN apt-get update \
    && apt-get install -y build-essential python \
    && npm install --verbose \
    && apt-get remove -y build-essential python \
    && apt-get purge -y build-essential python \
    && apt-get -y autoremove \
    && rm -rf /var/lib/apt/lists/* \
    && chown -R chrome:chrome .
USER chrome
