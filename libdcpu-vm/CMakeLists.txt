cmake_minimum_required(VERSION 2.8.5)
project(libdcpu-vm)

# Check to ensure that we are running as part of the
# root CMakeLists.txt file.
if(NOT DEFINED IS_ROOT)
  message(FATAL_ERROR "You must generate the CMake files as part of the root directory.")
endif(NOT DEFINED IS_ROOT)

# Define the libvm project.
dt_project(library)
dt_needs(libtcod)
dt_needs(libdcpu)
dt_needs(bstring)

