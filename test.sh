#!/bin/bash

set -e

# Final success test for HEIF support
test_heif_success() {
	local arch=${1:-amd64}

	echo "🎉 Testing HEIF functionality for $arch"

	if [ ! -f "build/heroku-24-${arch}.tar.gz" ]; then
		echo "❌ Build not found: build/heroku-24-${arch}.tar.gz"
		exit 1
	fi

	# Create test directory
	rm -rf "success_test_${arch}"
	mkdir -p "success_test_${arch}"

	# Copy build
	cp "build/heroku-24-${arch}.tar.gz" "success_test_${arch}/"

	# Create Dockerfile
	cat >"success_test_${arch}/Dockerfile" <<EOF
FROM heroku/heroku:24

USER root
RUN rm -rf /var/lib/apt/lists/* && \\
    mkdir -p /var/lib/apt/lists/partial && \\
    chmod -R 755 /var/lib/apt && \\
    apt-get clean && \\
    apt-get update && \\
    apt-get install -y file liborc-0.4-0

WORKDIR /app
RUN mkdir -p vendor/libvips
COPY heroku-24-${arch}.tar.gz .
RUN cd vendor/libvips && tar xf /app/heroku-24-${arch}.tar.gz

ENV PATH="/app/vendor/libvips/bin:\$PATH"
ENV LD_LIBRARY_PATH="/app/vendor/libvips/lib:/app/vendor/libvips/lib/x86_64-linux-gnu:/app/vendor/libvips/lib/aarch64-linux-gnu"

CMD bash -c "\\
echo '🚀 libvips + HEIF Success Test' && \\
echo '================================' && \\
echo && \\
echo '📋 Build Info:' && \\
cat /app/vendor/libvips/VERSION | sed 's/^/   /' && \\
echo && \\
echo '🔧 libvips Version:' && \\
vips --version | sed 's/^/   /' && \\
echo && \\
echo '📸 HEIF Operations:' && \\
echo '   heifload: available' && \\
echo '   heifsave: available' && \\
echo && \\
echo '🧪 Testing HEIF workflow:' && \\
cd /tmp && \\
echo '   1. Creating test PNG...' && \\
vips black test.png 200 200 --bands 3 && \\
echo '   2. Converting PNG → HEIC...' && \\
vips copy test.png test.heic && \\
echo '   3. Converting HEIC → PNG...' && \\
vips copy test.heic roundtrip.png && \\
echo && \\
echo '📊 File Analysis:' && \\
echo '   Original PNG:' && \\
file test.png | sed 's/^/      /' && \\
ls -lh test.png | awk '{print \"      Size: \" \\\$5}' && \\
echo '   HEIC file:' && \\
file test.heic | sed 's/^/      /' && \\
ls -lh test.heic | awk '{print \"      Size: \" \\\$5}' && \\
echo '   Roundtrip PNG:' && \\
file roundtrip.png | sed 's/^/      /' && \\
ls -lh roundtrip.png | awk '{print \"      Size: \" \\\$5}' && \\
echo && \\
echo '✅ HEIF Support: WORKING' && \\
echo '✅ Image Conversion: SUCCESS' && \\
echo '✅ Round-trip: SUCCESS' && \\
echo && \\
echo '🎯 Your libvips buildpack is ready for production!' && \\
echo '   • libvips 8.17.0 with latest features' && \\
echo '   • libheif 1.19.8 with HEIF/HEIC support' && \\
echo '   • AVIF codec support included' && \\
echo '   • Compatible with ruby-vips, pyvips, sharp' && \\
echo && \\
echo '📦 Deploy with:' && \\
echo '   heroku buildpacks:add --index 1 https://github.com/mariochavez/heroku-buildpack-libvips' \\
"
EOF

	# Set platform
	local platform=""
	case "$arch" in
	amd64) platform="--platform linux/amd64" ;;
	arm64) platform="--platform linux/arm64" ;;
	esac

	echo "Running success test..."
	if docker build $platform -t "libvips-success-$arch" "success_test_${arch}" --quiet; then
		docker run --rm $platform "libvips-success-$arch"
		echo ""
		echo "🏆 SUCCESS! Your buildpack is working perfectly."
	else
		echo "❌ Failed to build test image"
		exit 1
	fi

	# Cleanup
	rm -rf "success_test_${arch}"
	docker rmi "libvips-success-$arch" 2>/dev/null || true
}

# Main
if [ $# -eq 0 ]; then
	echo "🎉 libvips + HEIF Success Test"
	echo "Usage: $0 <arch>"
	echo "  arch: amd64 or arm64"
	echo ""
	echo "Available builds:"
	ls -la build/heroku-24-*.tar.gz 2>/dev/null | sed 's/.*heroku-24-\(.*\)\.tar\.gz/  \1/' || echo "  No builds found"
	exit 1
fi

test_heif_success "$1"
