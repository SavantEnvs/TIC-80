# Loaded by mayhem/build.sh through -DCMAKE_PROJECT_INCLUDE; upstream's CMakeLists.txt is untouched.
# Defers to the end of the top-level directory, when every upstream target exists:
#   1. sources under vendor/ (the embedded interpreters and libraries) are built without any sanitizer
#      or SanCov flag, so the fuzzer explores TIC-80 rather than Lua and QuickJS;
#   2. one libFuzzer binary and one run-once -standalone binary per harness, linked against tic80core
#      with the project's own include paths and definitions.

if(NOT MAYHEM_FUZZ)
    return()
endif()

# Included after every project() call, vendored ones included: register once.
get_property(mayhem_registered GLOBAL PROPERTY MAYHEM_FUZZ_REGISTERED)
if(mayhem_registered)
    return()
endif()
set_property(GLOBAL PROPERTY MAYHEM_FUZZ_REGISTERED TRUE)

function(mayhem_collect_targets dir out)
    get_property(own DIRECTORY "${dir}" PROPERTY BUILDSYSTEM_TARGETS)
    get_property(subs DIRECTORY "${dir}" PROPERTY SUBDIRECTORIES)
    foreach(sub IN LISTS subs)
        mayhem_collect_targets("${sub}" subtargets)
        list(APPEND own ${subtargets})
    endforeach()
    set(${out} ${own} PARENT_SCOPE)
endfunction()

function(mayhem_fuzz_setup)
    mayhem_collect_targets("${CMAKE_SOURCE_DIR}" all_targets)
    foreach(t IN LISTS all_targets)
        get_target_property(type ${t} TYPE)
        if(NOT type MATCHES "LIBRARY|EXECUTABLE")
            continue()
        endif()
        get_target_property(sources ${t} SOURCES)
        foreach(src IN LISTS sources)
            if(src MATCHES "/vendor/")
                set_source_files_properties("${src}" TARGET_DIRECTORY ${t}
                    PROPERTIES COMPILE_OPTIONS "-fno-sanitize=all")
            endif()
        endforeach()
    endforeach()

    # core/io.c builds the 32-bit gamepad mask with `1 << i` for i up to 31 on every tick, which would
    # halt each run on its first frame. Only that check, only that file.
    set_source_files_properties("${CMAKE_SOURCE_DIR}/src/core/io.c" TARGET_DIRECTORY tic80core
        PROPERTIES COMPILE_OPTIONS "-fno-sanitize=shift-base")

    set(harness_dir "${CMAKE_SOURCE_DIR}/mayhem")
    foreach(name IN ITEMS fuzz_cart_load fuzz_project_load fuzz_script_run)
        set(sources "${harness_dir}/${name}.c")
        if(name STREQUAL fuzz_project_load)
            list(APPEND sources "${CMAKE_SOURCE_DIR}/src/studio/project.c")
        endif()

        add_executable(${name} ${sources} "${MAYHEM_LSAN_OFF_OBJ}")
        set_source_files_properties("${MAYHEM_LSAN_OFF_OBJ}" PROPERTIES EXTERNAL_OBJECT TRUE GENERATED TRUE)
        target_link_libraries(${name} PRIVATE tic80core)
        target_link_options(${name} PRIVATE ${MAYHEM_LIB_FUZZING_ENGINE})
        set_target_properties(${name} PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}")

        add_executable(${name}-standalone ${sources} "${MAYHEM_LSAN_OFF_OBJ}" "${MAYHEM_STANDALONE_MAIN_OBJ}")
        set_source_files_properties("${MAYHEM_STANDALONE_MAIN_OBJ}" PROPERTIES EXTERNAL_OBJECT TRUE GENERATED TRUE)
        target_link_libraries(${name}-standalone PRIVATE tic80core)
        set_target_properties(${name}-standalone PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}")
    endforeach()
endfunction()

cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL mayhem_fuzz_setup)
