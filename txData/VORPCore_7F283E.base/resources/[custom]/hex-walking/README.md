# hex-walking RedM


# Enhanced Movement Controller

A customizable movement control system for RedM with auto-run feature and speed controls.

## Features

- **Customizable Movement Speeds**
  - Adjustable walking/running speeds
  - Quick speed presets (min/max)
  - Smooth speed transitions

- **Auto-Run System**
  - Charge-based activation
  - Camera-following movement
  - Lock camera option
  - Auto-stop on player state changes

- **Visual Feedback**
  - Speed indicator display
  - Auto-run charging progress bar
  - Color-coded speed levels

## Controls

- **Speed Controls** (while holding Left Shift)
  - `Up Arrow` - Increase speed
  - `Down Arrow` - Decrease speed
  - `R` - Reset to default speed
  - `Right Arrow` - Set maximum speed
  - `Left Arrow` - Set minimum speed

- **Auto-Run**
  - `G` (hold while sprinting) - Activate auto-run
  - `X` - Cancel auto-run
  - `C` (hold) - Lock camera direction during auto-run

## Configuration

All settings can be adjusted in the Config section at the top of the file:

```lua
Config = {
    Movement = {
        MIN_SPEED = 0.2,
        MAX_SPEED = 3.0,
        SPEED_INCREMENT = 0.1,
        -- ...
    },
    -- ...
}
```

## Installation

1. Create a new resource folder in your server's resources directory
2. Copy the script file into the folder
3. Add `ensure your-resource-name` to your server.cfg

## Requirements

- RedM server/client
- Updated FiveM/RedM natives

## Notes

- Auto-run will automatically stop if the player becomes incapacitated
- Speed settings persist until manually changed or auto-run is activated
- Visual indicators will hide after a short delay when not in use
