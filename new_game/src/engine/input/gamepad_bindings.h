#ifndef ENGINE_INPUT_GAMEPAD_BINDINGS_H
#define ENGINE_INPUT_GAMEPAD_BINDINGS_H

enum GamepadControlsPreset {
    GAMEPAD_CONTROLS_OPENCHAOS = 0,
    GAMEPAD_CONTROLS_HANDHELD = 1,
};

void gamepad_bindings_init();
int gamepad_controls_preset();
void gamepad_controls_set_preset(int preset);

int gamepad_bind_jump();
int gamepad_bind_sprint();
int gamepad_bind_stealth();
int gamepad_bind_use();
int gamepad_bind_kick();
int gamepad_bind_punch_button();
int gamepad_bind_aim();
int gamepad_bind_inventory();
int gamepad_bind_start();
int gamepad_bind_car_siren();

#endif // ENGINE_INPUT_GAMEPAD_BINDINGS_H
