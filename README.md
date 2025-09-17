# heroku-buildpack-libvips

A modern Heroku buildpack for [libvips](https://github.com/libvips/libvips) with comprehensive HEIF/HEIC and AVIF support.

[![libvips](https://img.shields.io/github/v/tag/Flytedesk/heroku-buildpack-libvips?label=libvips&logo=image)](https://github.com/Flytedesk/heroku-buildpack-libvips/releases)
[![Heroku 20](https://img.shields.io/badge/stack-20-904edf?logo=heroku)](https://devcenter.heroku.com/articles/heroku-20-stack)
[![Heroku 22](https://img.shields.io/badge/stack-22-904edf?logo=heroku)](https://devcenter.heroku.com/articles/heroku-22-stack)
[![Heroku 24](https://img.shields.io/badge/stack-24-904edf?logo=heroku)](https://devcenter.heroku.com/articles/heroku-24-stack)
[![Build](https://github.com/Flytedesk/heroku-buildpack-libvips/actions/workflows/build.yml/badge.svg)](https://github.com/Flytedesk/heroku-buildpack-libvips/actions/workflows/build.yml)
[![Multi-arch](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-blue)](https://github.com/Flytedesk/heroku-buildpack-libvips/releases)

## Features

- 🚀 **Latest libvips** (8.17.0) with cutting-edge image processing capabilities
- 📸 **Full HEIF/HEIC support** via libheif 1.19.8 with AOM and DAV1D codecs
- 🎯 **AVIF support** for next-generation image formats
- 🏗️ **Multi-architecture** support for both x86_64 and ARM64
- ⚡ **Smart deployment** - pre-built binaries with source compilation fallback
- 🔧 **Language agnostic** - works with Ruby, Python, Node.js, and more
- 🌐 **Modern stacks** - supports Heroku-20, Heroku-22, and Heroku-24

## Quick Start

Add this buildpack to your Heroku app:

```bash
heroku buildpacks:add --index 1 https://github.com/Flytedesk/heroku-buildpack-libvips
```

Deploy your app and verify the installation:

```bash
heroku run vips --version
# vips-8.17.0

heroku run vips list | grep heif
# heifload: load HEIF images
# heifsave: save HEIF images
```

## Language Support

### Ruby (ruby-vips)

```ruby
require 'vips'

# Process HEIF images
image = Vips::Image.new_from_file('photo.heic')
thumbnail = image.thumbnail_image(300)
thumbnail.write_to_file('thumbnail.jpg')

puts "libvips: #{Vips::LIBRARY_VERSION}"
puts "HEIF support: #{Vips.get_suffixes.include?('.heic')}"
```

### Python (pyvips)

```python
import pyvips

# Process HEIF images
image = pyvips.Image.new_from_file('photo.heic')
thumbnail = image.thumbnail_image(300)
thumbnail.write_to_file('thumbnail.jpg')

print(f"libvips: {pyvips.version_string()}")
```

### Node.js (sharp)

```javascript
const sharp = require('sharp');

// Process HEIF images
await sharp('photo.heic')
  .resize(300)
  .jpeg()
  .toFile('thumbnail.jpg');

console.log(`libvips: ${sharp.versions.vips}`);
console.log(`HEIF support: ${sharp.format.heif.input}`);
```

## Configuration

### Version Selection

Control which version of libvips to install:

```bash
heroku config:set VIPS_VERSION=8.17.0
```

### Force Source Compilation

By default, the buildpack tries to use pre-built binaries for faster deployments. To force compilation from source:

```bash
heroku config:set COMPILE_FROM_SOURCE=true
```

### HEIF Version Control

Specify the libheif version (when compiling from source):

```bash
heroku config:set LIBHEIF_VERSION=1.19.8
```

### Security Settings

Block untrusted operations at runtime:

```bash
heroku config:set VIPS_BLOCK_UNTRUSTED=true
```

## Advanced Usage

### Multi-Buildpack Setup

For applications requiring system dependencies, use the apt buildpack first:

```bash
# Add apt buildpack for system dependencies
heroku buildpacks:add --index 1 heroku-community/apt

# Add libvips buildpack
heroku buildpacks:add --index 2 https://github.com/Flytedesk/heroku-buildpack-libvips

# Add your language buildpack
heroku buildpacks:add --index 3 heroku/ruby
```

Create an `Aptfile` for additional system dependencies:

```
# Aptfile
build-essential
pkg-config
# Add other dependencies as needed
```

### Performance Optimization

For production applications, consider these optimizations:

```bash
# Enable libvips cache
heroku config:set VIPS_CACHE_MAX=100

# Set operation cache size
heroku config:set VIPS_CACHE_MAX_OPS=500

# Tune memory usage
heroku config:set VIPS_CACHE_MAX_MEM=50m
```

## Supported Image Formats

| Format | Read | Write | Notes |
|--------|------|-------|-------|
| JPEG | ✅ | ✅ | Including JPEG-XL |
| PNG | ✅ | ✅ | Full transparency support |
| TIFF | ✅ | ✅ | Multi-page support |
| WebP | ✅ | ✅ | Animation support |
| HEIF/HEIC | ✅ | ✅ | **Apple Photos format** |
| AVIF | ✅ | ✅ | **Next-gen format** |
| GIF | ✅ | ✅ | Animation support |
| SVG | ✅ | ❌ | Via librsvg |
| PDF | ✅ | ❌ | Via poppler |

## Architecture Support

This buildpack supports both Heroku's x86_64 and ARM64 infrastructure:

- **x86_64** - Standard Heroku dynos
- **ARM64** - Heroku's newer ARM-based dynos (when available)

The buildpack automatically detects the architecture and uses the appropriate binaries.

## Development

### Building Locally

Clone the repository and build for specific stacks:

```bash
git clone https://github.com/Flytedesk/heroku-buildpack-libvips
cd heroku-buildpack-libvips

# Build for all supported stacks
./build.sh

# Build for specific stack and architecture
./build.sh --stack 24 --arch amd64

# Build with custom versions
LIBVIPS_VERSION=8.17.0 LIBHEIF_VERSION=1.19.8 ./build.sh
```

### Testing

The build process includes comprehensive tests:

```bash
# Run full test suite
./build.sh --stack 24

# Skip tests for faster builds
./build.sh --no-tests
```

Tests verify:

- Library loading and basic operations
- HEIF/AVIF format support
- Ruby, Python, and Node.js integration
- Multi-architecture compatibility

### Docker Development

Use the provided Docker containers for development:

```bash
# Build development container
docker build -f container/Dockerfile --build-arg STACK_VERSION=24 -t libvips-dev .

# Run interactive session
docker run -it libvips-dev bash
```

## Troubleshooting

### Common Issues

**"No HEIF support detected"**

- Ensure you're using a recent version (8.15+)
- Check that libheif was compiled correctly
- Verify HEIF codecs are available

**"Library not found errors"**

- Make sure the buildpack is first in your buildpack order
- Check that `LD_LIBRARY_PATH` includes libvips directories
- For multi-buildpack setups, ensure proper ordering

**"Build failures during compilation"**

- Add required system dependencies to your `Aptfile`
- Use pre-built binaries instead: `heroku config:unset COMPILE_FROM_SOURCE`
- Check the build logs for specific missing dependencies

### Getting Help

1. **Check the [releases page](https://github.com/Flytedesk/heroku-buildpack-libvips/releases)** for pre-built binaries
2. **Review build logs** for specific error messages
3. **Open an issue** with your stack version, architecture, and error details
4. **Check [libvips documentation](https://www.libvips.org/)** for format-specific questions

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Update documentation
6. Submit a pull request

### Release Process

Releases are automated via GitHub Actions:

1. Tag a new version: `git tag v8.17.0`
2. Push the tag: `git push origin v8.17.0`
3. GitHub Actions builds all variants and creates a release
4. Pre-built binaries are attached to the release

## License

This buildpack is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Acknowledgments

- [libvips team](https://github.com/libvips/libvips) for the excellent image processing library
- [strukturag](https://github.com/strukturag/libheif) for libheif HEIF/HEIC support
- [Heroku](https://heroku.com) for the platform and buildpack specification
- Original [heroku-buildpack-vips](https://github.com/hardpixel/heroku-buildpack-vips) for inspiration
