FROM ubuntu:18.04
# Flutter setup instructions from https://blog.codemagic.io/how-to-dockerize-flutter-apps/
# Prerequisites
RUN apt update && apt install -y curl git unzip xz-utils zip libglu1-mesa openjdk-8-jdk wget

# Set up new user
RUN useradd -ms /bin/bash developer
USER developer
WORKDIR /home/developer

# Prepare Android directories and system variables
RUN mkdir -p Android/sdk
ENV ANDROID_SDK_ROOT /home/developer/Android/sdk
RUN mkdir -p .android && touch .android/repositories.cfg

# Set up Android SDK
RUN wget -O sdk-tools.zip https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip
RUN unzip sdk-tools.zip && rm sdk-tools.zip
RUN mv tools Android/sdk/tools
RUN cd Android/sdk/tools/bin && yes | ./sdkmanager --licenses
RUN cd Android/sdk/tools/bin && ./sdkmanager "build-tools;29.0.2" "patcher;v4" "platform-tools" "platforms;android-29" "sources;android-29"
ENV PATH "$PATH:/home/developer/Android/sdk/platform-tools"

# Download Flutter SDK
# TODO: this is where we will get the candidate
RUN git clone https://github.com/flutter/flutter.git
ENV PATH "$PATH:/home/developer/flutter/bin"

# Run basic check to download Dark SDK
RUN flutter doctor


# DEVTOOLS SETUP
COPY /packages/devtools_app/pubspec.yaml ./packages/devtools_app/pubspec.yaml
COPY /packages/devtools_test/pubspec.yaml ./packages/devtools_test/pubspec.yaml
COPY /packages/devtools_shared/pubspec.yaml ./packages/devtools_shared/pubspec.yaml
COPY /third_party ./third_party

WORKDIR /packages/devtools_app

RUN flutter pub get

COPY . .
