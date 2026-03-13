cmake_minimum_required(VERSION 3.20)

foreach(v COMPILER CLANG SRC ROOT OUT_LL OUT_CLANG_BIN OUT_C2LL_BIN)
  if(NOT DEFINED ${v} OR "${${v}}" STREQUAL "")
    message(FATAL_ERROR "Missing required -D${v}=...")
  endif()
endforeach()

if(NOT DEFINED CASE_TIMEOUT_SEC OR "${CASE_TIMEOUT_SEC}" STREQUAL "")
  set(CASE_TIMEOUT_SEC 60)
endif()
if(NOT DEFINED RUN_MEM_MB OR "${RUN_MEM_MB}" STREQUAL "")
  set(RUN_MEM_MB 0)
endif()
if(NOT DEFINED RUN_CPU_SEC OR "${RUN_CPU_SEC}" STREQUAL "")
  set(RUN_CPU_SEC 0)
endif()

set(RUN_WRAPPER_CMD)
if((RUN_MEM_MB GREATER 0) OR (RUN_CPU_SEC GREATER 0))
  find_program(BASH_EXECUTABLE NAMES bash)
  if(BASH_EXECUTABLE)
    set(_sandbox_prefix "")
    if(RUN_MEM_MB GREATER 0)
      math(EXPR RUN_MEM_KB "${RUN_MEM_MB} * 1024")
      string(APPEND _sandbox_prefix "ulimit -v ${RUN_MEM_KB} >/dev/null 2>&1; ")
    endif()
    if(RUN_CPU_SEC GREATER 0)
      string(APPEND _sandbox_prefix "ulimit -t ${RUN_CPU_SEC} >/dev/null 2>&1; ")
    endif()
    set(_sandbox_cmd "${_sandbox_prefix}exec \"\$@\"")
    set(RUN_WRAPPER_CMD "${BASH_EXECUTABLE}" "-lc" "${_sandbox_cmd}" "sandbox")
  else()
    message(WARNING
      "Requested RUN_MEM_MB/RUN_CPU_SEC but bash not found; running without ulimit sandbox")
  endif()
endif()

get_filename_component(out_ll_dir "${OUT_LL}" DIRECTORY)
get_filename_component(out_clang_dir "${OUT_CLANG_BIN}" DIRECTORY)
get_filename_component(out_c2ll_dir "${OUT_C2LL_BIN}" DIRECTORY)
file(MAKE_DIRECTORY "${out_ll_dir}")
file(MAKE_DIRECTORY "${out_clang_dir}")
file(MAKE_DIRECTORY "${out_c2ll_dir}")

execute_process(
  COMMAND "${CLANG}" -std=gnu89 -w -I "${ROOT}" "${SRC}" -o "${OUT_CLANG_BIN}"
  WORKING_DIRECTORY "${ROOT}"
  TIMEOUT "${CASE_TIMEOUT_SEC}"
  RESULT_VARIABLE clang_build_rc
  OUTPUT_VARIABLE clang_build_out
  ERROR_VARIABLE clang_build_err
)
if(clang_build_rc MATCHES "timeout")
  message(FATAL_ERROR "[CLANG_COMPILE_TIMEOUT] ${SRC} exceeded ${CASE_TIMEOUT_SEC}s")
endif()
if(NOT clang_build_rc EQUAL 0)
  message(FATAL_ERROR "[CLANG_COMPILE_FAIL] ${SRC}\n${clang_build_err}")
endif()

if(RUN_WRAPPER_CMD)
  execute_process(
    COMMAND ${RUN_WRAPPER_CMD} "${OUT_CLANG_BIN}"
    WORKING_DIRECTORY "${ROOT}"
    TIMEOUT "${CASE_TIMEOUT_SEC}"
    RESULT_VARIABLE clang_run_rc
    OUTPUT_VARIABLE clang_run_out
    ERROR_VARIABLE clang_run_err
  )
else()
  execute_process(
    COMMAND "${OUT_CLANG_BIN}"
    WORKING_DIRECTORY "${ROOT}"
    TIMEOUT "${CASE_TIMEOUT_SEC}"
    RESULT_VARIABLE clang_run_rc
    OUTPUT_VARIABLE clang_run_out
    ERROR_VARIABLE clang_run_err
  )
endif()
if(clang_run_rc MATCHES "timeout")
  message(FATAL_ERROR "[CLANG_RUN_TIMEOUT] ${SRC} exceeded ${CASE_TIMEOUT_SEC}s")
endif()
set(clang_all_out "${clang_run_out}${clang_run_err}")

execute_process(
  COMMAND "${COMPILER}" "${SRC}" -o "${OUT_LL}"
  WORKING_DIRECTORY "${ROOT}"
  TIMEOUT "${CASE_TIMEOUT_SEC}"
  RESULT_VARIABLE front_rc
  OUTPUT_VARIABLE front_out
  ERROR_VARIABLE front_err
)
if(front_rc MATCHES "timeout")
  message(FATAL_ERROR "[FRONTEND_TIMEOUT] ${SRC} exceeded ${CASE_TIMEOUT_SEC}s")
endif()
if(NOT front_rc EQUAL 0)
  message(FATAL_ERROR "[FRONTEND_FAIL] ${SRC}\n${front_err}")
endif()

execute_process(
  COMMAND "${CLANG}" "${OUT_LL}" -o "${OUT_C2LL_BIN}"
  WORKING_DIRECTORY "${ROOT}"
  TIMEOUT "${CASE_TIMEOUT_SEC}"
  RESULT_VARIABLE back_rc
  OUTPUT_VARIABLE back_out
  ERROR_VARIABLE back_err
)
if(back_rc MATCHES "timeout")
  message(FATAL_ERROR "[BACKEND_TIMEOUT] ${SRC} exceeded ${CASE_TIMEOUT_SEC}s")
endif()
if(NOT back_rc EQUAL 0)
  message(FATAL_ERROR "[BACKEND_FAIL] ${SRC}\n${back_err}")
endif()

if(RUN_WRAPPER_CMD)
  execute_process(
    COMMAND ${RUN_WRAPPER_CMD} "${OUT_C2LL_BIN}"
    WORKING_DIRECTORY "${ROOT}"
    TIMEOUT "${CASE_TIMEOUT_SEC}"
    RESULT_VARIABLE c2ll_run_rc
    OUTPUT_VARIABLE c2ll_run_out
    ERROR_VARIABLE c2ll_run_err
  )
else()
  execute_process(
    COMMAND "${OUT_C2LL_BIN}"
    WORKING_DIRECTORY "${ROOT}"
    TIMEOUT "${CASE_TIMEOUT_SEC}"
    RESULT_VARIABLE c2ll_run_rc
    OUTPUT_VARIABLE c2ll_run_out
    ERROR_VARIABLE c2ll_run_err
  )
endif()
if(c2ll_run_rc MATCHES "timeout")
  message(FATAL_ERROR "[C2LL_RUN_TIMEOUT] ${SRC} exceeded ${CASE_TIMEOUT_SEC}s")
endif()
set(c2ll_all_out "${c2ll_run_out}${c2ll_run_err}")

if(NOT c2ll_run_rc EQUAL clang_run_rc OR NOT c2ll_all_out STREQUAL clang_all_out)
  message(FATAL_ERROR
    "[RUNTIME_FAIL] ${SRC}\n"
    "clang_exit=${clang_run_rc} c2ll_exit=${c2ll_run_rc}\n"
    "clang_out:\n${clang_all_out}\n"
    "c2ll_out:\n${c2ll_all_out}")
endif()

message(STATUS "[PASS] ${SRC}")
