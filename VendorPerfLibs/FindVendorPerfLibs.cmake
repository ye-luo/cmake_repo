# FindVendorPerfLibs.cmake
#
# Searches for Intel MKL and creates the following CMake interface targets:
# - VPL::BLAS
# - VPL::LAPACK
# - VPL::fft
#
# Input variables:
# - VPL_THREADING: Specifies the threading layer to use. Acceptable values are:
#     - unset    : Sequential (mkl_sequential) - default
#     - "gomp"   : GNU OpenMP runtime (mkl_gnu_thread)
#     - "iomp5"  : Intel OpenMP runtime (mkl_intel_thread)
#

include(FindPackageHandleStandardArgs)

function(find_VPL_MKL)
  # Try to find the constituent libraries
  find_library(VendorPerfLibs_CORE_LIB NAMES mkl_core
    HINTS
      "${MKL_ROOT}/lib/intel64"
      "$ENV{MKLROOT}/lib/intel64"
      "$ENV{MKL_ROOT}/lib/intel64"
    PATHS
      /opt/intel/oneapi/mkl/latest/lib/intel64
      /opt/intel/mkl/lib/intel64
      /usr/lib/x86_64-linux-gnu
  )

  # Try to find MKL include directory
  find_path(VendorPerfLibs_INCLUDE_DIR NAMES mkl.h
    HINTS
      "${MKL_ROOT}/include"
      "$ENV{MKLROOT}/include"
      "$ENV{MKL_ROOT}/include"
    PATHS
      /opt/intel/oneapi/mkl/latest/include
      /opt/intel/mkl/include
      /usr/include/mkl
      /usr/include
  )

  set(VendorPerfLibs_INTERFACE_NAME mkl_gf_lp64)
  if(CMAKE_Fortran_COMPILER_LOADED)
    if(CMAKE_Fortran_COMPILER_ID MATCHES "^(Intel|IntelLLVM)$" OR CMAKE_Fortran_COMPILER_ID STREQUAL "NVHPC")
      set(VendorPerfLibs_INTERFACE_NAME mkl_intel_lp64)
    endif()
  endif()

  find_library(VendorPerfLibs_INTERFACE_LIB NAMES ${VendorPerfLibs_INTERFACE_NAME}
    HINTS
      "${MKL_ROOT}/lib/intel64"
      "$ENV{MKLROOT}/lib/intel64"
      "$ENV{MKL_ROOT}/lib/intel64"
    PATHS
      /opt/intel/oneapi/mkl/latest/lib/intel64
      /opt/intel/mkl/lib/intel64
      /usr/lib/x86_64-linux-gnu
  )

  if(NOT VPL_THREADING)
    set(VendorPerfLibs_THREAD_NAMES mkl_sequential)
  elseif(VPL_THREADING STREQUAL "iomp5")
    set(VendorPerfLibs_THREAD_NAMES mkl_intel_thread)
  else()
    set(VendorPerfLibs_THREAD_NAMES mkl_gnu_thread)
  endif()

  find_library(VendorPerfLibs_THREAD_LIB NAMES ${VendorPerfLibs_THREAD_NAMES}
    HINTS
      "${MKL_ROOT}/lib/intel64"
      "$ENV{MKLROOT}/lib/intel64"
      "$ENV{MKL_ROOT}/lib/intel64"
    PATHS
      /opt/intel/oneapi/mkl/latest/lib/intel64
      /opt/intel/mkl/lib/intel64
      /usr/lib/x86_64-linux-gnu
  )

  if(VendorPerfLibs_CORE_LIB AND VendorPerfLibs_INTERFACE_LIB AND VendorPerfLibs_THREAD_LIB)
    set(VendorPerfLibs_LIBRARIES ${VendorPerfLibs_INTERFACE_LIB} ${VendorPerfLibs_THREAD_LIB} ${VendorPerfLibs_CORE_LIB} pthread m dl PARENT_SCOPE)
    set(VendorPerfLibs_FOUND_LIBRARIES TRUE PARENT_SCOPE)
  else()
    set(VendorPerfLibs_FOUND_LIBRARIES FALSE PARENT_SCOPE)
  endif()
endfunction()

find_VPL_MKL()

find_package_handle_standard_args(VendorPerfLibs
  REQUIRED_VARS VendorPerfLibs_INCLUDE_DIR VendorPerfLibs_FOUND_LIBRARIES
)

if(VendorPerfLibs_FOUND)
  # Create VPL::BLAS
  if(NOT TARGET VPL::BLAS)
    add_library(VPL::BLAS INTERFACE IMPORTED)
    set_target_properties(VPL::BLAS PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${VendorPerfLibs_INCLUDE_DIR}"
      INTERFACE_LINK_LIBRARIES "${VendorPerfLibs_LIBRARIES}"
    )
  endif()

  # Create VPL::LAPACK
  if(NOT TARGET VPL::LAPACK)
    add_library(VPL::LAPACK INTERFACE IMPORTED)
    set_target_properties(VPL::LAPACK PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${VendorPerfLibs_INCLUDE_DIR}"
      INTERFACE_LINK_LIBRARIES "${VendorPerfLibs_LIBRARIES}"
    )
  endif()

  # Create VPL::fft
  if(NOT TARGET VPL::fft)
    add_library(VPL::fft INTERFACE IMPORTED)
    set_target_properties(VPL::fft PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${VendorPerfLibs_INCLUDE_DIR}"
      INTERFACE_LINK_LIBRARIES "${VendorPerfLibs_LIBRARIES}"
    )
  endif()
endif()
