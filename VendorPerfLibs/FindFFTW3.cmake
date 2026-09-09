# FindFFTW3.cmake
#
# Finds the FFTW3 library.
#
# This module supports the following components:
#   seq - sequential FFTW3 library (fftw3)
#   omp - OpenMP FFTW3 library (fftw3_omp)
#
# This module defines the following variables:
#   FFTW3_FOUND        - True if FFTW3 was found.
#   FFTW3_INCLUDE_DIR  - Include directory for FFTW3.
#   FFTW3_LIBRARIES    - All FFTW3 libraries found.
#
# This module creates the following imported targets:
#   FFTW3::seq - The sequential FFTW3 library.
#   FFTW3::omp - The OpenMP FFTW3 library.

include(FindPackageHandleStandardArgs)

# Find include directory
find_path(FFTW3_INCLUDE_DIR
  NAMES fftw3.h fftw3.f03
)

set(FFTW3_LIBRARIES)
set(_FFTW3_REQUIRED_VARS FFTW3_INCLUDE_DIR)

# Find seq component
if(NOT FFTW3_FIND_COMPONENTS OR "seq" IN_LIST FFTW3_FIND_COMPONENTS)
  find_library(FFTW3_seq_LIBRARY NAMES fftw3)
  if(FFTW3_seq_LIBRARY)
    set(FFTW3_seq_FOUND TRUE)
    list(PREPEND FFTW3_LIBRARIES ${FFTW3_seq_LIBRARY})
  else()
    set(FFTW3_seq_FOUND FALSE)
  endif()
  list(PREPEND _FFTW3_REQUIRED_VARS FFTW3_seq_LIBRARY)
endif()

# Find omp component
if(NOT FFTW3_FIND_COMPONENTS OR "omp" IN_LIST FFTW3_FIND_COMPONENTS)
  find_library(FFTW3_omp_LIBRARY NAMES fftw3_omp)
  if(FFTW3_omp_LIBRARY)
    set(FFTW3_omp_FOUND TRUE)
    list(PREPEND FFTW3_LIBRARIES ${FFTW3_omp_LIBRARY})
  else()
    set(FFTW3_omp_FOUND FALSE)
  endif()
  list(PREPEND _FFTW3_REQUIRED_VARS FFTW3_omp_LIBRARY)
endif()

find_package_handle_standard_args(FFTW3
  REQUIRED_VARS ${_FFTW3_REQUIRED_VARS}
  HANDLE_COMPONENTS
)
