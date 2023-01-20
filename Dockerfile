FROM ubuntu:18.04
# Flutter setup instructions from https://blog.codemagic.io/how-to-dockerize-flutter-apps/
# Prerequisites
RUN apt update && apt install -y curl git unzip xz-utils zip libglu1-mesa openjdk-8-jdk wget

# Set up new user
RUN useradd -ms /bin/bash developer

ENV DEVELOPER=/home/developer
ENV DEVTOOLS=${DEVELOPER}/devtools
ENV BIN=${DEVELOPER}/bin

WORKDIR /tmp

#TODO(???): pass in driver and chrome urls to dockerfile so if they change we can reload them 
RUN wget https://chromedriver.storage.googleapis.com/109.0.5414.74/chromedriver_linux64.zip
RUN unzip chromedriver_linux64.zip
RUN mkdir -p ${BIN}
RUN mv chromedriver ${BIN}/
ENV PATH "${BIN}:$PATH"


RUN wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
RUN apt-get -y --fix-broken install ./google-chrome-stable_current_amd64.deb


WORKDIR /home/developer


USER developer

# Download Flutter SDK
RUN git clone https://github.com/flutter/flutter.git
ENV PATH "$PATH:/home/developer/flutter/bin"

# Run basic check to download Dark SDK
RUN flutter doctor


WORKDIR ${DEVTOOLS}

# DEVTOOLS SETUP
COPY --chown=developer:developer packages/devtools_app/pubspec.yaml ./packages/devtools_app/pubspec.yaml
COPY --chown=developer:developer packages/devtools_test/pubspec.yaml ./packages/devtools_test/pubspec.yaml
COPY --chown=developer:developer packages/devtools_shared/pubspec.yaml ./packages/devtools_shared/pubspec.yaml
COPY --chown=developer:developer tool/pubspec.yaml ./tool/pubspec.yaml
COPY --chown=developer:developer third_party ./third_party
# TODO WORKDIRS STILL OWNED BY ROOT
WORKDIR ${DEVTOOLS}/packages/devtools_app
RUN flutter pub get

WORKDIR ${DEVTOOLS}/packages/devtools_test
RUN flutter pub get

WORKDIR ${DEVTOOLS}/packages/devtools_shared
RUN flutter pub get

WORKDIR ${DEVTOOLS}/tool
RUN flutter pub get

WORKDIR ${DEVTOOLS}


COPY --chown=developer:developer . .

# TODO Move this to before COPY . .

# RUN ./tool/generate_code.sh

# RUN chmod -R +wrx ${DEVELOPER}

# To monday self. run flutter drive on it's own to see if that works now.








