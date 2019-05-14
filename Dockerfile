FROM linuxkit/kernel:4.9.125 AS kernelsrc

FROM alpine:latest AS modulesrc
MAINTAINER Thomas Labarussias <issif+sysdig@gadz.org>
ARG SYSDIGVER=0.25
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
   find /proc -type f -name "config.gz" -exec cp {} . \; && \
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

FROM sysdig/sysdig:0.24.2 

COPY --from=modulesrc /sysdig/build/driver/sysdig-probe.ko /

COPY ./docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["bash"]
