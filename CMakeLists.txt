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
    src/as/as_macro.c
)
target_include_directories(as PRIVATE src/as src/common)

# Object Librarian (OL)
add_executable(ol
    src/ol/ol_main.c
    src/ol/ol_io.c
    src/ol/ol_rel.c
    src/ol/ol_ops.c
)
target_include_directories(ol PRIVATE src/ol src/common)

# Code Generator (CC2)
add_executable(cc2
    src/cc2/cc2_main.c
    src/cc2/cc2_io.c
    src/cc2/cc2_tmc.c
    src/cc2/cc2_sym.c
    src/cc2/cc2_gen.c
    src/cc2/cc2_out.c
)
target_include_directories(cc2 PRIVATE src/cc2 src/common)
