#include "engine/input/gamepad_bindings.h"

#include "engine/io/oc_config.h"
#include "engine/io/user_data.h"
#include "game/action_map/input_codes.h"

#include <nlohmann/json.hpp>

#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>

using json = nlohmann::json;
namespace fs = std::filesystem;

namespace {

struct GamepadBindings {
    int jump;
    int sprint;
    int stealth;
    int use;
    int kick;
    int punch_button;
    int punch_trigger;
    int aim;
    int inventory;
    int start;
    int car_siren;
    int car_accelerate;
    int car_brake;
    int car_reverse;
};

int s_preset = GAMEPAD_CONTROLS_OPENCHAOS;
GamepadBindings s_openchaos;
GamepadBindings s_handheld;
GamepadBindings s_custom;

int clamp_preset(int preset)
{
    if (preset < GAMEPAD_CONTROLS_OPENCHAOS || preset > GAMEPAD_CONTROLS_CUSTOM)
        return GAMEPAD_CONTROLS_OPENCHAOS;
    return preset;
}

GamepadBindings make_openchaos_bindings()
{
    return {
        GBTN_SOUTH,
        GBTN_EAST,
        GBTN_NORTH,
        GBTN_WEST,
        GBTN_R1,
        -1,
        GTRIG_R2,
        GBTN_L1,
        GBTN_R3,
        GBTN_START,
        GBTN_NORTH,
        GBTN_R2_DIGITAL,
        GBTN_L1,
        GBTN_L2_DIGITAL,
    };
}

GamepadBindings make_handheld_bindings()
{
    return {
        GBTN_SOUTH,
        GBTN_EAST,
        GBTN_L3,
        GBTN_R1,
        GBTN_NORTH,
        GBTN_WEST,
        GTRIG_R2,
        GBTN_L1,
        GBTN_R3,
        GBTN_START,
        GBTN_NORTH,
        GBTN_R2_DIGITAL,
        GBTN_L1,
        GBTN_L2_DIGITAL,
    };
}

const GamepadBindings& active_bindings()
{
    switch (s_preset) {
    case GAMEPAD_CONTROLS_HANDHELD:
        return s_handheld;
    case GAMEPAD_CONTROLS_CUSTOM:
        return s_custom;
    case GAMEPAD_CONTROLS_OPENCHAOS:
    default:
        return s_openchaos;
    }
}

std::string normalise_name(const std::string& in)
{
    std::string out;
    out.reserve(in.size());
    for (unsigned char c : in) {
        if (c == '_' || c == '-' || std::isspace(c))
            continue;
        out.push_back((char)std::tolower(c));
    }
    return out;
}

int parse_button_name(const std::string& name)
{
    const std::string n = normalise_name(name);
    if (n.empty() || n == "none" || n == "unbound")
        return -1;
    if (n == "south" || n == "a" || n == "cross")
        return GBTN_SOUTH;
    if (n == "east" || n == "b" || n == "circle")
        return GBTN_EAST;
    if (n == "west" || n == "x" || n == "square")
        return GBTN_WEST;
    if (n == "north" || n == "y" || n == "triangle")
        return GBTN_NORTH;
    if (n == "select" || n == "back" || n == "view")
        return GBTN_SELECT;
    if (n == "guide")
        return GBTN_GUIDE;
    if (n == "start" || n == "menu" || n == "options")
        return GBTN_START;
    if (n == "l3" || n == "leftstick" || n == "lsb")
        return GBTN_L3;
    if (n == "r3" || n == "rightstick" || n == "rsb")
        return GBTN_R3;
    if (n == "l1" || n == "lb" || n == "leftbumper")
        return GBTN_L1;
    if (n == "r1" || n == "rb" || n == "rightbumper")
        return GBTN_R1;
    if (n == "dpadup")
        return GBTN_DPAD_UP;
    if (n == "dpaddown")
        return GBTN_DPAD_DOWN;
    if (n == "dpadleft")
        return GBTN_DPAD_LEFT;
    if (n == "dpadright")
        return GBTN_DPAD_RIGHT;
    if (n == "l2" || n == "lt" || n == "lefttrigger")
        return GBTN_L2_DIGITAL;
    if (n == "r2" || n == "rt" || n == "righttrigger")
        return GBTN_R2_DIGITAL;

    fprintf(stderr, "gamepad_bindings: unknown button name '%s'\n", name.c_str());
    return -2;
}

int parse_trigger_name(const std::string& name)
{
    const std::string n = normalise_name(name);
    if (n.empty() || n == "none" || n == "unbound")
        return -1;
    if (n == "l2" || n == "lt" || n == "lefttrigger")
        return GTRIG_L2;
    if (n == "r2" || n == "rt" || n == "righttrigger")
        return GTRIG_R2;

    fprintf(stderr, "gamepad_bindings: unknown trigger name '%s'\n", name.c_str());
    return -2;
}

bool read_button_value(const json& value, int& out)
{
    if (value.is_string()) {
        int parsed = parse_button_name(value.get<std::string>());
        if (parsed == -2)
            return false;
        out = parsed;
        return true;
    }
    if (value.is_array()) {
        for (const auto& item : value) {
            if (!item.is_string())
                continue;
            int parsed = parse_button_name(item.get<std::string>());
            if (parsed != -2) {
                out = parsed;
                return true;
            }
        }
    }
    return false;
}

bool read_trigger_value(const json& value, int& out)
{
    if (!value.is_string())
        return false;
    int parsed = parse_trigger_name(value.get<std::string>());
    if (parsed == -2)
        return false;
    out = parsed;
    return true;
}

void apply_binding(json::const_iterator bindings_end, const json& bindings, const char* key, int& out)
{
    auto it = bindings.find(key);
    if (it == bindings_end)
        return;
    int parsed = out;
    if (read_button_value(*it, parsed))
        out = parsed;
    else
        fprintf(stderr, "gamepad_bindings: invalid value for '%s'\n", key);
}

void apply_trigger_binding(json::const_iterator bindings_end, const json& bindings, const char* key, int& out)
{
    auto it = bindings.find(key);
    if (it == bindings_end)
        return;
    int parsed = out;
    if (read_trigger_value(*it, parsed))
        out = parsed;
    else
        fprintf(stderr, "gamepad_bindings: invalid value for '%s'\n", key);
}

void apply_alias_binding(json::const_iterator bindings_end, const json& bindings, const char* key, const char* alias, int& out)
{
    auto it = bindings.find(key);
    if (it == bindings_end)
        it = bindings.find(alias);
    if (it == bindings_end)
        return;
    int parsed = out;
    if (read_button_value(*it, parsed))
        out = parsed;
    else
        fprintf(stderr, "gamepad_bindings: invalid value for '%s'\n", key);
}

std::string custom_bindings_path()
{
    if (const char* env = std::getenv("OPENCHAOS_GAMEPAD_BINDINGS")) {
        if (env[0])
            return env;
    }

    const char* filename = "OpenChaos.gamepad.json";
    const char* root = USERDATA_root();
    if (root && root[0]) {
        fs::path user_path = fs::path(root) / filename;
        if (fs::exists(user_path))
            return user_path.string();
    }
    return filename;
}

void load_custom_bindings()
{
    s_custom = s_handheld;

    const std::string path = custom_bindings_path();
    if (!fs::exists(path)) {
        if (std::getenv("OPENCHAOS_GAMEPAD_BINDINGS"))
            fprintf(stderr, "gamepad_bindings: custom binding file not found: %s\n", path.c_str());
        return;
    }

    try {
        std::ifstream f(path);
        json doc = json::parse(f);
        if (!doc.is_object()) {
            fprintf(stderr, "gamepad_bindings: expected object in %s\n", path.c_str());
            return;
        }
        const json* bindings = &doc;
        auto it = doc.find("bindings");
        if (it != doc.end() && it->is_object())
            bindings = &*it;
        if (!bindings->is_object()) {
            fprintf(stderr, "gamepad_bindings: expected object in %s\n", path.c_str());
            return;
        }

        const auto end = bindings->end();
        apply_binding(end, *bindings, "jump", s_custom.jump);
        apply_binding(end, *bindings, "sprint", s_custom.sprint);
        apply_binding(end, *bindings, "stealth", s_custom.stealth);
        apply_alias_binding(end, *bindings, "use", "interact", s_custom.use);
        apply_binding(end, *bindings, "kick", s_custom.kick);
        apply_alias_binding(end, *bindings, "punch", "shoot", s_custom.punch_button);
        apply_trigger_binding(end, *bindings, "punch_trigger", s_custom.punch_trigger);
        apply_binding(end, *bindings, "aim", s_custom.aim);
        apply_binding(end, *bindings, "inventory", s_custom.inventory);
        apply_alias_binding(end, *bindings, "start", "pause", s_custom.start);
        apply_alias_binding(end, *bindings, "car_siren", "siren", s_custom.car_siren);
        apply_alias_binding(end, *bindings, "car_accelerate", "accelerate", s_custom.car_accelerate);
        apply_alias_binding(end, *bindings, "car_brake", "brake", s_custom.car_brake);
        apply_alias_binding(end, *bindings, "car_reverse", "reverse", s_custom.car_reverse);
    } catch (const std::exception& e) {
        fprintf(stderr, "gamepad_bindings: could not parse %s: %s\n", path.c_str(), e.what());
    }
}

} // namespace

void gamepad_bindings_init()
{
    s_openchaos = make_openchaos_bindings();
    s_handheld = make_handheld_bindings();
    load_custom_bindings();
    s_preset = clamp_preset(OC_CONFIG_get_int("gamepad", "controls_preset", GAMEPAD_CONTROLS_OPENCHAOS, GAMEPAD_CONTROLS_OPENCHAOS, GAMEPAD_CONTROLS_CUSTOM));
}

int gamepad_controls_preset()
{
    return s_preset;
}

void gamepad_controls_set_preset(int preset)
{
    s_preset = clamp_preset(preset);
    if (s_preset == GAMEPAD_CONTROLS_CUSTOM)
        load_custom_bindings();
    OC_CONFIG_set_int("gamepad", "controls_preset", s_preset);
}

int gamepad_bind_jump()
{
    return active_bindings().jump;
}

int gamepad_bind_sprint()
{
    return active_bindings().sprint;
}

int gamepad_bind_stealth()
{
    return active_bindings().stealth;
}

int gamepad_bind_use()
{
    return active_bindings().use;
}

int gamepad_bind_kick()
{
    return active_bindings().kick;
}

int gamepad_bind_punch_button()
{
    return active_bindings().punch_button;
}

int gamepad_bind_punch_trigger()
{
    return active_bindings().punch_trigger;
}

int gamepad_bind_aim()
{
    return active_bindings().aim;
}

int gamepad_bind_inventory()
{
    return active_bindings().inventory;
}

int gamepad_bind_start()
{
    return active_bindings().start;
}

int gamepad_bind_car_siren()
{
    return active_bindings().car_siren;
}

int gamepad_bind_car_accelerate()
{
    return active_bindings().car_accelerate;
}

int gamepad_bind_car_brake()
{
    return active_bindings().car_brake;
}

int gamepad_bind_car_reverse()
{
    return active_bindings().car_reverse;
}
