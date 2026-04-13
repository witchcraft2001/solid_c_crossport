cmake_minimum_required(VERSION 3.10)
project(solid_c_cross C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Warnings
if(MSVC)
    add_compile_options(/W3)
else()
    add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# Z80 Assembler (AS)
add_executable(as
    src/as/as_main.c
    src/as/as_lexer.c
    src/as/as_symtab.c
    src/as/as_expr.c
    src/as/as_instr.c
    src/as/as_directives.c
    src/as/as_rel.c
    src/as/as_pass.c
    src/as/as_io.c
)
target_include_directories(as PRIVATE src/as src/common)
