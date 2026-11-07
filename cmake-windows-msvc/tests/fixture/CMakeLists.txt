cmake_minimum_required(VERSION 3.20)
project(fixture CXX)

set(GREETING "default greeting" CACHE STRING "Text the fixture prints")

add_executable(fixture main.cpp)
target_compile_definitions(fixture PRIVATE "GREETING=\"${GREETING}\"")
install(TARGETS fixture)
