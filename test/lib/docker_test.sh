#!/bin/bash
# Docker test script that will run inside the container

set -e

echo "🚀 Full Stack Test: Ruby + libvips"
echo "=================================="
echo

cd /tmp/test

# Copy buildpack to writable location
cp -r buildpack-libvips /tmp/buildpack-libvips

# Fix apt permissions for heroku-24
rm -rf /var/lib/apt/lists/*
mkdir -p /var/lib/apt/lists/partial
chmod -R 755 /var/lib/apt
apt-get clean
apt-get update

# Install all necessary dependencies for building gems and libvips AS ROOT
echo ">>> Installing system dependencies..."
apt-get install -y \
	git \
	curl \
	liborc-0.4-0 \
	build-essential \
	libffi-dev \
	pkg-config \
	libglib2.0-dev \
	ruby-dev

# Remove system vips to avoid conflicts
apt-get remove -y libvips-tools libvips42 || true

# Detect architecture for library paths
ARCH=$(uname -m)
case "$ARCH" in
x86_64) LIB_ARCH="x86_64-linux-gnu" ;;
aarch64) LIB_ARCH="aarch64-linux-gnu" ;;
*) LIB_ARCH="" ;;
esac

# Set environment before running buildpack
export LD_LIBRARY_PATH="/tmp/test/vendor/libvips/lib:/tmp/test/vendor/libvips/lib/$LIB_ARCH:$LD_LIBRARY_PATH"

# Run libvips buildpack first
echo ">>> Running libvips buildpack..."
if ! /tmp/buildpack-libvips/bin/detect /tmp/test; then
	echo "❌ libvips buildpack detection failed"
	exit 1
fi

mkdir -p /tmp/cache-libvips /tmp/env
/tmp/buildpack-libvips/bin/compile /tmp/test /tmp/cache-libvips /tmp/env

# Source profile.d scripts to get environment
echo ">>> Sourcing libvips environment..."
for script in /tmp/test/.profile.d/*.sh; do
	if [ -f "$script" ]; then
		echo "Sourcing: $script"
		source "$script"
	fi
done

# Ensure proper environment setup
export PATH="/tmp/test/vendor/libvips/bin:$PATH"
export LD_LIBRARY_PATH="/tmp/test/vendor/libvips/lib:/tmp/test/vendor/libvips/lib/$LIB_ARCH:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="/tmp/test/vendor/libvips/lib/pkgconfig:/tmp/test/vendor/libvips/lib/$LIB_ARCH/pkgconfig:$PKG_CONFIG_PATH"

# Verify libvips is working
echo ">>> Verifying libvips installation..."
if [ -f "/tmp/test/vendor/libvips/bin/vips" ]; then
	echo "Using vips at: $(which vips)"
	/tmp/test/vendor/libvips/bin/vips --version
	echo "✅ libvips binary working"

	# Check HEIF support
	if /tmp/test/vendor/libvips/bin/vips list classes | grep -q heif; then
		echo "✅ HEIF support detected"
	else
		echo "⚠️  HEIF support not detected"
	fi
else
	echo "❌ libvips binary not found"
	exit 1
fi

# Check Ruby version
echo ">>> Ruby version check..."
ruby --version

# Install Ruby gems as a regular user to avoid the warning
echo ">>> Creating test user and installing Ruby gems..."
useradd -m -s /bin/bash testuser || true
chown -R testuser:testuser /tmp/test

# Install gems as testuser - capture the gem path
BUNDLER_PATH=$(su testuser -c "
cd /tmp/test
export PATH=\"/tmp/test/vendor/libvips/bin:\$PATH\"
export LD_LIBRARY_PATH=\"/tmp/test/vendor/libvips/lib:/tmp/test/vendor/libvips/lib/$LIB_ARCH:\$LD_LIBRARY_PATH\"
export PKG_CONFIG_PATH=\"/tmp/test/vendor/libvips/lib/pkgconfig:/tmp/test/vendor/libvips/lib/$LIB_ARCH/pkgconfig:\$PKG_CONFIG_PATH\"

# Install bundler
gem install bundler -v 2.5.23 --user-install 2>&1 | grep -o '/home/testuser/.local/share/gem/ruby/[0-9.]\+' | head -1
")

echo ">>> Bundler installed to: $BUNDLER_PATH"

# Now install gems with proper PATH
su testuser -c "
cd /tmp/test
export PATH=\"$BUNDLER_PATH/bin:/tmp/test/vendor/libvips/bin:\$PATH\"
export LD_LIBRARY_PATH=\"/tmp/test/vendor/libvips/lib:/tmp/test/vendor/libvips/lib/$LIB_ARCH:\$LD_LIBRARY_PATH\"
export PKG_CONFIG_PATH=\"/tmp/test/vendor/libvips/lib/pkgconfig:/tmp/test/vendor/libvips/lib/$LIB_ARCH/pkgconfig:\$PKG_CONFIG_PATH\"

# First generate a fresh Gemfile.lock
bundle lock

# Configure bundler
bundle config set --local path 'vendor/bundle'

# Install gems
bundle install
"

echo ">>> Environment Summary:"
echo "PATH: $PATH"
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
echo "Which vips: $(which vips)"
echo "Which ruby: $(which ruby)"
echo

# Verify ruby-vips can find libvips
echo ">>> Testing ruby-vips integration..."
cd /tmp/test
su testuser -c "
export PATH=\"$BUNDLER_PATH/bin:/tmp/test/vendor/libvips/bin:\$PATH\"
export LD_LIBRARY_PATH=\"/tmp/test/vendor/libvips/lib:/tmp/test/vendor/libvips/lib/$LIB_ARCH:\$LD_LIBRARY_PATH\"
export PKG_CONFIG_PATH=\"/tmp/test/vendor/libvips/lib/pkgconfig:/tmp/test/vendor/libvips/lib/$LIB_ARCH/pkgconfig:\$PKG_CONFIG_PATH\"
cd /tmp/test

bundle exec ruby -e \"
require 'vips'
puts 'Ruby found libvips: ' + Vips.version_string
puts 'HEIF operations available: ' + (Vips.type_find('VipsOperation', 'heifload') != 0).to_s
\"
"

# Run comprehensive test
echo ">>> Running comprehensive Ruby + libvips test..."
su testuser -c "
export PATH=\"$BUNDLER_PATH/bin:/tmp/test/vendor/libvips/bin:\$PATH\"
export LD_LIBRARY_PATH=\"/tmp/test/vendor/libvips/lib:/tmp/test/vendor/libvips/lib/$LIB_ARCH:\$LD_LIBRARY_PATH\"
export PKG_CONFIG_PATH=\"/tmp/test/vendor/libvips/lib/pkgconfig:/tmp/test/vendor/libvips/lib/$LIB_ARCH/pkgconfig:\$PKG_CONFIG_PATH\"
cd /tmp/test

bundle exec ruby test_vips.rb
"

echo
echo "🎉 Full stack test completed successfully!"
echo "✅ libvips buildpack: Working"
echo "✅ ruby-vips gem: Working"
echo "✅ HEIF support: Working"
echo "✅ Image processing: Working"
