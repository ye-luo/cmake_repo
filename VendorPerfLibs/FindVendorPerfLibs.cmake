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
# - VPL_THREADING: Specifies the threading layer to use. Acceptable values are:
#     - unset    : Sequential (mkl_sequential) - default
#     - "gomp"   : GCC's libgomp, or any OpenMP runtime providing a compatibility layer for it
#     - "iomp5"  : Intel's libiomp5, or any OpenMP runtime providing a compatibility layer for it
#

include(FindPackageHandleStandardArgs)

set(_VPL_VALID_IDS "" "IntelMKL")
if(DEFINED VPL_ID AND NOT VPL_ID IN_LIST _VPL_VALID_IDS)
  message(FATAL_ERROR "VendorPerfLibs: Unknown VPL_ID '${VPL_ID}'. Acceptable values are: unset, 'IntelMKL'")
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
    set(VPL_ID "IntelMKL" CACHE STRING "Vendor Performance Library ID (unset, IntelMKL)" FORCE)
  else()
    set(VendorPerfLibs_FOUND_LIBRARIES FALSE PARENT_SCOPE)
  endif()
endfunction()


if(VendorPerfLibs_FIND_COMPONENTS AND "lapack" IN_LIST VendorPerfLibs_FIND_COMPONENTS AND NOT "blas" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
  list(APPEND VendorPerfLibs_FIND_COMPONENTS "blas")
endif()

if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64)$")
  if(NOT VPL_ID OR VPL_ID STREQUAL "IntelMKL")
    find_VPL_MKL()
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
