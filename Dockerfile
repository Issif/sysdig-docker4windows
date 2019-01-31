FROM linuxkit/kernel:4.9.125 AS kernelsrc

FROM alpine:latest AS modulesrc
MAINTAINER Thomas Labarussias <issif+sysdig@gadz.org>
ARG SYSDIGVER=0.24.2
ARG KERNELVER=4.9.125
COPY --from=kernelsrc /kernel-dev.tar /
RUN apk add --no-cache --update wget ca-certificates \
   build-base gcc abuild binutils \
   bc \
   cmake \
   git \
   autoconf && \
   export KERNELDIR=/usr/src/linux-headers-$KERNELVER-linuxkit/ && \
   tar xf /kernel-dev.tar && \
   cd $KERNELDIR && \
   find /proc -type f -name "config.gz" -exec cp {} . \; &&
 #  zcat /proc/config.gz > .config && \
 #  zcat /proc/1/root/proc/config.gz > .config && \
   make olddefconfig && \
   mkdir -p /sysdig/build && \
   mkdir /src && \
   cd /src && \
   wget https://github.com/draios/sysdig/archive/$SYSDIGVER.tar.gz && \
   tar zxf $SYSDIGVER.tar.gz && \
   cd /sysdig/build && \
   cmake /src/sysdig-$SYSDIGVER && \
   make driver && \
   apk del wget ca-certificates \
   build-base gcc abuild binutils \
   bc \
   cmake \
   git \
   autoconf

FROM debian:unstable
MAINTAINER Sysdig <support@sysdig.com>

LABEL RUN="docker run -i -t -v /var/run/docker.sock:/host/var/run/docker.sock -v /dev:/host/dev -v /proc:/host/proc:ro -v /boot:/host/boot:ro -v /lib/modules:/host/lib/modules:ro -v /usr:/host/usr:ro --name NAME IMAGE"

ENV SYSDIG_HOST_ROOT /host
ENV SYSDIG_REPOSITORY stable
ENV HOME /root

COPY --from=modulesrc /sysdig/build/driver/sysdig-probe.ko /

RUN cp /etc/skel/.bashrc /root && cp /etc/skel/.profile /root

ADD http://download.draios.com/apt-draios-priority /etc/apt/preferences.d/

RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends \
	bash-completion \
	bc \
	clang-7 \
	curl \
	dkms \
	gnupg2 \
	ca-certificates \
	gcc \
	#gcc-5 \
	libc6-dev \
	libelf-dev \
	libelf1 \
	less \
	llvm-7 \
	procps \
	xz-utils \
 && rm -rf /var/lib/apt/lists/*

# Since our base Debian image ships with GCC 7 which breaks older kernels, revert the
# default to gcc-5.
# RUN rm -rf /usr/bin/gcc && ln -s /usr/bin/gcc-5 /usr/bin/gcc

RUN rm -rf /usr/bin/clang \
 && rm -rf /usr/bin/llc \
 && ln -s /usr/bin/clang-7 /usr/bin/clang \
 && ln -s /usr/bin/llc-7 /usr/bin/llc

RUN curl -s https://s3.amazonaws.com/download.draios.com/DRAIOS-GPG-KEY.public | apt-key add - \
 && curl -s -o /etc/apt/sources.list.d/draios.list http://download.draios.com/$SYSDIG_REPOSITORY/deb/draios.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends sysdig \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Some base images have an empty /lib/modules by default
# If it's not empty, docker build will fail instead of
# silently overwriting the existing directory
RUN rm -df /lib/modules \
 && ln -s $SYSDIG_HOST_ROOT/lib/modules /lib/modules

# debian:unstable head contains binutils 2.31, which generates
# binaries that are incompatible with kernels < 4.16. So manually
# forcibly install binutils 2.30-22 instead.
RUN curl -s -o binutils_2.30-22_amd64.deb http://snapshot.debian.org/archive/debian/20180622T211149Z/pool/main/b/binutils/binutils_2.30-22_amd64.deb \
 && curl -s -o libbinutils_2.30-22_amd64.deb http://snapshot.debian.org/archive/debian/20180622T211149Z/pool/main/b/binutils/libbinutils_2.30-22_amd64.deb \
 && curl -s -o binutils-x86-64-linux-gnu_2.30-22_amd64.deb http://snapshot.debian.org/archive/debian/20180622T211149Z/pool/main/b/binutils/binutils-x86-64-linux-gnu_2.30-22_amd64.deb \
 && curl -s -o binutils-common_2.30-22_amd64.deb http://snapshot.debian.org/archive/debian/20180622T211149Z/pool/main/b/binutils/binutils-common_2.30-22_amd64.deb \
 && dpkg -i *binutils*.deb

COPY ./docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["bash"]
