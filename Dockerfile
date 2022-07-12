FROM ubuntu:20.04 as base
ENV DEBIAN_FRONTEND=noninteractive

# This docker file builds an image with an OpenVPN executable that is statically
# linked to the libraries it needs. It is compiled to run on a Ubiquity USG device.

# All build artifacts can be found in the /build directory. The 'openvpn' executable 
# is in /build/sbin and the 'plugins' directory is in /build/lib/openvpn_static.
# Beware that this openvpn is configured to search for plugins in /usr/lib/openvpn_static/plugins.
# Hence, the plugin libraries should be copied to that directory on the USG.

# The OpenVPN build will be based on the below versions
ENV OPENVPN_VERSION=2.5.7 \
	LZO_VERSION=2.10 \
    LZ4_VERSION=1.9.2 \
	OPENSSL_VERSION=1.1.1h \
	PKCS11_HELPER_VERSION=1.29.0 \
	PAM_VERSION=1.5.2
	
# All package dependencies in alphabetic order
RUN apt update && apt install -y \
	autoconf \
	autopoint \
	bison \
	cpp-10-mips64-linux-gnuabi64 \
	flex \
	gcc-10-mips64-linux-gnuabi64 \
	gcc-mips64-linux-gnuabi64 \
	gettext \
	libc6-mips64-cross \
    libc6-dev-mips64-cross \
	libfindbin-libs-perl \
	libgcc-10-dev-mips64-cross \
	libtool \
	linux-libc-dev-mips64-cross \
    make \
    pkg-config \
    wget

# We use a different library directory to avoid collisions with existing openvpn install 
ENV OPENVPN_LIB_DIR=/usr/lib/openvpn_static
ENV OPENVPN_PLUGIN_DIR=${OPENVPN_LIB_DIR}/plugins

ENV BUILD_DIR=/build 
ENV PREFIX_DIR=${BUILD_DIR}
ENV TARGET_ARCH="mips64-linux-gnuabi64"
ENV ORIG_TARGET_ARCH=${TARGET_ARCH}

RUN mkdir -p ${PREFIX_DIR} && \
	mkdir -p ${BUILD_DIR}/include/security && \
	mkdir -p ${BUILD_DIR}/bin && cd ${BUILD_DIR}/bin && \
	ln -s /usr/bin/mips64-linux-gnuabi64-ar ar && \
	ln -s /usr/bin/mips64-linux-gnuabi64-gcc gcc
	
# LZ0 library
WORKDIR ${BUILD_DIR}
RUN wget -qO - https://www.oberhumer.com/opensource/lzo/download/lzo-${LZO_VERSION}.tar.gz | tar zxf - && \
	cd lzo-${LZO_VERSION} && \
	./configure --prefix=${PREFIX_DIR} \
    	        --enable-static \
        	    --target=${TARGET_ARCH} \
            	--host=${TARGET_ARCH} && \
	make && make install

# LZ4 library
ENV TARGET_ARCH=""
WORKDIR ${BUILD_DIR}
RUN	wget -qO - https://github.com/lz4/lz4/archive/v${LZ4_VERSION}.tar.gz | tar zxf - && \
	cd lz4-${LZ4_VERSION} && \	
	CC=${BUILD_DIR}/bin/gcc AR=${BUILD_DIR}/bin/ar make && PREFIX=${PREFIX_DIR} make install

# OpenSSL library
ENV TARGET_ARCH=${ORIG_TARGET_ARCH}
WORKDIR ${BUILD_DIR}
RUN wget -qO - https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz | tar zxf - && \
	cd openssl-${OPENSSL_VERSION} && \
	./Configure gcc -static -no-shared --prefix=${PREFIX_DIR} --cross-compile-prefix=${TARGET_ARCH}- && \
	make && make install

# pkcs11-helper library
WORKDIR ${BUILD_DIR}
RUN wget -qO - https://github.com/OpenSC/pkcs11-helper/archive/refs/tags/pkcs11-helper-${PKCS11_HELPER_VERSION}.tar.gz | tar zxf - && \
	cd pkcs11-helper-pkcs11-helper-${PKCS11_HELPER_VERSION} && \
	autoreconf -vif && \
	./configure --target=${TARGET_ARCH} \
    	        --host=${TARGET_ARCH} \
        	    --prefix=${PREFIX_DIR} \
            	--disable-crypto-engine-gnutls \
            	--disable-crypto-engine-nss \
            	--disable-crypto-engine-polarssl \
            	--disable-crypto-engine-mbedtls \
            	--disable-crypto-engine-cryptoapi \
            	OPENSSL_CFLAGS="-I${PREFIX_DIR}/include" \
            	OPENSSL_LIBS="-L${PREFIX_DIR}/lib -lssl -lcrypto" \
            	--enable-static && \
	make && make install
	
# Linux PAM library
WORKDIR ${BUILD_DIR}
RUN wget -qO - https://github.com/linux-pam/linux-pam/archive/refs/tags/v${PAM_VERSION}.tar.gz  | tar zxf - && \
	cd linux-pam-${PAM_VERSION} && \
	./autogen.sh && \
	./configure --target=${TARGET_ARCH} \
    	        --host=${TARGET_ARCH} \
        	    --prefix=${PREFIX_DIR} \
            	--disable-doc \
            	--enable-static && \
	make && make install && \
	mkdir -p ${BUILD_DIR}/include/security && \
	ln -s ${BUILD_DIR}/include/pam_appl.h ${BUILD_DIR}/include/security/pam_appl.h && \
	ln -s ${BUILD_DIR}/include/_pam_types.h ${BUILD_DIR}/include/security/_pam_types.h && \
	ln -s ${BUILD_DIR}/include/_pam_compat.h ${BUILD_DIR}/include/security/_pam_compat.h

# OpenVPN application
WORKDIR ${BUILD_DIR}
RUN	wget -qO - https://swupdate.openvpn.org/community/releases/openvpn-${OPENVPN_VERSION}.tar.gz | tar zxf - && \
	cd openvpn-${OPENVPN_VERSION} && \
	./configure --target=${TARGET_ARCH} \
            --host=${TARGET_ARCH} \
            --prefix=${PREFIX_DIR} \
            --enable-static \
            --enable-x509-alt-username \
            --enable-pkcs11 \
            LIBPAM_CFLAGS="-I${PREFIX_DIR}/include" \
            LIBPAM_LIBS="-L${PREFIX_DIR}/lib -lpam" \
            OPENSSL_CFLAGS="-I${PREFIX_DIR}/include" \
            OPENSSL_LIBS="-L${PREFIX_DIR}/lib -lssl -lcrypto" \
            LZO_CFLAGS="-I${PREFIX_DIR}/include" LZO_LIBS="-L${PREFIX_DIR}/lib -llzo2" \
            LZ4_CFLAGS="-I${PREFIX_DIR}/include" LZ4_LIBS="-L${PREFIX_DIR}/lib -llz4" \
            PKCS11_HELPER_CFLAGS="-I${PREFIX_DIR}/include" \
            PKCS11_HELPER_LIBS="-L${PREFIX_DIR}/lib -lpkcs11-helper" \
            IFCONFIG=/sbin/ifconfig \
            ROUTE=/sbin/route \
            NETSTAT=/bin/netstat \
            IPROUTE=/sbin/ip \
            --enable-iproute2 \
            PLUGINDIR=${OPENVPN_PLUGIN_DIR} && \
	make LIBS="-all-static" && make install && \
	mv ${OPENVPN_LIB_DIR} ${BUILD_DIR}/lib	
	
ENTRYPOINT /bin/bash
