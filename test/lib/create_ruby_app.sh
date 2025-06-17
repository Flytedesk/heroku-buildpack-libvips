#!/bin/bash
# Function to create test Ruby app

create_test_ruby_app() {
	local test_dir="$1"

	log "Creating test Ruby application..."

	# Create Gemfile without Ruby version constraint
	cat >"$test_dir/Gemfile" <<'EOF'
source "https://rubygems.org"

gem "ruby-vips", "~> 2.2"
gem "image_processing", "~> 1.12"
EOF

	# Create test script
	cat >"$test_dir/test_vips.rb" <<'EOF'
#!/usr/bin/env ruby

require 'bundler/setup'
require 'vips'
require 'image_processing/vips'

puts "🎉 Testing Ruby integration with libvips"
puts "========================================"
puts

# Test 1: Basic Vips functionality
puts "📋 libvips Information:"
puts "   Version: #{Vips.version_string}"
puts "   Features: #{Vips.get_suffixes.join(', ')}"
puts

# Test 2: HEIF support check
puts "🔍 HEIF Support Check:"
heif_supported = Vips.type_find("VipsOperation", "heifload") != 0
puts "   HEIF Load: #{heif_supported ? '✅ Available' : '❌ Not available'}"
heif_save_supported = Vips.type_find("VipsOperation", "heifsave") != 0
puts "   HEIF Save: #{heif_save_supported ? '✅ Available' : '❌ Not available'}"
puts

# Test 3: Load and analyze HEIC images
puts "📸 Analyzing HEIC Images:"

["sample1.heic", "sample2.heic"].each_with_index do |filename, index|
  if File.exist?(filename)
    puts "\n   #{index + 1}. Analyzing #{filename}:"
    
    begin
      # Load the image
      img = Vips::Image.new_from_file(filename)
      
      # Display image information
      puts "      - File size: #{File.size(filename)} bytes"
      puts "      - Dimensions: #{img.width} x #{img.height} pixels"
      puts "      - Bands: #{img.bands}"
      puts "      - Format: #{img.format}"
      puts "      - Interpretation: #{img.interpretation}"
      puts "      - Coding: #{img.coding}"
      puts "      - Xres: #{img.xres}, Yres: #{img.yres}"
      
      # Get some statistics
      # stats = img.stats
      # puts "      - Statistics:"
      # puts "        • Min values: R=#{stats[0, 0]}, G=#{stats[1, 0]}, B=#{stats[2, 0]}"
      # puts "        • Max values: R=#{stats[0, 1]}, G=#{stats[1, 1]}, B=#{stats[2, 1]}"
      # puts "        • Mean values: R=#{stats[0, 2].round(2)}, G=#{stats[1, 2].round(2)}, B=#{stats[2, 2].round(2)}"
      
      # Check available metadata fields
      fields = img.get_fields
      puts "      - Available metadata fields: #{fields.count}"
      if fields.include?("exif-data")
        puts "        • EXIF data: Present"
      end
      if fields.include?("heif-primary")
        puts "        • HEIF primary image: Present"
      end
      
      # Show some interesting fields if available
      interesting_fields = ["orientation", "xmp-data", "icc-profile-data"]
      interesting_fields.each do |field|
        if fields.include?(field)
          puts "        • #{field}: Present"
        end
      end
      
      # Convert to PNG for verification
      png_output = filename.gsub('.heic', '_converted.png')
      img.write_to_file(png_output)
      puts "      - Converted to: #{png_output} (#{File.size(png_output)} bytes)"
      
      # Calculate compression ratio
      compression_ratio = (File.size(png_output).to_f / File.size(filename)).round(2)
      puts "      - PNG/HEIC size ratio: #{compression_ratio}x"
      
    rescue => e
      puts "      ❌ Error loading #{filename}: #{e.message}"
      puts "         #{e.backtrace.first}"
    end
    
  else
    puts "   ⚠️  #{filename} not found in current directory"
    puts "      Current directory: #{Dir.pwd}"
    puts "      Files present: #{Dir['*'].join(', ')}"
  end
end

puts

# Test 4: Test image processing on HEIC files
if File.exist?("sample1.heic") && heif_supported
  puts "🔧 Image Processing on HEIC:"
  
  begin
    # Resize and convert format
    processed = ImageProcessing::Vips
      .source("sample1.heic")
      .resize_to_fit(200, 200)
      .saver(quality: 85)
      .convert("webp")
      .call
      
    puts "   ✅ Resized sample1.heic to 200x200 WebP"
    puts "      Output: #{File.basename(processed.path)} (#{File.size(processed.path)} bytes)"
    
    # Apply some effects if sample2 exists
    if File.exist?("sample2.heic")
      processed2 = ImageProcessing::Vips
        .source("sample2.heic")
        .resize_to_fill(150, 150)
        .rotate(45)
        .convert("jpeg")
        .call
        
      puts "   ✅ Resized and rotated sample2.heic to 150x150 JPEG"
      puts "      Output: #{File.basename(processed2.path)} (#{File.size(processed2.path)} bytes)"
    end
    
    # Test extracting thumbnails
    puts "\n   📐 Thumbnail extraction:"
    thumb = ImageProcessing::Vips
      .source("sample1.heic")
      .resize_to_limit(100, 100)
      .convert("png")
      .call
      
    puts "   ✅ Created thumbnail: #{File.basename(thumb.path)} (#{File.size(thumb.path)} bytes)"
    
  rescue => e
    puts "   ❌ Image processing error: #{e.message}"
    puts "      #{e.backtrace.first}"
  end
end

puts
puts "✅ All tests completed!"

# Create a simple test image for fallback testing
puts "\n🧪 Creating test image for basic operations:"
begin
  test_img = Vips::Image.black(200, 200, bands: 3)
  test_img = test_img.add([100, 150, 200])
  test_img.write_to_file("test_output.png")
  puts "   ✅ Created test_output.png"
rescue => e
  puts "   ❌ Failed to create test image: #{e.message}"
end
EOF

	success "Test Ruby application created"
}
