cmake_minimum_required(VERSION 3.16)
project(vd_robot_description)

find_package(ament_cmake REQUIRED)

# RViz cannot load Git LFS pointer text as STL geometry.
file(GLOB RD02_MESH_FILES "${CMAKE_CURRENT_SOURCE_DIR}/description/meshes/*.STL")
foreach(mesh_file IN LISTS RD02_MESH_FILES)
  file(READ "${mesh_file}" mesh_header LIMIT 64)
  if(mesh_header MATCHES "^version https://git-lfs.github.com/spec/v1")
    message(FATAL_ERROR
      "${mesh_file} is a Git LFS pointer. Run 'git lfs pull' before building.")
  endif()
endforeach()

install(DIRECTORY description/launch/
  DESTINATION share/${PROJECT_NAME}/launch
  FILES_MATCHING PATTERN "*.launch.py" PATTERN "*.rviz"
)

# Keep the package://vd_robot_description/robots/RD02/meshes/ URIs in the URDF.
install(DIRECTORY
  description/urdf
  description/meshes
  description/xml
  description/usd
  DESTINATION share/${PROJECT_NAME}/robots/RD02
)

ament_package()
