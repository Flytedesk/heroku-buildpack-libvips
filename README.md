# Heroku Buildpack: libvips with libheif

This buildpack installs the latest versions of libvips and libheif on Heroku-24 stack, enabling advanced image processing capabilities including HEIF/HEIC format support.

## Features

- Installs libvips with full HEIF/HEIC support
- Includes libheif with AVIF support (via libaom and libdav1d)
- Optimized build with caching for faster subsequent deployments
- Configurable versions via environment variables

## Usage

### Add the buildpack to your app

```bash
heroku buildpacks:add https://github.com/mariochavez/heroku-buildpack-libvips --index 1
```

**Important:** This buildpack should be added before your language-specific buildpack (e.g., before heroku/python or heroku/ruby).

### Configure versions (optional)

You can specify custom versions using environment variables:

```bash
heroku config:set LIBVIPS_VERSION=8.15.5
heroku config:set LIBHEIF_VERSION=1.18.2
```

## Supported Image Formats

After installation, libvips will support:

- JPEG, PNG, WebP, GIF
- HEIF/HEIC (via libheif)
- AVIF (via libheif with AOM)
- SVG (via librsvg)
- PDF (via poppler)
- TIFF, EXR, and many more

## Verification

To verify the installation in your app:

```bash
heroku run vips --version
heroku run vips list classes | grep -i heif
```

## Using with Ruby

If you're using Ruby with the `ruby-vips` gem:

```ruby
# Gemfile
gem 'ruby-vips', '~> 2.2'
```

```ruby
require 'vips'

# Check HEIF support
puts Vips::get_suffixes
# Should include .heif and .heic

# Convert HEIC to JPEG
image = Vips::Image.new_from_file("photo.heic")
image.write_to_file("photo.jpg")
```

## Using with Python

If you're using Python with `pyvips`:

```python
# requirements.txt
pyvips==2.2.3
```

```python
import pyvips

# Check version and features
print(f"libvips version: {pyvips.version(0)}.{pyvips.version(1)}.{pyvips.version(2)}")

# Convert HEIC to JPEG
image = pyvips.Image.new_from_file('photo.heic')
image.write_to_file('photo.jpg')
```

## Using with Node.js

If you're using Node.js with `sharp`:

```json
// package.json
{
  "dependencies": {
    "sharp": "^0.33.0"
  }
}
```

```javascript
const sharp = require('sharp');

// Check format support
console.log(sharp.format);

// Convert HEIC to JPEG
await sharp('photo.heic')
  .jpeg()
  .toFile('photo.jpg');
```

## Build Cache

The buildpack caches downloaded source files to speed up subsequent builds. The cache is stored in Heroku's build cache directory.

## Troubleshooting

### Out of Memory During Build

If you encounter memory issues during compilation, you may need to use a larger dyno size for builds:

```bash
heroku config:set BUILD_DYNO_SIZE=performance-l
```

### Missing Format Support

Run `vips list classes` to see all supported formats. If HEIF is not listed, check the build logs for any errors during libheif compilation.

### Library Path Issues

The buildpack automatically configures `LD_LIBRARY_PATH`. If you're having issues, ensure you're not overriding this variable in your app.

## Development

To modify this buildpack:

1. Fork the repository
2. Make your changes
3. Test locally using the Heroku CLI:

   ```bash
   heroku buildpacks:set https://github.com/mariochavez/heroku-buildpack-libvips#YOUR_BRANCH
   ```

## License

MIT License

## Contributing

Pull requests are welcome! Please ensure that:

- The build script remains compatible with Heroku-24 stack
- Version updates are tested
- Documentation is updated accordingly
