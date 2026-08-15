# testing with:
#   sudo bcvk ephemeral run-ssh localhost/image-name:latest --console
# or
#   sudo podman build -t qwer:latest . ; sudo image-builder build --output-dir /var/lib/libvirt/images --blueprint blueprint.toml --verbose --bootc-default-fs ext4 --bootc-ref localhost/qwer:latest raw
#   sudo podman build -t qwer:latest . && sudo image-builder build --output-dir /var/lib/libvirt/images --blueprint blueprint.toml --verbose --bootc-default-fs ext4 --bootc-ref localhost/qwer:latest raw
# for qemu/kvm virsh testing

# https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/using_image_mode_for_rhel_to_build_deploy_and_manage_operating_systems/managing-kernel-arguments-in-bootc-systems

# for partition configuration: 
#   https://osbuild.org/docs/developer-guide/projects/image-builder/advanced/bootc/sources-of-configuration/

# TODO:
# * .config, .local, bin owned by root on initial load
# obsidian not found; bashrc path add?
# prompt doesn't exist, probably missing bashrc stuff



FROM quay.io/fedora/fedora-bootc:44

# I'm thinking...
#   1   root system (wm, file management, etc)
#   2   additional items (serial comms, web browsers for dev, manual installs etc)
#   3   dev stuff
#   3.1 C#
#   3.2 Rust?
#   3.3 ESP32
#   4   experimental
#   4.1 root
#   4.2 user

# ==============================================================================
#   1.0   core components + configuration
#   this is the common stuff that makes the system useable, things like the GUI,
#   common applications, etc.
# ==============================================================================

# this will suppress output from the journal to the console.  without this, it 
# spams journal entries to the console, which interferes with normal use
# for setting configuration
#   man sysctl.d
#   https://www.kernel.org/doc/html/latest/core-api/printk-basics.html
#   https://tldp.org/LDP/abs/html/here-docs.html (w/r/t "heredocument" format)
#RUN echo "kernel.printk = 3 4 1 7" >> /etc/sysctl.d/10-printk.conf
COPY <<EOF /etc/sysctl.d/10-printk.conf
  kernel.printk = 3 4 1 7
EOF

# ====================
#   1.1   RPM Fusion
# ====================
RUN dnf --assumeyes install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm



# ==================
#   1.2   packages
# ==================

RUN dnf install --assumeyes \
    neovim \
    git \
    tmux \
    sddm \
    sway \
    rofi \
    thunar \
    firefox \
    waybar \
    glibc-langpack-en \
    chromium \
    minicom \
    lrzsz \
    tio

# ENV LANG=en_US.UTF-8
# ENV LANGUAGE=en_US:en
# ENV LC_ALL=en_US.UTF-8
# ENV TZ=America/New_York
#RUN localectl set-locale en_US.UTF-8
#RUN timedatectl set-timezone America/New_York

# =======
#   GUI
# =======

RUN dnf install --assumeyes  cmus
RUN dnf swap --assumeyes  ffmpeg-free ffmpeg --allowerasing


RUN echo 'include /var/home/rob/.config/sway/config.d/*' >> /etc/sway/config


# ==================================
#   https://linuxize.com/post/how-to-create-users-in-linux-using-the-useradd-command/
# have to escape password with single quotes, otherwise it gets parsed incorrectly in the shell
# mkpasswd --salt=4hkdXiEWlvvhEakz --method=sha512crypt --rounds=695876
RUN useradd \
    --groups wheel \
    --user-group \
    --uid 1000 \
    --password '$6$rounds=695876$4hkdXiEWlvvhEakz$mxU4VMtyFCf8S6dELVqIsM1sLU5e5ickJMreLWCJy8tPGDF9P9poDXvEWT5NFUw4B08kzu6s/PCHsb8bimCWc0' \
    --create-home \
    --home-dir /var/home/rob \
    rob






# ==============================================================================
#   2.0   specific components
#   this is for applications in support of more specific usecases (VSC, etc)
# ==============================================================================

# =============
#   2.1   IDE
# =============
RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc
RUN sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
# --assumeyes prevents the build process from dying when dnf reads from STDIN
RUN dnf install --assumeyes code \
                            foot

# =================
#   2.2   .NET 10
# =================
RUN dnf install --assumeyes dotnet-sdk-10.0


# ImHex
WORKDIR /temp-root
RUN curl --location --output imhex-1.38.1-Fedora-43-x86_64.rpm  https://github.com/WerWolv/ImHex/releases/download/v1.38.1/imhex-1.38.1-Fedora-43-x86_64.rpm
RUN echo "79658c0b21bc176fb25d92d16e0e26b909cb8345f51c833ecab059ae2253a7dd  imhex-1.38.1-Fedora-43-x86_64.rpm" | sha256sum --check --quiet || false
RUN dnf --assumeyes install ./imhex-1.38.1-Fedora-43-x86_64.rpm
RUN rm imhex-1.38.1-Fedora-43-x86_64.rpm


# JetBrains Mono font
USER rob
WORKDIR /temp-user
# /temp-user/jbm/fonts/fft/*
RUN curl --location --output JetBrainsMono-2.304.zip            https://download.jetbrains.com/fonts/JetBrainsMono-2.304.zip
RUN echo "6f6376c6ed2960ea8a963cd7387ec9d76e3f629125bc33d1fdcd7eb7012f7bbf  JetBrainsMono-2.304.zip" | sha256sum --check --quiet || false
RUN unzip -d jbm JetBrainsMono-2.304.zip

# /var/home/rob/.local/share/fonts/j
WORKDIR /var/home/rob/.local/share/fonts/j
RUN cp /temp-user/jbm/fonts/ttf/* .


# Obsidian
WORKDIR /var/home/rob/bin
RUN curl --location --output obsidian-1.12.7.tar.gz             https://github.com/obsidianmd/obsidian-releases/releases/download/v1.12.7/obsidian-1.12.7.tar.gz
RUN echo "fcbe08b111d9c1fdb09b9c08952b06e1c829c62163eba2584c4b4ec859be079d  obsidian-1.12.7.tar.gz" | sha256sum --check --quiet || false
RUN tar --extract --file obsidian-1.12.7.tar.gz
RUN ln -s ./obsidian-1.12.7/obsidian ./obsidian
RUN rm obsidian-1.12.7.tar.gz

RUN code --install-extension ms-dotnettools.csdevkit
# re-use the default cache directory to prevent doubling up on package use; in
# 2026 there's apparently no way to disable the cache during restore, so if your
# local repo is different from the cache directory, it will copy everything from
# your local repo to the cache, which is just a waste of space
#RUN dotnet nuget add source --name local-repo ~/.nuget/packages
# if the directory doesn't exist, it whines at you during restore
#RUN mkdir ~/.nuget/packages

COPY --chown=rob:rob ./misc/dotnet-packages /temp-user/dotnet-package-restore/
WORKDIR /temp-user/dotnet-package-restore
#RUN dotnet restore packages-to-restore.slnx

# https://github.com/dotnet/sdk/issues/46165
# for some reason, without this RequiresAspNetWebAssets property, dotnet restore doesn't include Microsoft.AspNetCore.App.Internal.Assets as a dependency
RUN find . -iname '*.csproj' -exec dotnet restore /p:RequiresAspNetWebAssets=true {} \;

# ============== above stuff is good
USER root

# migrate to just using a folder and loose files
# per https://docs.docker.com/reference/dockerfile/#copy :
# "The directory itself isn't copied, only its contents."
COPY --chown=rob:rob ./home /var/home/rob





# ==============================================================================
#   WIP / experimental
#   this is for things that are current a WIP; placed at the end to avoid
#   unnecessary podman layer builds.  when done, move into one of the sections
#   above
# ==============================================================================
USER rob
WORKDIR /temp-user
RUN code --install-extension nanoframework.vscode-nanoframework
RUN dotnet tool install -g nanoff
RUN ln -s /var/home/rob/.dotnet/tools/nanoff /var/home/rob/bin/nanoff

WORKDIR /var/home/rob/bin
RUN curl --location --output esptool-v5.3.0-linux-amd64.tar.gz             https://github.com/espressif/esptool/releases/download/v5.3.0/esptool-v5.3.0-linux-amd64.tar.gz
RUN echo "46ca7b52c309790bc4d140990680f6088e8cad40b230fda6999661efc24845b6  esptool-v5.3.0-linux-amd64.tar.gz" | sha256sum --check --quiet || false
RUN tar --extract --file esptool-v5.3.0-linux-amd64.tar.gz
RUN ln -s ./esptool-linux-amd64/esptool ./esptool
RUN rm esptool-v5.3.0-linux-amd64.tar.gz

RUN ln -s /usr/bin/xbuild ./msbuild

WORKDIR /var/home/rob/esp-firmware
RUN curl --location --output ESP32_S3_QUAD-1.17.0.285.zip https://dl.cloudsmith.io/public/net-nanoframework/nanoframework-images/raw/names/ESP32_S3_QUAD/versions/1.17.0.285/ESP32_S3_QUAD-1.17.0.285.zip
RUN echo "9719576b28d925fe9cd0b5edd7a06c0d0ceea68d1fff3bca44671f80b8ab56ea  ESP32_S3_QUAD-1.17.0.285.zip" | sha256sum --check --quiet || false
RUN unzip -d ESP32_S3_QUAD-1.17.0.285 ESP32_S3_QUAD-1.17.0.285.zip
RUN curl --location --output ESP32_S3_OCTAL-1.17.0.285.zip https://dl.cloudsmith.io/public/net-nanoframework/nanoframework-images/raw/names/ESP32_S3_OCTAL/versions/1.17.0.285/ESP32_S3_OCTAL-1.17.0.285.zip
RUN echo "4f89c851ef18719b8020f29abb90e365d9672f468d8fd8567bf496304a2e9c0c  ESP32_S3_OCTAL-1.17.0.285.zip" | sha256sum --check --quiet || false
RUN unzip -d ESP32_S3_OCTAL-1.17.0.285 ESP32_S3_OCTAL-1.17.0.285.zip

#WORKDIR /var/home/rob/.nuget/99-nuget-cli-hack


USER root
# necessary for nanoff to run, weirdly
RUN dnf install --assumeyes dotnet-runtime-8.0 mono-complete mono-developer
# installs to /usr/bin/nuget
#RUN dnf install --assumeyes nuget
RUN curl --location --output /usr/local/bin/nuget.exe https://dist.nuget.org/win-x86-commandline/latest/nuget.exe

# =========
#   final
#   this is for manual in-container moves and such
# =========
USER rob

# dotnet restore effectively downloads packages and their dependencies by
# "restoring" them and caching the results.  this moves all those files to a
# specific repo directory that we won't want to touch, and then we switch the
# cache to a directry in `/tmp`.
# my preference is to rename the original cache directory instead and not have
# a `packages` directory, so as to not muddle with normal workflow habits
# elsewhere
RUN mv /var/home/rob/.nuget/packages /var/home/rob/.nuget/00-stock-packages
RUN dotnet nuget add source --name local /var/home/rob/.nuget/00-stock-packages

# make a directory for temporary packages (things we might be operating on)
RUN mkdir /var/home/rob/.nuget/01-temporary-packages
RUN dotnet nuget add source --name temporary /var/home/rob/.nuget/01-temporary-packages

# move the package cache to a tmpfs mount
RUN dotnet nuget config set globalPackagesFolder /tmp/nuget-package-cache

# disable the default source - this system will be airgapped, so this will only
# cause timeouts while it tries to connect to something it will never be able to
# connect to.
RUN dotnet nuget disable source nuget.org


# this is extremely stupid.  nuget cli (not `dotnet nuget`) apparently won't see
# packages if they're in directories?  idk.  it wouldn't read from the typical
# dotnet layout, with `packagename/packageversion` hierarchy.  if we symlink all
# our packages into a flat directory, we can make it available to the nuget cli
# in general, which should allow the nanoframework extension to properly resolve
# packages
#RUN mkdir /var/home/rob/.nuget/99-nuget-cli-hack
#RUN find /var/home/rob/.nuget -iname '*.nupkg' | xargs -I {} sh -c 'ln --symbolic --force {} /var/home/rob/.nuget/99-nuget-cli-hack/$(basename {})'
# copy the dotnet cli nuget config to the nuget cli config location.  why????
RUN mkdir -p /var/home/rob/.config/NuGet/ && cp /var/home/rob/.nuget/NuGet/NuGet.Config /var/home/rob/.config/NuGet/NuGet.Config
#RUN nuget sources add -Name hack -Source /var/home/rob/.nuget/99-nuget-cli-hack



USER root
RUN rm -rf /temp-root
RUN rm -rf /temp-user


# from https://learn.microsoft.com/en-us/nuget/reference/nuget-exe-cli-reference?tabs=macos#installing-nugetexe
# the stock nuget package for fedora was not enough
COPY <<-"EOF" /usr/bin/nuget
#!/bin/sh
mono /usr/local/bin/nuget.exe "$@"
EOF
RUN chmod +x /usr/bin/nuget

# above seems to work

#COPY <<-"EOF" /usr/bin/msbuild
COPY <<-"EOF" /usr/lib/mono/xbuild/14.0/bin/msbuild
#!/usr/bin/sh
MONO_GC_PARAMS="nursery-size=64m,$MONO_GC_PARAMS" exec /usr/bin/mono $MONO_OPTIONS /usr/lib/mono/xbuild/14.0/bin/xbuild.exe "$@"
EOF
RUN chmod +x /usr/lib/mono/xbuild/14.0/bin/msbuild

RUN <<EOF
echo 'PATH="/usr/lib/mono/xbuild/14.0/bin/:$PATH"' >> /var/home/rob/.bashrc
echo 'export PATH' >> /var/home/rob/.bashrc
EOF
