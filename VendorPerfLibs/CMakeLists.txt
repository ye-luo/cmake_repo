cmake_minimum_required(VERSION 3.15)
project(VendorPerfLibsTest LANGUAGES Fortran C)

# Append current directory to CMAKE_MODULE_PATH so find_package can find FindVendorPerfLibs.cmake
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}")

option(USE_OMP "Use OpenMP threading" OFF)
if(USE_OMP)
  find_package(OpenMP REQUIRED COMPONENTS Fortran C)
endif()

# Find our custom VendorPerfLibs
if(USE_OMP)
  set(VPL_OMP ON)
endif()
find_package(VendorPerfLibs REQUIRED fft)

# Enable CTest
enable_testing()

# Create the test executable
add_executable(test_blas_zdotc tests/test_blas_zdotc.f90)

# Link it against the BLAS target provided by VendorPerfLibs
target_link_libraries(test_blas_zdotc PRIVATE VPL::blas)

# Add the test
add_test(NAME test_blas_zdotc COMMAND test_blas_zdotc)
