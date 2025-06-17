#!/bin/bash

set -e

# Default versions
LIBVIPS_VERSION=${LIBVIPS_VERSION:-8.17.0}
LIBHEIF_VERSION=${LIBHEIF_VERSION:-1.19.8}

# Supported stacks and architectures
STACK_VERSIONS=(24)
ARCHITECTURES=(amd64 arm64)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
	echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
	echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
	echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
	echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to build for a specific stack and architecture
build_stack_arch() {
	local stack_version=$1
	local arch=$2

	log "Building libvips ${LIBVIPS_VERSION} for heroku-${stack_version} (${arch})"

	# Create build directory
	mkdir -p build

	# Set platform for multi-arch builds
	local platform=""
	case "$arch" in
	amd64) platform="linux/amd64" ;;
	arm64) platform="linux/arm64" ;;
	*)
		error "Unsupported architecture: $arch"
		return 1
		;;
	esac

	# Build the main container
	local image_name="libvips/heroku-${stack_version}-${arch}:${LIBVIPS_VERSION}"

	log "Building Docker image: $image_name"
	docker buildx build \
		--platform "$platform" \
		--file container/Dockerfile \
		--build-arg LIBVIPS_VERSION="$LIBVIPS_VERSION" \
		--build-arg LIBHEIF_VERSION="$LIBHEIF_VERSION" \
		--tag "$image_name" \
		--load \
		. || {
		error "Failed to build image for heroku-${stack_version} (${arch})"
		return 1
	}

	# Extract the built artifacts
	log "Extracting build artifacts"
	local container_id=$(docker create "$image_name")
	docker cp "$container_id:/dist/." build/ || {
		error "Failed to extract artifacts"
		docker rm "$container_id" 2>/dev/null || true
		return 1
	}
	docker rm "$container_id"

	success "Build completed for heroku-${stack_version} (${arch})"

	return 0
}

# Function to validate prerequisites
check_prerequisites() {
	log "Checking prerequisites..."

	# Check if Docker is available
	if ! command -v docker >/dev/null 2>&1; then
		error "Docker is required but not installed"
		exit 1
	fi

	# Check if Docker buildx is available
	if ! docker buildx version >/dev/null 2>&1; then
		error "Docker buildx is required but not available"
		exit 1
	fi

	# Create buildx builder if it doesn't exist
	if ! docker buildx inspect multiarch >/dev/null 2>&1; then
		log "Creating multi-architecture builder"
		docker buildx create --name multiarch --use --platform linux/amd64,linux/arm64 || {
			error "Failed to create multi-architecture builder"
			exit 1
		}
	else
		docker buildx use multiarch
	fi

	success "Prerequisites check passed"
}

# Function to clean up old builds
cleanup() {
	log "Cleaning up old build artifacts..."
	rm -rf build/*

	# Clean up old Docker images
	docker image prune -f --filter "label=libvips-build=true" 2>/dev/null || true

	success "Cleanup completed"
}

# Function to show build summary
show_summary() {
	log "Build Summary"
	echo "=============================================="
	echo "libvips version: ${LIBVIPS_VERSION}"
	echo "libheif version: ${LIBHEIF_VERSION}"
	echo "Build date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
	echo ""
	echo "Generated artifacts:"
	if [ -d "build" ]; then
		find build -name "*.tar.gz" -exec basename {} \; | sort
		echo ""
		find build -name "*.config.log" -exec basename {} \; | sort
	else
		echo "No artifacts found"
	fi
	echo "=============================================="
}

# Main execution
main() {
	local stacks_to_build=()
	local archs_to_build=()
	local run_tests=true
	local clean_first=false

	# Parse command line arguments
	while [[ $# -gt 0 ]]; do
		case $1 in
		--stack)
			stacks_to_build+=("$2")
			shift 2
			;;
		--arch)
			archs_to_build+=("$2")
			shift 2
			;;
		--no-tests)
			run_tests=false
			shift
			;;
		--clean)
			clean_first=true
			shift
			;;
		--help)
			echo "Usage: $0 [options]"
			echo "Options:"
			echo "  --stack STACK    Build only specific stack (24)"
			echo "  --arch ARCH      Build only specific architecture (amd64, arm64)"
			echo "  --no-tests       Skip test builds"
			echo "  --clean          Clean before building"
			echo "  --help           Show this help"
			echo ""
			echo "Environment variables:"
			echo "  LIBVIPS_VERSION  libvips version to build (default: ${LIBVIPS_VERSION})"
			echo "  LIBHEIF_VERSION  libheif version to build (default: ${LIBHEIF_VERSION})"
			exit 0
			;;
		*)
			error "Unknown option: $1"
			exit 1
			;;
		esac
	done

	# Use defaults if no specific stacks/archs specified
	if [ ${#stacks_to_build[@]} -eq 0 ]; then
		stacks_to_build=("${STACK_VERSIONS[@]}")
	fi

	if [ ${#archs_to_build[@]} -eq 0 ]; then
		archs_to_build=("${ARCHITECTURES[@]}")
	fi

	log "Starting libvips buildpack build process"
	log "libvips version: ${LIBVIPS_VERSION}"
	log "libheif version: ${LIBHEIF_VERSION}"
	log "Target stacks: ${stacks_to_build[*]}"
	log "Target architectures: ${archs_to_build[*]}"

	# Clean up if requested
	if [ "$clean_first" = true ]; then
		cleanup
	fi

	# Check prerequisites
	check_prerequisites

	# Build for each combination
	local total_builds=$((${#stacks_to_build[@]} * ${#archs_to_build[@]}))
	local current_build=0
	local failed_builds=()

	for stack in "${stacks_to_build[@]}"; do
		for arch in "${archs_to_build[@]}"; do
			current_build=$((current_build + 1))
			log "Build ${current_build}/${total_builds}: heroku-${stack} (${arch})"

			if build_stack_arch "$stack" "$arch"; then
				success "Completed build ${current_build}/${total_builds}"
			else
				error "Failed build ${current_build}/${total_builds}"
				failed_builds+=("heroku-${stack}-${arch}")
			fi
			echo ""
		done
	done

	# Show summary
	show_summary

	# Report failures
	if [ ${#failed_builds[@]} -gt 0 ]; then
		error "The following builds failed:"
		printf '%s\n' "${failed_builds[@]}"
		exit 1
	else
		success "All builds completed successfully!"
	fi
}

# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
