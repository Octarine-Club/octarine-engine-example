#pragma once

#include <cstdint>

// POD steering parameters for parallel C++ swarm agents.
struct SwarmAgentComponent {
  float target_x = 640.0F;
  float target_y = 360.0F;
  float max_speed = 160.0F;
  float orbit_radius = 90.0F;
  float phase = 0.0F;
  std::uint8_t team = 1;
};
