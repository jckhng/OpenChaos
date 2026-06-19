#include "engine/input/gamepad_bindings.h"

#include "engine/io/oc_config.h"
#include "game/action_map/input_codes.h"

namespace {

int s_preset = GAMEPAD_CONTROLS_OPENCHAOS;

int clamp_preset(int preset)
{
    if (preset < GAMEPAD_CONTROLS_OPENCHAOS || preset > GAMEPAD_CONTROLS_HANDHELD)
        return GAMEPAD_CONTROLS_OPENCHAOS;
    return preset;
}

bool handheld()
{
    return s_preset == GAMEPAD_CONTROLS_HANDHELD;
}

} // namespace

void gamepad_bindings_init()
{
    s_preset = clamp_preset(OC_CONFIG_get_int("gamepad", "controls_preset", GAMEPAD_CONTROLS_OPENCHAOS, GAMEPAD_CONTROLS_OPENCHAOS, GAMEPAD_CONTROLS_HANDHELD));
}

int gamepad_controls_preset()
{
    return s_preset;
}

void gamepad_controls_set_preset(int preset)
{
    s_preset = clamp_preset(preset);
    OC_CONFIG_set_int("gamepad", "controls_preset", s_preset);
}

int gamepad_bind_jump()
{
    return GBTN_SOUTH;
}

int gamepad_bind_sprint()
{
    return GBTN_EAST;
}

int gamepad_bind_stealth()
{
    return handheld() ? GBTN_L3 : GBTN_NORTH;
}

int gamepad_bind_use()
{
    return handheld() ? GBTN_R1 : GBTN_WEST;
}

int gamepad_bind_kick()
{
    return handheld() ? GBTN_NORTH : GBTN_R1;
}

int gamepad_bind_punch_button()
{
    return handheld() ? GBTN_WEST : -1;
}

int gamepad_bind_aim()
{
    return GBTN_L1;
}

int gamepad_bind_inventory()
{
    return GBTN_R3;
}

int gamepad_bind_start()
{
    return GBTN_START;
}

int gamepad_bind_car_siren()
{
    return GBTN_NORTH;
}
