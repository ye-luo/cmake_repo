# FindVendorPerfLibs.cmake
#
# Searches for Intel MKL and creates the following CMake interface targets:
# - VPL::blas
# - VPL::lapack
# - VPL::fft
#
# Input variables:
# - VPL_Name: Specifies the vendor performance library to search for. Acceptable values are:
#     - unset      : Search any vendor libraries
#     - "IntelMKL" : Intel Math Kernel Library
#     - "NVPL"     : NVIDIA Performance Libraries
# - VPL_THREADING: Specifies the threading layer to use. Acceptable values are:
#     - unset    : Sequential (mkl_sequential) - default
#     - "gomp"   : GNU OpenMP runtime (mkl_gnu_thread)
#     - "iomp5"  : Intel OpenMP runtime (mkl_intel_thread)
#

include(FindPackageHandleStandardArgs)

function(find_VPL_MKL)
  # Try to find the constituent libraries
  find_library(MKL_CORE_LIB NAMES mkl_core
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

  # Try to find FFTW3 include directory
  find_path(VendorPerfLibs_FFTW3_INCLUDE_DIR NAMES fftw3.f03
    HINTS
      "${MKL_ROOT}/include"
      "$ENV{MKLROOT}/include"
      "$ENV{MKL_ROOT}/include"
    PATHS
      /opt/intel/oneapi/mkl/latest/include
      /opt/intel/mkl/include
      /usr/include/mkl
      /usr/include
    PATH_SUFFIXES fftw
  )

  if(MKL_CORE_LIB)
    get_filename_component(VendorPerfLibs_LIB_DIR "${MKL_CORE_LIB}" DIRECTORY)

    set(VendorPerfLibs_INTERFACE_NAME mkl_gf_lp64)
    if(CMAKE_Fortran_COMPILER_LOADED)
      if(CMAKE_Fortran_COMPILER_ID MATCHES "^(Intel|IntelLLVM)$" OR CMAKE_Fortran_COMPILER_ID STREQUAL "NVHPC")
        set(VendorPerfLibs_INTERFACE_NAME mkl_intel_lp64)
      endif()
    endif()

    find_library(MKL_INTERFACE_LIB NAMES ${VendorPerfLibs_INTERFACE_NAME}
      PATHS "${VendorPerfLibs_LIB_DIR}"
      NO_DEFAULT_PATH
    )

    if(NOT VPL_THREADING)
      set(VendorPerfLibs_THREAD_NAMES mkl_sequential)
    elseif(VPL_THREADING STREQUAL "iomp5")
      set(VendorPerfLibs_THREAD_NAMES mkl_intel_thread)
    else()
      set(VendorPerfLibs_THREAD_NAMES mkl_gnu_thread)
    endif()

    find_library(MKL_THREAD_LIB NAMES ${VendorPerfLibs_THREAD_NAMES}
      PATHS "${VendorPerfLibs_LIB_DIR}"
      NO_DEFAULT_PATH
    )
  endif()

  if(MKL_CORE_LIB AND MKL_INTERFACE_LIB AND MKL_THREAD_LIB)
    set(VendorPerfLibs_LIBRARIES ${MKL_INTERFACE_LIB} ${MKL_THREAD_LIB} ${MKL_CORE_LIB} pthread m dl PARENT_SCOPE)
    set(VendorPerfLibs_FOUND_LIBRARIES TRUE PARENT_SCOPE)
  else()
    set(VendorPerfLibs_FOUND_LIBRARIES FALSE PARENT_SCOPE)
  endif()
endfunction()

if(NOT VPL_Name OR VPL_Name STREQUAL "IntelMKL")
  find_VPL_MKL()
endif()

find_package_handle_standard_args(VendorPerfLibs
  REQUIRED_VARS VendorPerfLibs_INCLUDE_DIR VendorPerfLibs_FFTW3_INCLUDE_DIR VendorPerfLibs_FOUND_LIBRARIES
)

if(VendorPerfLibs_FOUND)
  # Create VPL::blas
  if(NOT TARGET VPL::blas)
    add_library(VPL::blas INTERFACE IMPORTED)
    set_target_properties(VPL::blas PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${VendorPerfLibs_INCLUDE_DIR}"
      INTERFACE_LINK_LIBRARIES "${VendorPerfLibs_LIBRARIES}"
    )
  endif()

  # Create VPL::lapack
  if(NOT TARGET VPL::lapack)
    add_library(VPL::lapack INTERFACE IMPORTED)
    set_target_properties(VPL::lapack PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${VendorPerfLibs_INCLUDE_DIR}"
      INTERFACE_LINK_LIBRARIES "${VendorPerfLibs_LIBRARIES}"
    )
  endif()

  # Create VPL::fft
  if(NOT TARGET VPL::fft)
    add_library(VPL::fft INTERFACE IMPORTED)
    set_target_properties(VPL::fft PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${VendorPerfLibs_INCLUDE_DIR};${VendorPerfLibs_FFTW3_INCLUDE_DIR}"
      INTERFACE_LINK_LIBRARIES "${VendorPerfLibs_LIBRARIES}"
    )
  endif()
endif()
