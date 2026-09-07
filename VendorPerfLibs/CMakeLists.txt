cmake_minimum_required(VERSION 3.10)
project(VendorPerfLibsTest LANGUAGES Fortran)

# Append current directory to CMAKE_MODULE_PATH so find_package can find FindVendorPerfLibs.cmake
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}")

# Find our custom VendorPerfLibs
#set(VPL_THREADING gomp)
find_package(VendorPerfLibs REQUIRED)

# Enable CTest
enable_testing()

# Create the test executable
add_executable(test_blas_zdotc tests/test_blas_zdotc.f90)

# Link it against the BLAS target provided by VendorPerfLibs
target_link_libraries(test_blas_zdotc PRIVATE VPL::blas)

# Add the test
add_test(NAME test_blas_zdotc COMMAND test_blas_zdotc)

#find_package(VendorPerfLibs REQUIRED COMPONENTS fft)
