set(GAME_MODULE_SOURCES
    GameModule.cpp
    Systems/SwarmSteeringSystem.cpp
    Systems/CombatEventSystem.cpp
    Systems/HealthBarRenderSystem.cpp
)

octarine_library(octarine_game_module ${GAME_MODULE_SOURCES})
target_include_directories(octarine_game_module PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_definitions(octarine_game_module PUBLIC OCTARINE_HAS_GAME_MODULE)
target_link_libraries(octarine_game_module PUBLIC
    octarine_core
    octarine_assets
    octarine_renderer
    octarine_systems
    octarine_lua
)
if (OCTARINE_WITH_IMGUI)
    target_link_libraries(octarine_game_module PUBLIC imgui::imgui)
endif ()
