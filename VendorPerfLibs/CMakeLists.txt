cmake_minimum_required(VERSION 3.15)
project(VendorPerfLibsTest LANGUAGES Fortran C)

# Append current directory to CMAKE_MODULE_PATH so find_package can find FindVendorPerfLibs.cmake
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}")

option(USE_OMP "Use OpenMP threading" OFF)
find_package(OpenMP REQUIRED COMPONENTS Fortran C)

option(VPL_OMP "Use OpenMP threading for Vendor Performance Libraries" ${USE_OMP})

# Enable CTest
enable_testing()

# Test BLAS

# Find our custom VendorPerfLibs
find_package(VendorPerfLibs REQUIRED lapack)

# Create the test executable
add_executable(test_blas_zdotc tests/test_blas_zdotc.f90)

# Link it against the BLAS target provided by VendorPerfLibs
target_link_libraries(test_blas_zdotc PRIVATE VPL::lapack)

# Add the test
add_test(NAME test_blas_zdotc COMMAND test_blas_zdotc)

find_package(VendorPerfLibs REQUIRED fft lapack)# Test FFT

# Find our custom VendorPerfLibs
find_package(VendorPerfLibs REQUIRED fft)

# Create the test executable
add_executable(test_fftw3 tests/test_fftw3.c)

# Link it against the BLAS target provided by VendorPerfLibs
target_link_libraries(test_fftw3 PRIVATE VPL::fft)

# Add the test
add_test(NAME test_fftw3 COMMAND test_fftw3)


