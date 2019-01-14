#! /usr/bin/env bash

MINIMUM_ANDROID_SDK_VERSION=$1
MINIMUM_ANDROID_64_BIT_SDK_VERSION=$2
OPENSSL_FULL_VERSION="openssl-1.1.1a"

if [ ! -f "$OPENSSL_FULL_VERSION.tar.gz" ]; then
    curl -O https://www.openssl.org/source/$OPENSSL_FULL_VERSION.tar.gz
fi
tar -xvzf $OPENSSL_FULL_VERSION.tar.gz

(cd $OPENSSL_FULL_VERSION;

 if [ ! ${MINIMUM_ANDROID_SDK_VERSION} ]; then
     echo "MINIMUM_ANDROID_SDK_VERSION was not provided, include and rerun"
     exit 1
 fi

 if [ ! ${MINIMUM_ANDROID_64_BIT_SDK_VERSION} ]; then
     echo "MINIMUM_ANDROID_64_BIT_SDK_VERSION was not provided, include and rerun"
     exit 1
 fi

 if [ ! ${ANDROID_NDK_ROOT} ]; then
     echo "ANDROID_NDK_ROOT environment variable not set, set and rerun"
     exit 1
 fi

 ANDROID_LIB_ROOT="../../$OPENSSL_FULL_VERSION"
 ANDROID_TOOLCHAIN_DIR=/tmp/android-toolchain
 #OPENSSL_CONFIGURE_OPTIONS="no-pic no-krb5 no-idea no-camellia \
 #       no-seed no-bf no-cast no-rc2 no-rc4 no-rc5 no-md2 \
 #       no-md4 no-ripemd no-rsa no-ecdh no-sock no-ssl2 no-ssl3 \
 #       no-dsa no-dh no-ec no-ecdsa no-tls1 no-pbe no-pkcs \
 #       no-tlsext no-pem no-rfc3779 no-whirlpool no-ui no-srp \
 #       no-ssltrace no-tlsext no-mdc2 no-ecdh no-engine \
 #       no-tls2 no-srtp -fPIC"

OPENSSL_CONFIGURE_OPTIONS=""

 HOST_INFO=`uname -a`
 case ${HOST_INFO} in
     Darwin*)
         TOOLCHAIN_SYSTEM=darwin-x86
         ;;
     Linux*)
         if [[ "${HOST_INFO}" == *i686* ]]
         then
             TOOLCHAIN_SYSTEM=linux-x86
         else
             TOOLCHAIN_SYSTEM=linux-x86_64
         fi
         ;;
     *)
         echo "Toolchain unknown for host system"
         exit 1
         ;;
 esac

 rm -rf ${ANDROID_LIB_ROOT}

 # copy header
 mkdir -p "${ANDROID_LIB_ROOT}/include/openssl"
 cp -r "include/openssl" "${ANDROID_LIB_ROOT}/include/"

 ./Configure dist
#armeabi armeabi-v7a x86 x86_64 arm64-v8a
 for ANDROID_TARGET_PLATFORM in armeabi-v7a x86 x86_64 arm64-v8a
 do
     echo "Building for libcrypto.so and libssl.so for ${ANDROID_TARGET_PLATFORM}"
     case "${ANDROID_TARGET_PLATFORM}" in
         armeabi-v7a)
             TOOLCHAIN_ARCH=arm
             TOOLCHAIN_PREFIX=arm-linux-androideabi
             CONFIGURE_ARCH=android-arm
             PLATFORM_OUTPUT_DIR=armeabi-v7a
             ANDROID_API_VERSION=${MINIMUM_ANDROID_SDK_VERSION}
             ;;
         x86)
             TOOLCHAIN_ARCH=x86
             TOOLCHAIN_PREFIX=i686-linux-android
             CONFIGURE_ARCH=android-x86
             PLATFORM_OUTPUT_DIR=x86
             ANDROID_API_VERSION=${MINIMUM_ANDROID_SDK_VERSION}
             ;;
         x86_64)
             TOOLCHAIN_ARCH=x86_64
             TOOLCHAIN_PREFIX=x86_64-linux-android
             CONFIGURE_ARCH=android-x86_64
             PLATFORM_OUTPUT_DIR=x86_64
             ANDROID_API_VERSION=${MINIMUM_ANDROID_64_BIT_SDK_VERSION}
             ;;
         arm64-v8a)
             TOOLCHAIN_ARCH=arm64
             TOOLCHAIN_PREFIX=aarch64-linux-android
             CONFIGURE_ARCH=android-arm64
             PLATFORM_OUTPUT_DIR=arm64-v8a
             ANDROID_API_VERSION=${MINIMUM_ANDROID_64_BIT_SDK_VERSION}
             ;;
         *)
             echo "Unsupported build platform:${ANDROID_TARGET_PLATFORM}"
             exit 1
     esac

     #rm -rf ${ANDROID_TOOLCHAIN_DIR}
     mkdir -p "${ANDROID_LIB_ROOT}/${ANDROID_TARGET_PLATFORM}/shared"
     #python ${ANDROID_NDK_ROOT}/build/tools/make_standalone_toolchain.py \
     #       --arch ${TOOLCHAIN_ARCH} \
     #       --api ${ANDROID_API_VERSION} \
     #       --install-dir ${ANDROID_TOOLCHAIN_DIR}

     #if [ $? -ne 0 ]; then
     #    echo "Error executing make_standalone_toolchain.py for ${TOOLCHAIN_ARCH}"
     #    exit 1
     #fi

     #export PATH=${ANDROID_TOOLCHAIN_DIR}/bin:${TOOLCHAIN_PREFIX}-clang:${TOOLCHAIN_PREFIX}-gcc:$PATH
     #export CROSS_SYSROOT=${ANDROID_TOOLCHAIN_DIR}/sysroot
     export PATH=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin:${PATH}
     echo $TOOLCHAIN_PREFIX
     echo $PATH
     echo ${ANDROID_API_VERSION}
     
     ./Configure "${CONFIGURE_ARCH}" -D__ANDROID_API__=${ANDROID_API_VERSION}

#     RANLIB=${TOOLCHAIN_PREFIX}-ranlib \
#           AR=${TOOLCHAIN_PREFIX}-ar \
#           CC=${TOOLCHAIN_PREFIX}-clang \
#           ./Configure "${CONFIGURE_ARCH}" \
#           -D__ANDROID_API__=${ANDROID_API_VERSION} 
#\
           #"${OPENSSL_CONFIGURE_OPTIONS}"

     if [ $? -ne 0 ]; then
         echo "Error executing:./Configure ${CONFIGURE_ARCH} ${OPENSSL_CONFIGURE_OPTIONS}"
         exit 1
     fi

     make clean
     make

     if [ $? -ne 0 ]; then
         echo "Error executing make for platform:${ANDROID_TARGET_PLATFORM}"
         exit 1
     fi

     mv libcrypto.a ${ANDROID_LIB_ROOT}/${PLATFORM_OUTPUT_DIR}
     mv libssl.a ${ANDROID_LIB_ROOT}/${PLATFORM_OUTPUT_DIR}

     mv libcrypto.so.1.1 ${ANDROID_LIB_ROOT}/${PLATFORM_OUTPUT_DIR}/shared/libcrypto.so
     mv libssl.so.1.1 ${ANDROID_LIB_ROOT}/${PLATFORM_OUTPUT_DIR}/shared/libssl.so
 done 
)
