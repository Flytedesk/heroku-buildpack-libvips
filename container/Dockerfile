FROM heroku/heroku:24

ENV DEBIAN_FRONTEND=noninteractive

# Fix apt permissions and directories, then install build dependencies
# The heroku base image may have permission issues with /var/lib/apt
USER root
RUN rm -rf /var/lib/apt/lists/* && \
  mkdir -p /var/lib/apt/lists/partial && \
  chmod -R 755 /var/lib/apt && \
  apt-get clean && \
  apt-get update && \
  apt-get install -y \
  build-essential \
  pkg-config \
  cmake \
  meson \
  ninja-build \
  patchelf \
  python3-pip \
  git \
  curl \
  wget \
  intltool \
  libtool \
  gtk-doc-tools

# Install additional development libraries available on Heroku platform
RUN apt-get install -y \
  glib-2.0-dev \
  libexpat1-dev \
  libpango1.0-dev \
  librsvg2-dev \
  libjpeg-turbo8-dev \
  libopenjp2-7-dev \
  libopenexr-dev \
  libtiff-dev \
  libexif-dev \
  liblcms2-dev \
  libxml2-dev \
  libfftw3-dev \
  libwebp-dev \
  libgif-dev \
  liborc-0.4-dev

# Install codec libraries for HEIF/AVIF support
RUN apt-get install -y \
  libde265-dev \
  libx265-dev \
  libaom-dev \
  libdav1d-dev \
  librav1e-dev \
  libsvtav1enc-dev \
  libspng-dev \
  libcgif-dev \
  libimagequant-dev \
  libgsf-1-dev

# Set build prefix - this will match our buildpack installation path
ARG VIPS_PREFIX=/app/vendor/libvips
ENV CMAKE_PREFIX_PATH=${VIPS_PREFIX}
ENV PKG_CONFIG_PATH=${VIPS_PREFIX}/lib/pkgconfig:${VIPS_PREFIX}/lib/x86_64-linux-gnu/pkgconfig:${VIPS_PREFIX}/lib/aarch64-linux-gnu/pkgconfig

# Create build directory
WORKDIR /usr/local/src

# Set library versions to match buildpack defaults
ARG LIBHEIF_VERSION=1.19.8
ARG LIBVIPS_VERSION=8.17.0

# Function to detect architecture and set lib directory
RUN ARCH=$(dpkg --print-architecture) && \
  case "$ARCH" in \
  amd64) LIB_ARCH_DIR="x86_64-linux-gnu" ;; \
  arm64) LIB_ARCH_DIR="aarch64-linux-gnu" ;; \
  *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
  esac && \
  echo "export LIB_ARCH_DIR=$LIB_ARCH_DIR" >> /etc/environment && \
  echo "LIB_ARCH_DIR=$LIB_ARCH_DIR" && \
  mkdir -p ${VIPS_PREFIX}/{bin,lib,include,share} && \
  mkdir -p ${VIPS_PREFIX}/lib/$LIB_ARCH_DIR

# Set environment for subsequent RUN commands
RUN ARCH=$(dpkg --print-architecture) && \
  case "$ARCH" in \
  amd64) echo "LIB_ARCH_DIR=x86_64-linux-gnu" >> /etc/environment ;; \
  arm64) echo "LIB_ARCH_DIR=aarch64-linux-gnu" >> /etc/environment ;; \
  esac

# Build libheif with full codec support
RUN . /etc/environment && \
  wget https://github.com/strukturag/libheif/releases/download/v${LIBHEIF_VERSION}/libheif-${LIBHEIF_VERSION}.tar.gz && \
  tar xzf libheif-${LIBHEIF_VERSION}.tar.gz && \
  cd libheif-${LIBHEIF_VERSION} && \
  mkdir build && cd build && \
  cmake .. \
  -DCMAKE_INSTALL_PREFIX=${VIPS_PREFIX} \
  -DCMAKE_INSTALL_LIBDIR=lib/${LIB_ARCH_DIR} \
  -DCMAKE_BUILD_TYPE=Release \
  -DWITH_EXAMPLES=OFF \
  -DWITH_LIBDE265=ON \
  -DWITH_X265=ON \
  -DWITH_AOM=ON \
  -DWITH_DAV1D=ON \
  -DWITH_RAV1E=ON \
  -DWITH_SvtEnc=ON \
  -DBUILD_SHARED_LIBS=ON && \
  make -j$(nproc) && \
  make install

# Update PKG_CONFIG_PATH to include libheif
RUN . /etc/environment && \
  echo "export PKG_CONFIG_PATH=${VIPS_PREFIX}/lib/${LIB_ARCH_DIR}/pkgconfig:${PKG_CONFIG_PATH}" >> /etc/environment

# Build libvips with HEIF support - ensure PKG_CONFIG_PATH includes libheif
RUN . /etc/environment && \
  export PKG_CONFIG_PATH="${VIPS_PREFIX}/lib/${LIB_ARCH_DIR}/pkgconfig:${PKG_CONFIG_PATH}" && \
  wget https://github.com/libvips/libvips/releases/download/v${LIBVIPS_VERSION}/vips-${LIBVIPS_VERSION}.tar.xz && \
  tar xf vips-${LIBVIPS_VERSION}.tar.xz && \
  cd vips-${LIBVIPS_VERSION} && \
  meson setup builddir \
  --prefix=${VIPS_PREFIX} \
  --libdir=lib/${LIB_ARCH_DIR} \
  --buildtype=release \
  -Dintrospection=disabled \
  -Dmodules=disabled \
  -Dcgif=enabled \
  -Dheif=enabled \
  -Djpeg=enabled \
  -Dpng=enabled \
  -Dtiff=enabled \
  -Dwebp=enabled \
  -Dexif=enabled \
  -Dlcms=enabled \
  -Dfftw=enabled && \
  meson compile -C builddir && \
  meson install -C builddir

# Set RUNPATH for all libraries and binaries to work in Heroku environment
RUN . /etc/environment && \
  cd ${VIPS_PREFIX} && \
  # Set RUNPATH for libheif and libvips libraries \
  for lib in lib/${LIB_ARCH_DIR}/lib{heif,vips}*.so*; do \
  if [ -f "$lib" ] && [ ! -L "$lib" ]; then \
  patchelf --set-rpath "\$ORIGIN:/app/vendor/libvips/lib:/app/vendor/libvips/lib/${LIB_ARCH_DIR}" "$lib" || true; \
  fi; \
  done && \
  # Set RUNPATH for vips binaries \
  for bin in bin/vips*; do \
  if [ -f "$bin" ] && [ ! -L "$bin" ]; then \
  patchelf --set-rpath "/app/vendor/libvips/lib:/app/vendor/libvips/lib/${LIB_ARCH_DIR}" "$bin" || true; \
  fi; \
  done

# Clean up unnecessary files to reduce package size
RUN cd ${VIPS_PREFIX} && \
  # Remove development files but keep essential headers \
  rm -rf share/doc share/man && \
  # Remove static libraries \
  find lib -name "*.a" -delete && \
  find lib -name "*.la" -delete && \
  # Strip binaries and libraries \
  strip bin/vips* 2>/dev/null || true && \
  find lib -name "*.so*" -exec strip {} \; 2>/dev/null || true

# Create version information
RUN cd ${VIPS_PREFIX} && \
  echo "libvips: ${LIBVIPS_VERSION}" > VERSION && \
  echo "libheif: ${LIBHEIF_VERSION}" >> VERSION && \
  echo "architecture: $(dpkg --print-architecture)" >> VERSION && \
  echo "build_date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> VERSION && \
  echo "build_method: docker_container" >> VERSION && \
  echo "stack: heroku-24" >> VERSION

# Verify the build - use proper environment
RUN . /etc/environment && \
  cd ${VIPS_PREFIX} && \
  export LD_LIBRARY_PATH="lib:lib/${LIB_ARCH_DIR}" && \
  export PKG_CONFIG_PATH="lib/pkgconfig:lib/${LIB_ARCH_DIR}/pkgconfig" && \
  echo "=== Build Verification ===" && \
  echo "libvips version:" && \
  ./bin/vips --version && \
  echo && \
  echo "HEIF support check:" && \
  pkg-config --exists libheif && echo "✓ libheif found via pkg-config" || echo "✗ libheif not found via pkg-config" && \
  echo "Available operations:" && \
  ./bin/vips list | grep -E "(heif|load|save)" | head -10 && \
  echo && \
  echo "Testing HEIF operations directly:" && \
  (./bin/vips heifload 2>&1 | head -3 || echo "heifload not available") && \
  (./bin/vips heifsave 2>&1 | head -3 || echo "heifsave not available") && \
  echo && \
  echo "Library dependencies for libvips.so:" && \
  ldd lib/${LIB_ARCH_DIR}/libvips.so.42 | head -10 && \
  echo && \
  echo "RUNPATH for libvips.so:" && \
  readelf -d lib/${LIB_ARCH_DIR}/libvips.so.42 | grep -E "(RUNPATH|RPATH)" || echo "No RUNPATH found"

# Create the distribution tarball for each architecture
RUN ARCH=$(dpkg --print-architecture) && \
  cd ${VIPS_PREFIX} && \
  mkdir -p /dist && \
  tar czf "/dist/heroku-24-${ARCH}.tar.gz" . && \
  echo "Created /dist/heroku-24-${ARCH}.tar.gz"

# Create config log for debugging
RUN ARCH=$(dpkg --print-architecture) && \
  . /etc/environment && \
  cd ${VIPS_PREFIX} && \
  export LD_LIBRARY_PATH="lib:lib/${LIB_ARCH_DIR}" && \
  { \
  echo "=== libvips Configuration Log ==="; \
  echo "Stack: heroku-24"; \
  echo "Architecture: ${ARCH}"; \
  echo "Build date: $(date -u)"; \
  echo ""; \
  echo "$ vips --version"; \
  ./bin/vips --version || echo "Version check failed"; \
  echo ""; \
  echo "$ vips list | head -20"; \
  ./bin/vips list | head -20 || echo "List command failed"; \
  echo ""; \
  echo "$ pkg-config --libs libheif"; \
  pkg-config --libs libheif || echo "libheif pkg-config failed"; \
  echo ""; \
  echo "=== Library Analysis ==="; \
  echo "Library files:"; \
  find lib -name "*.so*" | sort; \
  echo ""; \
  echo "Binary files:"; \
  find bin -type f | sort; \
  } > "/dist/heroku-24-${ARCH}.config.log"
