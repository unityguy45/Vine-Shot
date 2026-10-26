Vine shot
==============================

A top-down pixel-art stealth game made in **Godot 4.6**. You're a hooded archer defending the forest. Woodcutter camps keep appearing and cutting it down. Sneak through the bushes, take them out before they see you, and hide the bodies before their friends find them.

<img width="413" height="232" alt="Screenshot 2026-10-26 112405" src="https://github.com/user-attachments/assets/d06787b0-db39-42f5-8daa-e5947d6388f1" />


How to play
-----------

Woodcutter camps appear in the forest one after another and start chopping trees. Clear all 4 camps before a quarter of the forest is gone.

| Key | Action |
|---|---|
| W A S D | Move |
| Shift | Sneak (slow and silent) |
| Space | Dash (you can't be hit while dashing) |
| Left click | Shoot an arrow at the mouse |
| G | Grab or drop a body |
| R | Play again (on the end screen) |
| Esc | Back to the title screen |


Features
--------

**Stealth**
- **Bushes** hide you completely, and you slowly heal in them while nobody is chasing you.
- **Detection meter:** a bar fills over an enemy's head while they can see you. It fills faster up close and slower while you sneak. Half full, they come to check ("?"); full, they spot you ("!") and call for help.
- **Sound matters:** running is loud and sneaking is silent. Missed arrows make a noise that draws enemies over.
- **Sneak attacks** do 3x damage. Woodcutters drop in one shot; guards need two.

**Bodies and alerts**
- Fallen enemies stay where they drop. If another enemy spots a body, the whole camp goes **on guard**: they see further and wider, notice you faster, search harder, and call in a reinforcement guard.
- **Drag bodies into bushes** with G so they're never found.
- Camps calm down after a while, but never fully relax again.

**Escalation**
- Each new camp is bigger than the last, up to 3 woodcutters and 3 guards.
- Woodcutters who spot you throw axes. Dash through them.
- Get spotted or have bodies found too often and new camps arrive already suspicious.

**Feel**
- Sound effects for the bow, hits, alerts, axes, chopping, falling trees and camp horns.
- Screen shake, hit flashes and a short freeze-frame on silent takedowns.
- An end screen with your takedowns, times spotted, bodies found and time, plus a rank from **S (Ghost of the forest)** to **C (Brawler)**.


Running it
----------

1. Install [Godot 4.6](https://godotengine.org/download).
2. Clone this repo.
3. In the Godot Project Manager, click **Import** and pick the `project.godot` file in this folder.
4. Press **F5** to play.


Project layout
--------------

```
scenes/
  main.tscn            the level
  player/              the archer
  enemies/             woodcutter, guard
  world/               trees, bushes, rocks, camp
  combat/              arrow, thrown axe
  ui/                  HUD, title screen
scripts/               one script per scene, plus autoload/game_state.gd
resources/             sprite frames, tilesets, UI theme
art/                   sprites, tiles and sound effects
```

The main scene:

```
Main
  GameManager          runs the game: camps, win and lose, messages
  Level
    Ground, Decor      tile layers
    Bounds             invisible walls around the map
  World                everything that moves, y-sorted
    Player
    Trees, Bushes, Rocks
    Camps              camps are added here during play
  CampSpots            where camps can appear
  HUD
```

`GameState` (an autoload) handles sounds, screen shake, stats and noises that enemies can hear.


Tuning
------

Most of the balance can be changed in the Inspector without touching code:

| Node | Values |
|---|---|
| Main > GameManager | `max_camps`, `camp_interval`, `lose_below_forest` |
| woodcutter.tscn, guard.tscn | `notice_speed`, `vision_range`, `vision_angle`, `hearing_range`, `max_health` |
| woodcutter.tscn | `throw_cooldown`, `throw_range` |
| camp.tscn | `on_guard_time` |
| player.tscn | `max_health`, `bush_heal`, `sneak_speed`, `shot_cooldown` |


Credits
-------

Made with [Godot Engine](https://godotengine.org). The pixel art and sound effects were made for this game.
