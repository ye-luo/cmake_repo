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
# Searches for Vendor Performance Libraries (such as Intel MKL, AMD AOCL, or generic
# equivalents like Netlib LAPACK and FFTW) and provides a unified interface.
#
# This module supports the following components:
# - lapack    : Linear Algebra PACKage
# - scalapack : SCAlable Linear Algebra PACKage
# - fft       : Fast Fourier Transform
# - vml       : Vector Math Library
#
# Example usage:
#   find_package(VendorPerfLibs COMPONENTS lapack fft vml REQUIRED)
#
# This module creates the following CMake imported targets (if their
# respective components are found):
# - VPL::lapack
# - VPL::scalapack
# - VPL::fft
# - VPL::vml
#
# Input variables:
# - VPL_ID: Specifies the vendor performance library family to search for.
#   Acceptable values are:
#     - "IntelMKL" : Intel Math Kernel Library
#     - "AOCL"     : AMD Optimizing CPU Libraries
#     - "ARMPL"    : Arm Performance Libraries
#     - "NVPL"     : NVIDIA Performance Libraries
#     - "Generic"  : Generic libraries (e.g., standard BLAS/LAPACK and FFTW)
#   Note: If VPL_ID is not set, the following rules determine its value
#   (once a rule applies, the subsequent rules are ignored):
#     1. "Generic" if BLA_VENDOR was specified.
#     2. "IntelMKL" if the Intel MKL mkl_core library file was found.
#     3. "AOCL" if the AOCL aoclutils library file was found.
#     4. "ARMPL" if the ArmPL library file was found.
#     5. "NVPL" if the nvpl CMake package was found.
#     6. "Generic" if all previous rules fail.
#
# - VPL_OMP: If ON, OpenMP threading is requested. If OFF (default), sequential is used.
#   Note: If ON, you must call find_package(OpenMP) before finding VendorPerfLibs.
#   It is recommended to set the following in the project top-level for consistent selection of threading.
#   option(VPL_OMP "Use OpenMP threading for Vendor Performance Libraries" ${<project_OpenMP_variable>})
#
# - VPL_MPI: Specifies the MPI layer for library components depending on MPI.
#   Acceptable values are "openmpi" and "mpich" or left unset.
#   Note: If VPL_MPI is set, you must call find_package(MPI) before finding VendorPerfLibs.
#
# Advanced Component-Specific Variables:
# - VPL_lapack_ID: Overrides VPL_ID specifically for the LAPACK component.
# - VPL_scalapack_ID: Overrides VPL_ID specifically for the ScaLAPACK component.
# - VPL_fft_ID: Overrides VPL_ID specifically for the FFT component.
# - VPL_vml_ID: Overrides VPL_ID specifically for the VML component.
#

include(FindPackageHandleStandardArgs)
include(CMakePushCheckState)

if(NOT (CMAKE_C_COMPILER_LOADED OR CMAKE_CXX_COMPILER_LOADED))
  message(FATAL_ERROR "VendorPerfLibs: C or CXX compiler must be loaded before calling find_package(VendorPerfLibs)")
endif()

cmake_push_check_state()

if(VPL_OMP)
  if(NOT OpenMP_FOUND)
    message(FATAL_ERROR "VendorPerfLibs: VPL_OMP is ON but OpenMP_FOUND is false. Please invoke find_package(OpenMP) before VendorPerfLibs.")
  endif()
  if(CMAKE_Fortran_COMPILER_LOADED AND OpenMP_Fortran_FOUND)
    set(CMAKE_REQUIRED_LINK_OPTIONS ${OpenMP_Fortran_FLAGS})
  elseif(CMAKE_C_COMPILER_LOADED AND OpenMP_C_FOUND)
    set(CMAKE_REQUIRED_LINK_OPTIONS ${OpenMP_C_FLAGS})
  elseif(CMAKE_CXX_COMPILER_LOADED AND OpenMP_CXX_FOUND)
    set(CMAKE_REQUIRED_LINK_OPTIONS ${OpenMP_CXX_FLAGS})
  endif()
endif()

set(_VPL_VALID_MPIS "openmpi" "mpich")
function(check_VPL_MPI var_name mpi_to_check)
  if(NOT mpi_to_check IN_LIST _VPL_VALID_MPIS)
    message(FATAL_ERROR "VendorPerfLibs: Unknown ${var_name} '${mpi_to_check}'. Acceptable values are: 'openmpi', 'mpich'")
  endif()
endfunction()

if(VPL_MPI)
  check_VPL_MPI("VPL_MPI" "${VPL_MPI}")
  if(NOT MPI_FOUND)
    message(FATAL_ERROR "VendorPerfLibs: VPL_MPI is set but MPI_FOUND is false. Please invoke find_package(MPI) before VendorPerfLibs.")
  endif()
endif()

set(_VPL_VALID_IDS "IntelMKL" "AOCL" "ARMPL" "NVPL" "Generic")
function(check_VPL_ID var_name id_to_check)
  if(NOT id_to_check IN_LIST _VPL_VALID_IDS)
    message(FATAL_ERROR "VendorPerfLibs: Unknown ${var_name} '${id_to_check}'. Acceptable values are: 'IntelMKL', 'AOCL', 'ARMPL', 'NVPL', 'Generic'")
  endif()
endfunction()

macro(speculateVendor)
  find_library(_MKL_CORE_TEST_LIB NAMES mkl_core
    HINTS
      "$ENV{MKLROOT}/lib/intel64"
  )

  find_library(AOCL_UTILS_LIB NAMES aoclutils)

  find_library(_ARMPL_TEST_LIB NAMES armpl_lp64 armpl_lp64_mp armpl)

  find_package(nvpl QUIET)

  if(_MKL_CORE_TEST_LIB)
    set(VPL_ID_GUESS "IntelMKL")
    if(NOT VendorPerfLibs_FIND_QUIETLY)
      message(STATUS "Found mkl_core library file. Guessed VPL_ID 'IntelMKL'.")
    endif()
  elseif(AOCL_UTILS_LIB)
    set(VPL_ID_GUESS "AOCL")
    if(NOT VendorPerfLibs_FIND_QUIETLY)
      message(STATUS "Found aoclutils library file. Guessed VPL_ID 'AOCL'.")
    endif()
  elseif(_ARMPL_TEST_LIB)
    set(VPL_ID_GUESS "ARMPL")
    if(NOT VendorPerfLibs_FIND_QUIETLY)
      message(STATUS "Found armpl library file. Guessed VPL_ID 'ARMPL'.")
    endif()
  elseif(nvpl_FOUND)
    set(VPL_ID_GUESS "NVPL")
    if(NOT VendorPerfLibs_FIND_QUIETLY)
      message(STATUS "Found nvpl package. Guessed VPL_ID 'NVPL'.")
    endif()
  else()
    set(VPL_ID_GUESS "Generic")
    if(NOT VendorPerfLibs_FIND_QUIETLY)
      message(STATUS "Signs of vendor performance libraries not found. Guessed VPL_ID 'Generic'.")
    endif()
  endif()
endmacro()

if(NOT VPL_ID)
  if(BLA_VENDOR)
    # If BLA_VENDOR was set, interpret user intention as opting out of auto-detection by VPL.
    set(VPL_ID_GUESS "Generic")
    if(NOT VendorPerfLibs_FIND_QUIETLY)
      message(STATUS "BLA_VENDOR has been set to '${BLA_VENDOR}'. Guessed VPL_ID 'Generic'.")
    endif()
  else()
    speculateVendor()
  endif()
else()
  check_VPL_ID("VPL_ID" "${VPL_ID}")
endif()

set(VPL_ID "${VPL_ID_GUESS}" CACHE STRING "Vendor Performance Library ID (IntelMKL, AOCL, ARMPL, NVPL, Generic)")

set(_find_package_args)
if(VendorPerfLibs_FIND_QUIETLY)
  list(APPEND _find_package_args QUIET)
endif()

function(warn_MKL_Fortran_ABI_issue CORE_LIB_VAR)
  # https://gitlab.kitware.com/cmake/cmake/-/merge_requests/12479
  # Switch to GNU Fortran ABI regarding how functions return complex numbers and how characters are passed (but not on Apple, where MKL does not provide it).
  # GNU and LLVMFlang families of compilers follow modern C99 _Complex ABI convention.
  # Intel, IntelLLVM, NVHPC follows the legacy convention.
  if(CMAKE_Fortran_COMPILER_LOADED AND CMAKE_VERSION VERSION_LESS "4.5")
    if(NOT (CMAKE_Fortran_COMPILER_ID MATCHES "^Intel" OR CMAKE_Fortran_COMPILER_ID STREQUAL "NVHPC") AND NOT APPLE)
      string(REPLACE "mkl_intel_lp64" "mkl_gf_lp64" CORE_LIBS "${${CORE_LIB_VAR}}")
    else()
      set(CORE_LIBS "${${CORE_LIB_VAR}}")
    endif()
    if(NOT VendorPerfLibs_FIND_QUIETLY AND NOT CORE_LIBS STREQUAL "${${CORE_LIB_VAR}}")
      message(WARNING "Potential incorrect selection of MKL ABI layer in variable ${CORE_LIB_VAR}.\n"
                      "    Original  : ${${CORE_LIB_VAR}}.\n"
                      "    Preferred : ${CORE_LIBS}\n"
                      "Use CMake >=4.5")
    endif()
  endif()
endfunction()

macro(find_VPL_core)
  set(VPL_CORE_FOUND TRUE)
  if(VPL_ID STREQUAL "IntelMKL")
    # MKL core library support BLAS/LAPACK and FFT.
    # Thus we require VendorPerfLibs_INCLUDE_DIR and VPL_CORE_LIBRARIES being set
    list(APPEND _vpl_required_vars VendorPerfLibs_INCLUDE_DIR VPL_CORE_LIBRARIES)

    if(NOT VPL_OMP)
      set(BLA_VENDOR "Intel10_64lp_seq")
    else()
      set(BLA_VENDOR "Intel10_64lp")
    endif()
    find_package(BLAS ${_find_package_args})

    # Try to find MKL include directory
    find_path(VendorPerfLibs_INCLUDE_DIR NAMES mkl.h
      HINTS
        "$ENV{MKLROOT}/include"
      PATH_SUFFIXES mkl
    )

    if(BLAS_FOUND AND VendorPerfLibs_INCLUDE_DIR)
      warn_MKL_Fortran_ABI_issue(BLAS_LIBRARIES)
      set(VPL_CORE_LIBRARIES ${BLAS_LIBRARIES})
    else()
      set(VPL_CORE_FOUND FALSE)
      if(NOT VendorPerfLibs_FIND_QUIETLY)
        set(_vpl_warning_core_mkl)
        if(NOT VendorPerfLibs_INCLUDE_DIR)
          list(APPEND _vpl_warning_core_mkl "Intel header file mkl.h not found.\n")
        endif()
        if(NOT BLAS_FOUND)
          # exactly the same check as in speculateVendor in case it was not called.
          find_library(_MKL_CORE_TEST_LIB NAMES mkl_core
            HINTS
              "$ENV{MKLROOT}/lib/intel64"
          )
          if(_MKL_CORE_TEST_LIB)
            list(APPEND _vpl_warning_core_mkl "Intel mkl_core library file was found. FindBLAS failed most likely when testing linking MKL for complex reasons.\n")
            if(VPL_OMP)
              list(APPEND _vpl_warning_core_mkl "Threaded MKL requested but linking may fail due to incompatible compiler OpenMP runtime. To request sequential MKL, set VPL_OMP=OFF.\n")
            endif()
          else()
            list(APPEND _vpl_warning_core_mkl "Intel mkl_core library file not found. Please set the MKL root directory via a CMake variable CMAKE_PREFIX_PATH or VendorPerfLibs_ROOT.\n")
          endif()
        endif()
        message(WARNING ${_vpl_warning_core_mkl} "If you'd like to fully opt out Intel MKL, set VPL_ID=Generic.")
      endif()
    endif()
  elseif(VPL_ID STREQUAL "AOCL")
    list(APPEND _vpl_required_vars VendorPerfLibs_INCLUDE_DIR)

    set(_vpl_warning_core_aocl)
    find_path(VendorPerfLibs_INCLUDE_DIR NAMES blis/blis.h blis.h)
    if(NOT VendorPerfLibs_INCLUDE_DIR)
      set(VPL_CORE_FOUND FALSE)
      list(APPEND _vpl_warning_core_aocl "AOCL header file blis.h not found.\n")
    endif()

    if(NOT VendorPerfLibs_FIND_QUIETLY AND NOT VendorPerfLibs_INCLUDE_DIR)
      message(WARNING ${_vpl_warning_core_aocl} "If you'd like to fully opt out AOCL, set VPL_ID=Generic.")
    endif()
  elseif(VPL_ID STREQUAL "ARMPL")
    list(APPEND _vpl_required_vars VendorPerfLibs_INCLUDE_DIR VPL_CORE_LIBRARIES)

    if(NOT VPL_OMP)
      set(BLA_VENDOR "Arm")
    else()
      set(BLA_VENDOR "Arm_mp")
    endif()
    find_package(BLAS ${_find_package_args})

    find_path(VendorPerfLibs_INCLUDE_DIR NAMES armpl.h)

    if(BLAS_FOUND AND VendorPerfLibs_INCLUDE_DIR)
      set(VPL_CORE_LIBRARIES ${BLAS_LIBRARIES})
    else()
      set(VPL_CORE_FOUND FALSE)
      if(NOT VendorPerfLibs_FIND_QUIETLY)
        set(_vpl_warning_core_armpl)
        if(NOT VendorPerfLibs_INCLUDE_DIR)
          list(APPEND _vpl_warning_core_armpl "ArmPL header file armpl.h not found.\n")
        endif()
        if(NOT BLAS_FOUND)
          list(APPEND _vpl_warning_core_armpl "ArmPL library not found.\n")
        endif()
        message(WARNING ${_vpl_warning_core_armpl} "If you'd like to fully opt out ArmPL, set VPL_ID=Generic.")
      endif()
    endif()
  elseif(VPL_ID STREQUAL "NVPL")
    if(CMAKE_VERSION VERSION_LESS 4.1)
      message(FATAL_ERROR "VendorPerfLibs: NVPL support requires CMake 4.1 or newer (current: ${CMAKE_VERSION})")
    endif()
    find_package(nvpl QUIET)
    if(NOT nvpl_FOUND)
      set(VPL_CORE_FOUND FALSE)
      if(NOT VendorPerfLibs_FIND_QUIETLY)
        message(WARNING "NVPL not found. If you'd like to fully opt out NVPL, set VPL_ID=Generic.")
      endif()
    endif()
  endif()

  if(VPL_CORE_FOUND)
    list(APPEND _vpl_lib_found_ids "core(${VPL_ID})")
  endif()
endmacro()

macro(find_VPL_lapack)
  set(VPL_lapack_ID ${VPL_ID} CACHE STRING "Vendor LAPACK ID (IntelMKL, AOCL, ARMPL, NVPL, Generic)")
  check_VPL_ID("VPL_lapack_ID" "${VPL_lapack_ID}")

  if(VPL_lapack_ID STREQUAL "IntelMKL")
    if(NOT VPL_ID STREQUAL "IntelMKL")
      message(FATAL_ERROR "VendorPerfLibs: VPL_lapack_ID is IntelMKL but VPL_ID is not IntelMKL. Unsupported.")
    endif()
    if(NOT VPL_OMP)
      set(BLA_VENDOR "Intel10_64lp_seq")
    else()
      set(BLA_VENDOR "Intel10_64lp")
    endif()
    find_package(LAPACK ${_find_package_args})
    if(LAPACK_FOUND)
      warn_MKL_Fortran_ABI_issue(LAPACK_LIBRARIES)
    endif()
  elseif(VPL_lapack_ID STREQUAL "AOCL")
    if(NOT VPL_ID STREQUAL "AOCL")
      message(FATAL_ERROR "VendorPerfLibs: VPL_lapack_ID is AOCL but VPL_ID is not AOCL. Unsupported.")
    endif()
    if(NOT VPL_OMP)
      set(BLA_VENDOR "AOCL")
    else()
      set(BLA_VENDOR "AOCL_mt")
    endif()
    find_package(LAPACK ${_find_package_args})
  elseif(VPL_lapack_ID STREQUAL "ARMPL")
    if(NOT VPL_ID STREQUAL "ARMPL")
      message(FATAL_ERROR "VendorPerfLibs: VPL_lapack_ID is ARMPL but VPL_ID is not ARMPL. Unsupported.")
    endif()
    if(NOT VPL_OMP)
      set(BLA_VENDOR "Arm")
    else()
      set(BLA_VENDOR "Arm_mp")
    endif()
    find_package(LAPACK ${_find_package_args})
  elseif(VPL_lapack_ID STREQUAL "NVPL")
    if(NOT VPL_ID STREQUAL "NVPL")
      message(FATAL_ERROR "VendorPerfLibs: VPL_lapack_ID is NVPL but VPL_ID is not NVPL. Unsupported.")
    endif()
    if(NOT VPL_OMP)
      set(BLA_THREAD "SEQ")
    else()
      set(BLA_THREAD "OMP")
    endif()
    set(BLA_VENDOR "NVPL")
    find_package(LAPACK ${_find_package_args})
  else()
    find_package(LAPACK ${_find_package_args})
  endif()

  if(LAPACK_FOUND)
    list(APPEND _vpl_lib_found_ids "lapack(${VPL_lapack_ID})")
    set(VendorPerfLibs_lapack_FOUND TRUE)
  else()
    set(VendorPerfLibs_lapack_FOUND FALSE)
    if(NOT VendorPerfLibs_FIND_QUIETLY)
      message(WARNING "LAPACK for VPL_lapack_ID '${VPL_lapack_ID}' with OpenMP ${VPL_OMP}, not found")
    endif()
  endif()
endmacro()

macro(find_VPL_scalapack)
  set(VPL_scalapack_ID ${VPL_ID} CACHE STRING "Vendor ScaLAPACK ID (IntelMKL, AOCL, ARMPL, NVPL, Generic)")
  check_VPL_ID("VPL_scalapack_ID" "${VPL_scalapack_ID}")

  set(VPL_SCALAPACK_FOUND TRUE)
  if(VPL_scalapack_ID STREQUAL "IntelMKL")
    if(NOT VPL_ID STREQUAL "IntelMKL")
      message(FATAL_ERROR "VendorPerfLibs: VPL_scalapack_ID is IntelMKL but VPL_ID is not IntelMKL. Unsupported.")
    endif()

    get_filename_component(_mkl_core_dir "${_MKL_CORE_TEST_LIB}" DIRECTORY)

    find_library(_MKL_SCALAPACK_LIB NAMES mkl_scalapack_lp64 HINTS ${_mkl_core_dir})

    if(VPL_MPI STREQUAL "openmpi")
      find_library(_MKL_BLACS_${VPL_MPI}_LIB NAMES mkl_blacs_openmpi_lp64 HINTS ${_mkl_core_dir})
    elseif(VPL_MPI STREQUAL "mpich")
      find_library(_MKL_BLACS_${VPL_MPI}_LIB NAMES mkl_blacs_intelmpi_lp64 mkl_blacs_mpich_lp64 HINTS ${_mkl_core_dir})
    endif()

    if(_MKL_SCALAPACK_LIB AND _MKL_BLACS_${VPL_MPI}_LIB AND VPL_CORE_LIBRARIES)
      set(VPL_SCALAPACK_LIBRARIES ${_MKL_SCALAPACK_LIB} ${_MKL_BLACS_${VPL_MPI}_LIB} ${VPL_CORE_LIBRARIES})
    else()
      set(VPL_SCALAPACK_FOUND FALSE)
    endif()
  elseif(VPL_scalapack_ID STREQUAL "NVPL")
    if(NOT VPL_ID STREQUAL "NVPL")
      message(FATAL_ERROR "VendorPerfLibs: VPL_scalapack_ID is NVPL but VPL_ID is not NVPL. Unsupported.")
    endif()

    find_package(nvpl QUIET)

    # Check for imported targets
    if(TARGET nvpl::scalapack_lp64)
      set(_NVPL_SCALAPACK_LIB nvpl::scalapack_lp64)
    endif()

    if(VPL_MPI STREQUAL "openmpi")
      set(_mpi_lib_ver)
      if(CMAKE_Fortran_COMPILER_LOADED AND MPI_Fortran_LIBRARY_VERSION_STRING)
        set(_mpi_lib_ver "${MPI_Fortran_LIBRARY_VERSION_STRING}")
      elseif(CMAKE_C_COMPILER_LOADED AND MPI_C_LIBRARY_VERSION_STRING)
        set(_mpi_lib_ver "${MPI_C_LIBRARY_VERSION_STRING}")
      elseif(CMAKE_CXX_COMPILER_LOADED AND MPI_CXX_LIBRARY_VERSION_STRING)
        set(_mpi_lib_ver "${MPI_CXX_LIBRARY_VERSION_STRING}")
      endif()

      set(_openmpi_major)
      if(_mpi_lib_ver MATCHES "Open[ -]?MPI[ \tv]*([0-9]+)")
        set(_openmpi_major "${CMAKE_MATCH_1}")
      elseif(_mpi_lib_ver MATCHES "([0-9]+)\\.[0-9]+")
        set(_openmpi_major "${CMAKE_MATCH_1}")
      endif()

      if(_openmpi_major)
        set(_openmpi_target "nvpl::blacs_lp64_openmpi${_openmpi_major}")
      else()
        set(_openmpi_target "nvpl::blacs_lp64_openmpi5")
      endif()

      if(TARGET ${_openmpi_target})
        set(_NVPL_BLACS_${VPL_MPI}_LIB ${_openmpi_target})
      endif()
      unset(_mpi_lib_ver)
      unset(_openmpi_major)
      unset(_openmpi_target)
    elseif(VPL_MPI STREQUAL "mpich")
      if(TARGET nvpl::blacs_lp64_mpich)
        set(_NVPL_BLACS_${VPL_MPI}_LIB nvpl::blacs_lp64_mpich)
      endif()
    endif()

    if(_NVPL_SCALAPACK_LIB AND _NVPL_BLACS_${VPL_MPI}_LIB)
      set(VPL_SCALAPACK_LIBRARIES ${_NVPL_SCALAPACK_LIB} ${_NVPL_BLACS_${VPL_MPI}_LIB} ${LAPACK_LIBRARIES})
    else()
      set(VPL_SCALAPACK_FOUND FALSE)
    endif()
  else()
    set(SCALAPACK_FOUND TRUE)
    if(NOT SCALAPACK_LIBRARIES)
      find_library(SCALAPACK_LIBRARY NAMES scalapack-${VPL_MPI} scalapack)
      if(SCALAPACK_LIBRARY)
        message(STATUS "Found ScaLAPACK: ${SCALAPACK_LIBRARY}")
        set(SCALAPACK_LIBRARIES ${SCALAPACK_LIBRARY} ${LAPACK_LIBRARIES})
      else()
        set(SCALAPACK_FOUND FALSE)
      endif()
    endif()

    if(SCALAPACK_FOUND)
      set(VPL_SCALAPACK_LIBRARIES ${SCALAPACK_LIBRARIES})
    else()
      set(VPL_SCALAPACK_FOUND FALSE)
    endif()
  endif()

  if(VPL_SCALAPACK_FOUND)
    list(APPEND _vpl_lib_found_ids "scalapack(${VPL_scalapack_ID})")
    set(VendorPerfLibs_scalapack_FOUND TRUE)
  else()
    set(VendorPerfLibs_scalapack_FOUND FALSE)
    if(NOT VendorPerfLibs_FIND_QUIETLY)
      message(WARNING "ScaLAPACK for VPL_scalapack_ID '${VPL_scalapack_ID}', not found")
    endif()
  endif()
endmacro()

macro(find_VPL_fft)
  set(VPL_fft_ID ${VPL_ID} CACHE STRING "Vendor FFT ID (IntelMKL, AOCL, ARMPL, NVPL, Generic)")
  check_VPL_ID("VPL_fft_ID" "${VPL_fft_ID}")
  list(APPEND _vpl_required_vars VPL_FFT_LIBRARIES)

  set(VPL_FFT_FOUND TRUE)
  if(VPL_fft_ID STREQUAL "IntelMKL")
    if(NOT VPL_ID STREQUAL "IntelMKL")
      message(FATAL_ERROR "VendorPerfLibs: VPL_fft_ID is IntelMKL but VPL_ID is not IntelMKL. Unsupported.")
    endif()
    list(APPEND _vpl_required_vars VendorPerfLibs_FFTW_INCLUDE_DIR)
    find_path(VendorPerfLibs_FFTW_INCLUDE_DIR NAMES fftw3.f03
      HINTS
        "$ENV{MKLROOT}/include"
      PATH_SUFFIXES fftw mkl/fftw
    )
    set(VPL_FFT_LIBRARIES ${VPL_CORE_LIBRARIES})
    if(NOT VendorPerfLibs_FFTW_INCLUDE_DIR OR NOT VPL_FFT_LIBRARIES)
      set(VPL_FFT_FOUND FALSE)
    endif()
  elseif(VPL_fft_ID STREQUAL "ARMPL")
    if(NOT VPL_ID STREQUAL "ARMPL")
      message(FATAL_ERROR "VendorPerfLibs: VPL_fft_ID is ARMPL but VPL_ID is not ARMPL. Unsupported.")
    endif()
    list(APPEND _vpl_required_vars VendorPerfLibs_FFTW_INCLUDE_DIR)
    find_path(VendorPerfLibs_FFTW_INCLUDE_DIR NAMES fftw3.f03 fftw3.h)
    set(VPL_FFT_LIBRARIES ${VPL_CORE_LIBRARIES})
    if(NOT VendorPerfLibs_FFTW_INCLUDE_DIR OR NOT VPL_FFT_LIBRARIES)
      set(VPL_FFT_FOUND FALSE)
    endif()
  elseif(VPL_fft_ID STREQUAL "NVPL")
    if(NOT VPL_ID STREQUAL "NVPL")
      message(FATAL_ERROR "VendorPerfLibs: VPL_fft_ID is NVPL but VPL_ID is not NVPL. Unsupported.")
    endif()
    find_package(nvpl QUIET)
    if(TARGET nvpl::fftw)
      set(VPL_FFT_LIBRARIES nvpl::fftw)
    else()
      set(VPL_FFT_FOUND FALSE)
    endif()
  else()
    list(APPEND _vpl_required_vars VendorPerfLibs_FFTW_INCLUDE_DIR)
    # search for fftw
    if(VPL_OMP)
      find_package(FFTW ${_find_package_args} COMPONENTS seq omp)
      if(NOT FFTW_FOUND)
        find_package(FFTW ${_find_package_args} COMPONENTS seq)
      endif()
    else()
      find_package(FFTW ${_find_package_args} COMPONENTS seq)
    endif()
    if(FFTW_FOUND)
      set(VPL_FFT_FOUND TRUE)
      set(VendorPerfLibs_FFTW_INCLUDE_DIR ${FFTW_INCLUDE_DIR})
      set(VPL_FFT_LIBRARIES ${FFTW_LIBRARIES})
    else()
      set(VPL_FFT_FOUND FALSE)
    endif()
  endif()

  if(VPL_FFT_FOUND)
    list(APPEND _vpl_lib_found_ids "fft(${VPL_fft_ID})")
    set(VendorPerfLibs_fft_FOUND TRUE)
  else()
    set(VendorPerfLibs_fft_FOUND FALSE)
    if(NOT VendorPerfLibs_FIND_QUIETLY)
      message(WARNING "FFT for VPL_fft_ID '${VPL_fft_ID}' with OpenMP ${VPL_OMP}, not found")
    endif()
  endif()
endmacro()

macro(find_VPL_vml)
  set(VPL_vml_ID ${VPL_ID} CACHE STRING "Vendor VML ID (IntelMKL, AOCL, ARMPL, NVPL, Generic)")
  check_VPL_ID("VPL_vml_ID" "${VPL_vml_ID}")

  set(VPL_VML_FOUND TRUE)
  if(VPL_vml_ID STREQUAL "IntelMKL")
    if(NOT VPL_ID STREQUAL "IntelMKL")
      message(FATAL_ERROR "VendorPerfLibs: VPL_vml_ID is IntelMKL but VPL_ID is not IntelMKL. Unsupported.")
    endif()
    # VML is part of MKL core. No additional libraries needed beyond core MKL libraries.
    set(VPL_VML_LIBRARIES ${VPL_CORE_LIBRARIES})
    if(NOT VPL_VML_LIBRARIES)
      set(VPL_VML_FOUND FALSE)
    endif()
  elseif(VPL_vml_ID STREQUAL "AOCL")
    if(NOT VPL_ID STREQUAL "AOCL")
      message(FATAL_ERROR "VendorPerfLibs: VPL_vml_ID is AOCL but VPL_ID is not AOCL. Unsupported.")
    endif()
    find_library(VPL_VML_LIBRARIES NAMES alm)
    if(NOT VPL_VML_LIBRARIES)
      set(VPL_VML_FOUND FALSE)
    endif()
  elseif(VPL_vml_ID STREQUAL "ARMPL")
    if(NOT VPL_ID STREQUAL "ARMPL")
      message(FATAL_ERROR "VendorPerfLibs: VPL_vml_ID is ARMPL but VPL_ID is not ARMPL. Unsupported.")
    endif()
    find_library(VPL_VML_LIBRARIES NAMES amath)
    if(NOT VPL_VML_LIBRARIES)
      set(VPL_VML_FOUND FALSE)
    endif()
  else()
    # VML for NVPL, Generic is not currently supported (e.g. no direct open source drop-in)
    set(VPL_VML_FOUND FALSE)
  endif()

  if(VPL_VML_FOUND)
    list(APPEND _vpl_lib_found_ids "vml(${VPL_vml_ID})")
    set(VendorPerfLibs_vml_FOUND TRUE)
  else()
    set(VendorPerfLibs_vml_FOUND FALSE)
    # if VML is not supported by the vendor library or VPL_vml_ID=Generic, there is no need to issue the following warning.
    if(NOT VendorPerfLibs_FIND_QUIETLY AND DEFINED VPL_VML_LIBRARIES)
      message(WARNING "VML for VPL_vml_ID '${VPL_vml_ID}' not found")
    endif()
  endif()
endmacro()

set(_vpl_lib_found_ids)
set(_vpl_required_vars _vpl_lib_found_ids)
find_VPL_core()

if(NOT VendorPerfLibs_FIND_COMPONENTS OR "lapack" IN_LIST VendorPerfLibs_FIND_COMPONENTS OR "scalapack" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
  find_VPL_lapack()
endif()

if(NOT VendorPerfLibs_FIND_COMPONENTS OR "scalapack" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
  if(VendorPerfLibs_lapack_FOUND AND VPL_MPI)
    find_VPL_scalapack()
  else()
    set(VendorPerfLibs_scalapack_FOUND FALSE)
    if(NOT VendorPerfLibs_FIND_QUIETLY)
      if(NOT VendorPerfLibs_lapack_FOUND)
        message(WARNING "ScaLAPACK requires LAPACK to be found")
      endif()
      if(NOT VPL_MPI)
        message(WARNING "ScaLAPACK requires VPL_MPI to be set to 'openmpi' or 'mpich'")
      endif()
    endif()
  endif()
endif()

if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
  find_VPL_fft()
endif()

if(NOT VendorPerfLibs_FIND_COMPONENTS OR "vml" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
  find_VPL_vml()
endif()

find_package_handle_standard_args(VendorPerfLibs
  REQUIRED_VARS ${_vpl_required_vars}
  HANDLE_COMPONENTS
)

if(VendorPerfLibs_FOUND)
  # Create vpl_lapack
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "lapack" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    if(NOT TARGET vpl_lapack)
      add_library(vpl_lapack INTERFACE IMPORTED)
      set_target_properties(vpl_lapack PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${VendorPerfLibs_INCLUDE_DIR}"
        INTERFACE_LINK_LIBRARIES "${LAPACK_LIBRARIES}"
      )
      add_library(VPL::lapack ALIAS vpl_lapack)
    endif()
  endif()

  # Create vpl_scalapack
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "scalapack" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    if(NOT TARGET vpl_scalapack)
      add_library(vpl_scalapack INTERFACE IMPORTED)
      set_target_properties(vpl_scalapack PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${VendorPerfLibs_INCLUDE_DIR}"
        INTERFACE_LINK_LIBRARIES "${VPL_SCALAPACK_LIBRARIES}"
      )
      add_library(VPL::scalapack ALIAS vpl_scalapack)
    endif()
  endif()

  # Create vpl_fft
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "fft" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    if(NOT TARGET vpl_fft)
      add_library(vpl_fft INTERFACE IMPORTED)
      set_target_properties(vpl_fft PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${VendorPerfLibs_INCLUDE_DIR};${VendorPerfLibs_FFTW_INCLUDE_DIR}"
        INTERFACE_LINK_LIBRARIES "${VPL_FFT_LIBRARIES}"
      )
      add_library(VPL::fft ALIAS vpl_fft)
    endif()
  endif()

  # Create vpl_vml
  if(NOT VendorPerfLibs_FIND_COMPONENTS OR "vml" IN_LIST VendorPerfLibs_FIND_COMPONENTS)
    if(NOT TARGET vpl_vml)
      add_library(vpl_vml INTERFACE IMPORTED)
      set_target_properties(vpl_vml PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${VendorPerfLibs_INCLUDE_DIR}"
        INTERFACE_LINK_LIBRARIES "${VPL_VML_LIBRARIES}"
      )
      add_library(VPL::vml ALIAS vpl_vml)
    endif()
  endif()
endif()

cmake_pop_check_state()

# Scope cleanup
unset(_find_package_args)
unset(_vpl_required_vars)
unset(_vpl_lib_found_ids)
unset(_VPL_VALID_IDS)
unset(_VPL_VALID_MPIS)
