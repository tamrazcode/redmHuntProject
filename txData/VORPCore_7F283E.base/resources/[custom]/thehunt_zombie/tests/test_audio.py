"""Audio integration and sound mapping test."""
import os
import sys
from pathlib import Path
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[1]

# 1. Verify sound files on disk and in config.lua
original_sounds = [
    'Female-zombie-breathing-fast.mp3',
    'Women Zombie Groan - QuickSounds.com.mp3',
    'Zombie Attack Woman - QuickSounds.com.mp3',
    'Zombie Attack Woman 2 - QuickSounds.com.mp3',
    'Zombie Bellow Man - QuickSounds.com.mp3',
    'Zombie Bellow Man 2 - QuickSounds.com.mp3',
    'Zombie Bellow Man 3 - QuickSounds.com.mp3',
    'Zombie Bellow Woman - QuickSounds.com.mp3',
    'Zombie Bellow Woman 2 - QuickSounds.com.mp3',
    'Zombie Bellow Woman 3 - QuickSounds.com.mp3',
    'Zombie Bellow Woman 4 - QuickSounds.com.mp3',
    'Zombie Bellow Woman 5 - QuickSounds.com.mp3',
    'Zombie Calm - QuickSounds.com.mp3',
    'Zombie Hiss Man 2 - QuickSounds.com.mp3',
    'Zombie Rattle Man - QuickSounds.com.mp3',
    'Zombie Roar Woman - QuickSounds.com.mp3',
    '666herohero-monster-death-grunt-131480.mp3',
    'freesound_community-dying-monster-101276.mp3',
    'freesound_community-zombie-death.mp3',
    'freesound_community-zombie-die.mp3',
    'dragon-studio-zombie-dying-sound-357974.mp3',
    'freesound_community-zombie-moan-44932.mp3',
    'freesound_community-zombie-moaning-101369.mp3',
    'freesound_community-weird-zombie-moan-44938.mp3',
    'vilches86-zombie-15965.mp3',
    'Reanimated_Hoard.mp3',
    'Lurking_Undead_Attack.mp3',
    'Horrific_Clash.mp3',
    'Zombie_Rumble.mp3'
]
sound_files = {p.name for p in (root / 'sounds').glob('*.mp3')}
for sound in original_sounds:
    assert sound in sound_files, f"Sound file {sound} not found in sounds/"

config_text = (root / 'config.lua').read_text(encoding='utf-8')
for sound in original_sounds:
    assert sound in config_text, f"Sound file {sound} not found in config.lua"

print(f"PASS: All {len(original_sounds)} sound files exist on disk and are mapped in config.lua")

# 2. Verify NUI 3D audio handling via Playwright
with sync_playwright() as p:
    browser = p.chromium.launch(
        channel='msedge',
        headless=True,
        args=['--allow-file-access-from-files', '--autoplay-policy=no-user-gesture-required']
    )
    page = browser.new_page()
    errors = []
    console_logs = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.on('console', lambda m: console_logs.append(m.text))
    page.goto((root / 'html/index.html').as_uri())

    # Wait for initial buffer preloads
    page.wait_for_timeout(500)

    # Stress test: trigger 150 sounds from multiple zombies across all sound files and stages (including death)
    result = page.evaluate('''async () => {
        const soundList = [
            'female_breathing_fast.mp3',
            'women_zombie_groan.mp3',
            'zombie_attack_woman_1.mp3',
            'zombie_attack_woman_2.mp3',
            'zombie_bellow_man_1.mp3',
            'zombie_bellow_man_2.mp3',
            'zombie_bellow_man_3.mp3',
            'zombie_bellow_woman_1.mp3',
            'zombie_bellow_woman_2.mp3',
            'zombie_bellow_woman_3.mp3',
            'zombie_bellow_woman_4.mp3',
            'zombie_bellow_woman_5.mp3',
            'zombie_calm.mp3',
            'zombie_hiss_man_2.mp3',
            'zombie_rattle_man.mp3',
            'zombie_roar_woman.mp3',
            '666herohero-monster-death-grunt-131480.mp3',
            'freesound_community-dying-monster-101276.mp3',
            'freesound_community-zombie-death.mp3',
            'freesound_community-zombie-die.mp3',
            'dragon-studio-zombie-dying-sound-357974.mp3',
            'freesound_community-zombie-moan-44932.mp3',
            'freesound_community-zombie-moaning-101369.mp3',
            'freesound_community-weird-zombie-moan-44938.mp3',
            'vilches86-zombie-15965.mp3',
            'Reanimated_Hoard.mp3',
            'Lurking_Undead_Attack.mp3',
            'Horrific_Clash.mp3',
            'Zombie_Rumble.mp3'
        ];
        const stages = ['idle', 'alert', 'chase', 'attack', 'death'];

        let playedCount = 0;
        for (let i = 0; i < 150; i++) {
            const file = soundList[i % soundList.length];
            const stage = stages[i % stages.length];
            const zombieId = `z_${i % 25}`;
            const soundId = `snd_${i}`;

            window.postMessage({
                action: 'playZombieSound3D',
                soundId: soundId,
                zombieId: zombieId,
                file: file,
                x: (i % 10) - 5,
                y: (i % 8) - 4,
                z: 0.2,
                dist: 3.0 + (i % 25),
                maxRange: 65.0,
                stage: stage
            }, '*');
            playedCount++;

            if (i % 10 === 0) {
                window.postMessage({
                    action: 'updateZombieSounds3D',
                    updates: {
                        [soundId]: { x: 1.0, y: 2.0, z: 0.0, dist: 2.5 }
                    }
                }, '*');
            }
            if (stage === 'death') {
                window.postMessage({
                    action: 'stopZombieSound3D',
                    zombieId: zombieId,
                    preserveDeath: true
                }, '*');
            }
        }
        await new Promise(r => setTimeout(r, 600));
        return { playedCount, activeCount: window.activeSounds ? window.activeSounds.size : 0 };
    }''')
    page.wait_for_timeout(300)

    # Verify no WebMediaPlayer limit warnings/errors occurred
    wmp_errors = [m for m in console_logs if 'WebMediaPlayer' in m]
    assert not wmp_errors, f"Detected WebMediaPlayer limit error in console: {wmp_errors}"
    assert not errors, f"JS errors in 3D sound processing: {errors}"
    print(f"PASS: Triggered {result.get('playedCount', 0)} sounds across 25 zombies without WebMediaPlayer cap hit or JS errors")

    browser.close()

print("PASS: NUI 3D sound messages (play, update, stop) executed without errors")
