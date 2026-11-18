octarine_add_test(OctarineShowcaseModuleTest ShowcaseModuleTest
        SOURCES ShowcaseModuleTest.cpp
        LIBS octarine_game_module octarine_engine
        INCLUDES "${CMAKE_SOURCE_DIR}/tests" "${CMAKE_CURRENT_SOURCE_DIR}/.."
)
