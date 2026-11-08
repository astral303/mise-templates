cmake_minimum_required(VERSION 3.20)
project(fixture CXX)

if(FIXTURE_FAIL_CONFIGURE)
  message(FATAL_ERROR "FIXTURE_FAIL_CONFIGURE is set.")
endif()

set(GREETING "default greeting" CACHE STRING "Text the fixture prints")

add_executable(fixture main.cpp)
target_compile_definitions(fixture PRIVATE "GREETING=\"${GREETING}\"")
install(TARGETS fixture)
