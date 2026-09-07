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
#     - "ARMPL"    : ARM Performance Libraries
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

  if(NOT MKL_CORE_LIB)
    set(VendorPerfLibs_FOUND_LIBRARIES FALSE PARENT_SCOPE)
    return()
  endif()

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
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
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
  endif()

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

  if(MKL_CORE_LIB AND MKL_INTERFACE_LIB AND MKL_THREAD_LIB)
    set(VendorPerfLibs_LIBRARIES ${MKL_INTERFACE_LIB} ${MKL_THREAD_LIB} ${MKL_CORE_LIB} pthread m dl PARENT_SCOPE)
    set(VendorPerfLibs_FOUND_LIBRARIES TRUE PARENT_SCOPE)
  else()
    set(VendorPerfLibs_FOUND_LIBRARIES FALSE PARENT_SCOPE)
  endif()
endfunction()

function(find_VPL_NVPL)
  # Try to find NVPL include directory
  find_path(VendorPerfLibs_INCLUDE_DIR NAMES nvpl_blas.h
    HINTS
      "${NVPL_ROOT}/include"
      "$ENV{nvpl_ROOT}/include"
      "$ENV{NVPL_ROOT}/include"
    PATHS
      /opt/nvidia/nvpl/include
      /usr/include
  )

  # Determine thread suffix
  if(NOT VPL_THREADING)
    set(NVPL_THREAD_SUFFIX "seq")
  else()
    set(NVPL_THREAD_SUFFIX "gomp")
  endif()

  set(NVPL_INTERFACE_SUFFIX "lp64")

  # Try to find the constituent libraries
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "blas" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    find_library(NVPL_BLAS_LIB NAMES nvpl_blas_${NVPL_INTERFACE_SUFFIX}_${NVPL_THREAD_SUFFIX}
      HINTS
        "${NVPL_ROOT}/lib"
        "$ENV{nvpl_ROOT}/lib"
        "$ENV{NVPL_ROOT}/lib"
      PATHS
        /opt/nvidia/nvpl/lib
        /usr/lib/aarch64-linux-gnu
        /usr/lib
    )
  endif()


  # Try to find FFTW3 include directory
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    find_path(VendorPerfLibs_FFTW3_INCLUDE_DIR NAMES nvpl_fftw.h fftw3.f03
      HINTS
        "${NVPL_ROOT}/include"
        "$ENV{nvpl_ROOT}/include"
        "$ENV{NVPL_ROOT}/include"
      PATHS
        /opt/nvidia/nvpl/include
        /usr/include
      PATH_SUFFIXES fftw
    )
  endif()

  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "lapack" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    find_library(NVPL_LAPACK_LIB NAMES nvpl_lapack_${NVPL_INTERFACE_SUFFIX}_${NVPL_THREAD_SUFFIX}
      HINTS
        "${NVPL_ROOT}/lib"
        "$ENV{nvpl_ROOT}/lib"
        "$ENV{NVPL_ROOT}/lib"
      PATHS
        /opt/nvidia/nvpl/lib
        /usr/lib/aarch64-linux-gnu
        /usr/lib
    )
  endif()

  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    find_library(NVPL_FFTW_LIB NAMES nvpl_fftw
      HINTS
        "${NVPL_ROOT}/lib"
        "$ENV{nvpl_ROOT}/lib"
        "$ENV{NVPL_ROOT}/lib"
      PATHS
        /opt/nvidia/nvpl/lib
        /usr/lib/aarch64-linux-gnu
        /usr/lib
    )
  endif()

  set(_nvpl_found TRUE)
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "blas" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    if(NOT NVPL_BLAS_LIB)
      set(_nvpl_found FALSE)
    endif()
  endif()
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "lapack" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    if(NOT NVPL_LAPACK_LIB)
      set(_nvpl_found FALSE)
    endif()
  endif()
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    if(NOT NVPL_FFTW_LIB)
      set(_nvpl_found FALSE)
    endif()
  endif()

  if(_nvpl_found)
    set(_vpl_libs)
    if(NOT VendorPerfLibs_FIND_COMPONENTS OR "lapack" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
      list(APPEND _vpl_libs ${NVPL_LAPACK_LIB})
    endif()
    if(NOT VendorPerfLibs_FIND_COMPONENTS OR "blas" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
      list(APPEND _vpl_libs ${NVPL_BLAS_LIB})
    endif()
    if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
      list(APPEND _vpl_libs ${NVPL_FFTW_LIB})
    endif()
    list(APPEND _vpl_libs pthread m dl)
    set(VendorPerfLibs_LIBRARIES ${_vpl_libs} PARENT_SCOPE)
    set(VendorPerfLibs_FOUND_LIBRARIES TRUE PARENT_SCOPE)
  else()
    set(VendorPerfLibs_FOUND_LIBRARIES FALSE PARENT_SCOPE)
  endif()
endfunction()

function(find_VPL_ARMPL)
  # Determine thread suffix
  if(NOT VPL_THREADING)
    set(ARMPL_THREAD_SUFFIX "")
  else()
    set(ARMPL_THREAD_SUFFIX "_mp")
  endif()

  set(ARMPL_INTERFACE_SUFFIX "lp64")
  set(ARMPL_LIB_NAME armpl_${ARMPL_INTERFACE_SUFFIX}${ARMPL_THREAD_SUFFIX})

  # Try to find ARMPL include directory
  find_path(VendorPerfLibs_INCLUDE_DIR NAMES armpl.h
    HINTS
      "${ARMPL_ROOT}/include"
      "$ENV{armpl_ROOT}/include"
      "$ENV{ARMPL_ROOT}/include"
    PATHS
      /opt/arm/armpl/include
      /usr/include
  )

  # Try to find FFTW3 include directory
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    find_path(VendorPerfLibs_FFTW3_INCLUDE_DIR NAMES fftw3.f03
      HINTS
        "${ARMPL_ROOT}/include"
        "$ENV{armpl_ROOT}/include"
        "$ENV{ARMPL_ROOT}/include"
      PATHS
        /opt/arm/armpl/include
        /usr/include
      PATH_SUFFIXES fftw
    )
  endif()

  find_library(ARMPL_LIB NAMES ${ARMPL_LIB_NAME}
    HINTS
      "${ARMPL_ROOT}/lib"
      "$ENV{armpl_ROOT}/lib"
      "$ENV{ARMPL_ROOT}/lib"
    PATHS
      /opt/arm/armpl/lib
      /usr/lib/aarch64-linux-gnu
      /usr/lib
  )

  if(ARMPL_LIB)
    set(_vpl_libs ${ARMPL_LIB})
    list(APPEND _vpl_libs pthread m dl)
    set(VendorPerfLibs_LIBRARIES ${_vpl_libs} PARENT_SCOPE)
    set(VendorPerfLibs_FOUND_LIBRARIES TRUE PARENT_SCOPE)
  else()
    set(VendorPerfLibs_FOUND_LIBRARIES FALSE PARENT_SCOPE)
  endif()
endfunction()


if(NOT VendorPerfLibs_FOUND_LIBRARIES AND NOT VPL_Name OR VPL_Name STREQUAL "IntelMKL")
  find_VPL_MKL()
endif()
if(NOT VendorPerfLibs_FOUND_LIBRARIES AND NOT VPL_Name OR VPL_Name STREQUAL "NVPL")
  find_VPL_NVPL()
endif()
if(NOT VendorPerfLibs_FOUND_LIBRARIES AND NOT VPL_Name OR VPL_Name STREQUAL "ARMPL")
  find_VPL_ARMPL()
endif()

set(_vpl_required_vars VendorPerfLibs_INCLUDE_DIR VendorPerfLibs_FOUND_LIBRARIES)
if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
  list(APPEND _vpl_required_vars VendorPerfLibs_FFTW3_INCLUDE_DIR)
endif()

find_package_handle_standard_args(VendorPerfLibs
  REQUIRED_VARS ${_vpl_required_vars}
)

if(VendorPerfLibs_FOUND)
  # Create VPL::blas
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "blas" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    if(NOT TARGET VPL::blas)
      add_library(VPL::blas INTERFACE IMPORTED)
      set_target_properties(VPL::blas PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${VendorPerfLibs_INCLUDE_DIR}"
        INTERFACE_LINK_LIBRARIES "${VendorPerfLibs_LIBRARIES}"
      )
    endif()
  endif()

  # Create VPL::lapack
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "lapack" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    if(NOT TARGET VPL::lapack)
      add_library(VPL::lapack INTERFACE IMPORTED)
      set_target_properties(VPL::lapack PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${VendorPerfLibs_INCLUDE_DIR}"
        INTERFACE_LINK_LIBRARIES "${VendorPerfLibs_LIBRARIES}"
      )
    endif()
  endif()

  # Create VPL::fft
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    if(NOT TARGET VPL::fft)
      add_library(VPL::fft INTERFACE IMPORTED)
      set_target_properties(VPL::fft PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${VendorPerfLibs_INCLUDE_DIR};${VendorPerfLibs_FFTW3_INCLUDE_DIR}"
        INTERFACE_LINK_LIBRARIES "${VendorPerfLibs_LIBRARIES}"
      )
    endif()
  endif()
endif()
