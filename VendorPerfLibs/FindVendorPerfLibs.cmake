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
# - VPL::lapack
# - VPL::fft
#
# Input variables:
# - VPL_ID: Specifies the vendor performance library to search for. Acceptable values are:
#     - "IntelMKL" : Intel Math Kernel Library
#     - "Generic"  : Generic BLAS/LAPACK/FFT
# - VPL_OMP: A boolean specifying the threading layer to use. If ON, OpenMP threading is used. If OFF (default), sequential is used.
#

include(FindPackageHandleStandardArgs)

if(NOT (CMAKE_C_COMPILER_LOADED OR CMAKE_CXX_COMPILER_LOADED))
  message(FATAL_ERROR "VendorPerfLibs: C or CXX compiler must be loaded before calling find_package(VendorPerfLibs)")
endif()

option(VPL_OMP "Use OpenMP threading for Vendor Performance Libraries" OFF)
if(NOT VendorPerfLibs_FIND_QUIETLY)
  if(VPL_OMP)
    message(STATUS "Requested OpenMP threaded Vendor Performance Libraries")
  else()
    message(STATUS "Requested non-threaded Vendor Performance Libraries")
  endif()
endif()


set(_VPL_VALID_IDS "IntelMKL" "Generic")
function(check_VPL_ID var_name id_to_check)
  if(NOT id_to_check IN_LIST _VPL_VALID_IDS)
    message(FATAL_ERROR "VendorPerfLibs: Unknown ${var_name} '${id_to_check}'. Acceptable values are: 'IntelMKL', 'Generic'")
  endif()
endfunction()

macro(speculateVendor)
  find_library(_MKL_CORE_TEST_LIB NAMES mkl_core
    HINTS
      "${MKL_ROOT}/lib/intel64"
      "$ENV{MKLROOT}/lib/intel64"
      "$ENV{MKL_ROOT}/lib/intel64"
    PATHS
      /opt/intel/oneapi/mkl/latest/lib/intel64
      /opt/intel/mkl/lib/intel64
  )

  if(_MKL_CORE_TEST_LIB)
    set(VPL_ID_GUESS "IntelMKL")
  else()
    set(VPL_ID_GUESS "Generic")
  endif()
endmacro()

if(NOT VPL_ID)
  speculateVendor()
else()
  check_VPL_ID("VPL_ID" "${VPL_ID}")
endif()

set(VPL_ID "${VPL_ID_GUESS}" CACHE STRING "Vendor Performance Library ID (IntelMKL, Generic)")

set(_find_package_args)
if(VendorPerfLibs_FIND_QUIETLY)
  list(APPEND _find_package_args QUIET REQUIRED)
endif()

macro(find_VPL_blas)
  set(VPL_blas_ID ${VPL_ID} CACHE STRING "Vendor BLAS ID (IntelMKL, Generic)")
  check_VPL_ID("VPL_blas_ID" "${VPL_blas_ID}")
if(NOT VendorPerfLibs_FIND_QUIETLY)
  message(STATUS "Searching for Vendor BLAS. Requested VPL_blas_ID '${VPL_blas_ID}'")
endif()

  if(VPL_blas_ID STREQUAL "IntelMKL")
    if(NOT VPL_OMP)
      set(BLA_VENDOR "Intel10_64lp_seq")
    else()
      set(BLA_VENDOR "Intel10_64lp")
    endif()
    find_package(BLAS ${_find_package_args})
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
  else()
    find_package(BLAS ${_find_package_args})
  endif()
endmacro()

macro(find_VPL_lapack)
  set(VPL_lapack_ID ${VPL_ID} CACHE STRING "Vendor LAPACK ID (IntelMKL, Generic)")
  check_VPL_ID("VPL_lapack_ID" "${VPL_lapack_ID}")
if(NOT VendorPerfLibs_FIND_QUIETLY)
  message(STATUS "Searching for Vendor LAPACK. Requested VPL_lapack_ID '${VPL_lapack_ID}'")
endif()

  if(VPL_lapack_ID STREQUAL "IntelMKL")
    if(NOT VPL_OMP)
      set(BLA_VENDOR "Intel10_64lp_seq")
    else()
      set(BLA_VENDOR "Intel10_64lp")
    endif()
    find_package(LAPACK ${_find_package_args})
  else()
    find_package(LAPACK ${_find_package_args})
  endif()
endmacro()

macro(find_VPL_fft)
  set(VPL_fft_ID ${VPL_ID} CACHE STRING "Vendor FFT ID (IntelMKL, Generic)")
  check_VPL_ID("VPL_fft_ID" "${VPL_fft_ID}")
if(NOT VendorPerfLibs_FIND_QUIETLY)
  message(STATUS "Searching for Vendor FFT. Requested VPL_fft_ID '${VPL_fft_ID}'")
endif()

  if(VPL_fft_ID STREQUAL "IntelMKL")
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
    set(FFT_LIBRARIES ${BLAS_LIBRARIES})
  else()
    # search for fftw3
    set(FFT_LIBRARIES "FIXME")
  endif()
endmacro()

set(_vpl_required_vars BLAS_LIBRARIES)
# blas is always searched regardless of request
find_VPL_blas()
if(NOT VPL_blas_ID STREQUAL "Generic")
  list(APPEND _vpl_required_vars VendorPerfLibs_INCLUDE_DIR)
endif()

if(NOT VendorPerfLibs_FIND_COMPONENTS OR "lapack" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
  find_VPL_lapack()
  list(APPEND _vpl_required_vars LAPACK_LIBRARIES)
endif()

if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
  find_VPL_fft()
  list(APPEND _vpl_required_vars VendorPerfLibs_FFTW3_INCLUDE_DIR FFT_LIBRARIES)
endif()

find_package_handle_standard_args(VendorPerfLibs
  REQUIRED_VARS ${_vpl_required_vars}
)

if(VendorPerfLibs_FOUND)
  # Create VPL::blas
  if(NOT TARGET VPL::blas)
    add_library(VPL::blas INTERFACE IMPORTED)
    set_target_properties(VPL::blas PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${VendorPerfLibs_INCLUDE_DIR}"
      INTERFACE_LINK_LIBRARIES "${BLAS_LIBRARIES}"
    )
  endif()

  # Create VPL::lapack
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "lapack" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    if(NOT TARGET VPL::lapack)
      add_library(VPL::lapack INTERFACE IMPORTED)
      set_target_properties(VPL::lapack PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${VendorPerfLibs_INCLUDE_DIR}"
        INTERFACE_LINK_LIBRARIES "${LAPACK_LIBRARIES}"
      )
    endif()
  endif()

  # Create VPL::fft
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    if(NOT TARGET VPL::fft)
      add_library(VPL::fft INTERFACE IMPORTED)
      set_target_properties(VPL::fft PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${VendorPerfLibs_INCLUDE_DIR};${VendorPerfLibs_FFTW3_INCLUDE_DIR}"
        INTERFACE_LINK_LIBRARIES "${FFT_LIBRARIES}"
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
