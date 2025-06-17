#!/bin/bash
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDPACK_PATH="$SCRIPT_DIR"
STACK="heroku-24"
IMAGE="heroku/heroku:24-build"

# Default architecture
ARCH=${1:-amd64}

# Source helper scripts
source "$SCRIPT_DIR/test/lib/colors.sh"
source "$SCRIPT_DIR/test/lib/create_ruby_app.sh"

# Function to run the full stack test
run_full_stack_test() {
	local arch="$1"
	local test_name="buildpack-full-test-ruby-$arch"

	log "Running full stack test for $arch architecture"

	# Create temporary test directory
	local test_dir=$(mktemp -d)
	trap "rm -rf $test_dir" EXIT

	# Create test Ruby app
	create_test_ruby_app "$test_dir"

	# Copy sample HEIC files if they exist
	if [ -f "$SCRIPT_DIR/sample1.heic" ]; then
		cp "$SCRIPT_DIR/sample1.heic" "$test_dir/"
		log "Copied sample1.heic"
	else
		warn "sample1.heic not found in $SCRIPT_DIR"
	fi

	if [ -f "$SCRIPT_DIR/sample2.heic" ]; then
		cp "$SCRIPT_DIR/sample2.heic" "$test_dir/"
		log "Copied sample2.heic"
	else
		warn "sample2.heic not found in $SCRIPT_DIR"
	fi

	# Copy the Docker test script
	cp "$SCRIPT_DIR/test/lib/docker_test.sh" "$test_dir/docker_test.sh"
	chmod +x "$test_dir/docker_test.sh"

	# Set platform for Docker
	local platform=""
	case "$arch" in
	amd64) platform="--platform linux/amd64" ;;
	arm64) platform="--platform linux/arm64" ;;
	*)
		error "Unsupported architecture: $arch"
		return 1
		;;
	esac

	log "Starting Docker container for full stack test..."

	# Copy buildpack to temporary location
	cp -r "$BUILDPACK_PATH" "$test_dir/buildpack-libvips"

	docker run -i --rm \
		$platform \
		--name "$test_name" \
		--user root \
		-v "$test_dir:/tmp/test" \
		-e "STACK=$STACK" \
		"$IMAGE" \
		/bin/bash /tmp/test/docker_test.sh

	if [ $? -eq 0 ]; then
		success "Full stack test completed successfully for $arch"
	else
		error "Full stack test failed for $arch"
		return 1
	fi
}

# Main execution
main() {
	local arch="amd64"

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case $1 in
		--arch)
			arch="$2"
			shift 2
			;;
		--help)
			echo "Usage: $0 [--arch ARCH]"
			echo "Options:"
			echo "  --arch ARCH    Architecture to test (amd64, arm64) [default: amd64]"
			echo "  --help         Show this help"
			exit 0
			;;
		*)
			error "Unknown option: $1"
			exit 1
			;;
		esac
	done

	# Validate architecture
	if [[ "$arch" != "amd64" && "$arch" != "arm64" ]]; then
		error "Unsupported architecture: $arch"
		exit 1
	fi

	# Check prerequisites
	if ! command -v docker >/dev/null 2>&1; then
		error "Docker is required but not installed"
		exit 1
	fi

	log "Starting full stack Ruby test"
	log "Architecture: $arch"
	log "Stack: $STACK"
	log "Buildpack path: $BUILDPACK_PATH"

	run_full_stack_test "$arch"

	success "All tests completed successfully!"
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
