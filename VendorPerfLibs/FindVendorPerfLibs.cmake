# Copyright (c) 2026, The VendorPerfLibs Authors
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# FindVendorPerfLibs.cmake
#
# Searches for Intel MKL and creates the following CMake interface targets:
# - VPL::blas
# - VPL::lapack
# - VPL::fft
#
# Input variables:
# - VPL_ID: Specifies the vendor performance library to search for. Acceptable values are:
#     - unset      : Search any vendor libraries
#     - "IntelMKL" : Intel Math Kernel Library
#     - "NVPL"     : NVIDIA Performance Libraries
#     - "ARMPL"    : ARM Performance Libraries
#     - "AOCL"     : AMD Optimizing CPU Libraries
# - VPL_THREADING: Specifies the threading layer to use. Acceptable values are:
#     - unset    : Sequential (mkl_sequential) - default
#     - "gomp"   : GCC's libgomp, or any OpenMP runtime providing a compatibility layer for it
#     - "iomp5"  : Intel's libiomp5, or any OpenMP runtime providing a compatibility layer for it
#

include(FindPackageHandleStandardArgs)

set(_VPL_VALID_IDS "" "IntelMKL" "NVPL" "ARMPL" "AOCL")
if(DEFINED VPL_ID AND NOT VPL_ID IN_LIST _VPL_VALID_IDS)
  message(FATAL_ERROR "VendorPerfLibs: Unknown VPL_ID '${VPL_ID}'. Acceptable values are: unset, 'IntelMKL', 'NVPL', 'ARMPL', 'AOCL'")
endif()

if(NOT VendorPerfLibs_FIND_QUIETLY)
  if(VPL_ID)
    message(STATUS "Searching for Vendor Performance Libraries. Requested VPL_ID '${VPL_ID}'")
  else()
    message(STATUS "Exploring Vendor Performance Libraries.")
  endif()
endif()

set(_VPL_VALID_THREADINGS "" "gomp" "iomp5")
if(DEFINED VPL_THREADING AND NOT VPL_THREADING IN_LIST _VPL_VALID_THREADINGS)
  message(FATAL_ERROR "VendorPerfLibs: Unknown VPL_THREADING '${VPL_THREADING}'. Acceptable values are: unset, 'gomp', 'iomp5'")
endif()

if(NOT VendorPerfLibs_FIND_QUIETLY)
  if(VPL_THREADING)
    message(STATUS "Requested threading layer: ${VPL_THREADING}")
  else()
    message(STATUS "Requested non-threaded Vendor Performance Libraries.")
  endif()
endif()

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
    PATH_SUFFIXES mkl
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
      PATH_SUFFIXES fftw mkl/fftw
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
    set(_vpl_libs ${MKL_INTERFACE_LIB} ${MKL_THREAD_LIB} ${MKL_CORE_LIB})
    if(VPL_THREADING)
      list(APPEND _vpl_libs ${VPL_THREADING})
    endif()
    list(APPEND _vpl_libs pthread m dl)
    set(VendorPerfLibs_LIBRARIES ${_vpl_libs} PARENT_SCOPE)
    set(VendorPerfLibs_FOUND_LIBRARIES TRUE PARENT_SCOPE)
    set(VPL_ID "IntelMKL" CACHE STRING "Vendor Performance Library ID (unset, IntelMKL, NVPL, ARMPL, AOCL)" FORCE)
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
    )
  endif()


  # Try to find FFTW3 include directory
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    find_path(VendorPerfLibs_FFTW3_INCLUDE_DIR NAMES fftw3.f03
      HINTS
        "${NVPL_ROOT}/include"
        "$ENV{nvpl_ROOT}/include"
        "$ENV{NVPL_ROOT}/include"
      PATHS
        /opt/nvidia/nvpl/include
      PATH_SUFFIXES nvpl_fftw
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
    if(VPL_THREADING)
      list(APPEND _vpl_libs ${VPL_THREADING})
    endif()
    list(APPEND _vpl_libs pthread m dl)
    set(VendorPerfLibs_LIBRARIES ${_vpl_libs} PARENT_SCOPE)
    set(VendorPerfLibs_FOUND_LIBRARIES TRUE PARENT_SCOPE)
    set(VPL_ID "NVPL" CACHE STRING "Vendor Performance Library ID (unset, IntelMKL, NVPL, ARMPL, AOCL)" FORCE)
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
      "$ENV{ARMPL_DIR}/include"
    PATHS
      /opt/arm/armpl/include
  )

  # Try to find FFTW3 include directory
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    find_path(VendorPerfLibs_FFTW3_INCLUDE_DIR NAMES fftw3.f03
      HINTS
        "${ARMPL_ROOT}/include"
        "$ENV{armpl_ROOT}/include"
        "$ENV{ARMPL_ROOT}/include"
        "$ENV{ARMPL_DIR}/include"
      PATHS
        /opt/arm/armpl/include
      PATH_SUFFIXES fftw
    )
  endif()

  find_library(ARMPL_LIB NAMES ${ARMPL_LIB_NAME}
    HINTS
      "${ARMPL_ROOT}/lib"
      "$ENV{armpl_ROOT}/lib"
      "$ENV{ARMPL_ROOT}/lib"
      "$ENV{ARMPL_DIR}/lib"
    PATHS
      /opt/arm/armpl/lib
  )

  if(ARMPL_LIB)
    set(_vpl_libs ${ARMPL_LIB})
    if(VPL_THREADING)
      list(APPEND _vpl_libs ${VPL_THREADING})
    endif()
    list(APPEND _vpl_libs pthread m dl)
    set(VendorPerfLibs_LIBRARIES ${_vpl_libs} PARENT_SCOPE)
    set(VendorPerfLibs_FOUND_LIBRARIES TRUE PARENT_SCOPE)
    set(VPL_ID "ARMPL" CACHE STRING "Vendor Performance Library ID (unset, IntelMKL, NVPL, ARMPL, AOCL)" FORCE)
  else()
    set(VendorPerfLibs_FOUND_LIBRARIES FALSE PARENT_SCOPE)
  endif()
endfunction()

function(find_VPL_AOCL)
  if(NOT VPL_THREADING)
    set(AOCL_BLAS_LIB_NAME "blis")
    set(AOCL_FFTW_LIB_NAME "fftw3")
  else()
    set(AOCL_BLAS_LIB_NAME "blis-mt")
    set(AOCL_FFTW_LIB_NAME "fftw3_omp")
  endif()
  set(AOCL_LAPACK_LIB_NAME "flame")

  find_path(VendorPerfLibs_INCLUDE_DIR NAMES aocl.h blis.h
    HINTS
      "${AOCL_ROOT}/include"
      "$ENV{AOCL_ROOT}/include"
    PATHS
      /opt/AMD/aocl/aocl-linux-gcc/include
  )

  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    find_path(VendorPerfLibs_FFTW3_INCLUDE_DIR NAMES fftw3.f03 fftw3.h
      HINTS
        "${AOCL_ROOT}/include"
        "$ENV{AOCL_ROOT}/include"
      PATHS
        /opt/AMD/aocl/aocl-linux-gcc/include
      PATH_SUFFIXES fftw fftw3
    )
  endif()

  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "blas" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    find_library(AOCL_BLAS_LIB NAMES ${AOCL_BLAS_LIB_NAME}
      HINTS
        "${AOCL_ROOT}/lib"
        "$ENV{AOCL_ROOT}/lib"
      PATHS
        /opt/AMD/aocl/aocl-linux-gcc/lib
    )
  endif()

  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "lapack" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    find_library(AOCL_LAPACK_LIB NAMES ${AOCL_LAPACK_LIB_NAME}
      HINTS
        "${AOCL_ROOT}/lib"
        "$ENV{AOCL_ROOT}/lib"
      PATHS
        /opt/AMD/aocl/aocl-linux-gcc/lib
    )
  endif()

  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    find_library(AOCL_FFTW_LIB NAMES ${AOCL_FFTW_LIB_NAME}
      HINTS
        "${AOCL_ROOT}/lib"
        "$ENV{AOCL_ROOT}/lib"
      PATHS
        /opt/AMD/aocl/aocl-linux-gcc/lib
    )
  endif()

  set(_aocl_found TRUE)
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "blas" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    if(NOT AOCL_BLAS_LIB)
      set(_aocl_found FALSE)
    endif()
  endif()
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "lapack" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    if(NOT AOCL_LAPACK_LIB)
      set(_aocl_found FALSE)
    endif()
  endif()
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    if(NOT AOCL_FFTW_LIB)
      set(_aocl_found FALSE)
    endif()
  endif()

  if(_aocl_found)
    set(_vpl_libs)
    if(NOT VendorPerfLibs_FIND_COMPONENTS OR "lapack" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
      list(APPEND _vpl_libs ${AOCL_LAPACK_LIB})
    endif()
    if(NOT VendorPerfLibs_FIND_COMPONENTS OR "blas" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
      list(APPEND _vpl_libs ${AOCL_BLAS_LIB})
    endif()
    if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
      list(APPEND _vpl_libs ${AOCL_FFTW_LIB})
    endif()

    if(VPL_THREADING)
      list(APPEND _vpl_libs ${VPL_THREADING})
    endif()

    list(APPEND _vpl_libs pthread m dl)

    set(VendorPerfLibs_LIBRARIES ${_vpl_libs} PARENT_SCOPE)
    set(VendorPerfLibs_FOUND_LIBRARIES TRUE PARENT_SCOPE)
    set(VPL_ID "AOCL" CACHE STRING "Vendor Performance Library ID (unset, IntelMKL, NVPL, ARMPL, AOCL)" FORCE)
  else()
    set(VendorPerfLibs_FOUND_LIBRARIES FALSE PARENT_SCOPE)
  endif()
endfunction()


if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64)$")
  if(NOT VPL_ID OR VPL_ID STREQUAL "IntelMKL")
    find_VPL_MKL()
  endif()
  if(NOT VPL_ID OR VPL_ID STREQUAL "AOCL")
    find_VPL_AOCL()
  endif()
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
  if(NOT VPL_ID OR VPL_ID STREQUAL "NVPL")
    find_VPL_NVPL()
  endif()
  if(NOT VPL_ID OR VPL_ID STREQUAL "ARMPL")
    find_VPL_ARMPL()
  endif()
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

  if(NOT VendorPerfLibs_FIND_QUIETLY)
    if(VendorPerfLibs_FIND_COMPONENTS)
      message(STATUS "VendorPerfLibs: Successfully found VPL_ID '${VPL_ID}' with components: ${VendorPerfLibs_FIND_COMPONENTS}")
    else()
      message(STATUS "VendorPerfLibs: Successfully found VPL_ID '${VPL_ID}'")
    endif()
  endif()
else()
  if(NOT VendorPerfLibs_FIND_QUIETLY AND NOT VendorPerfLibs_FIND_REQUIRED)
    if(VPL_ID)
      message(WARNING "VendorPerfLibs: Failed to find requested VPL_ID '${VPL_ID}'")
    else()
      message(WARNING "VendorPerfLibs: Failed to find any Vendor Performance Libraries")
    endif()
  endif()
endif()
