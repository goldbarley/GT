# Combat Presentation

## Playback contract

- Board coordinates use the selected map's rows and columns. Terrain textures follow the map theme.
- Center each fighter from its resting visible pixels once per perspective. Animated bounds must not change its tile anchor.
- Movement finishes before the strike. Offensive clips map their authored `impact` time to 58% of the battle tick; damage numbers, health changes, and hit reactions appear at that point.
- Preserve anticipation, a quick strike, a brief contact hold, and recovery. Defensive poses establish earlier. Do not truncate a clip before its effects land: Meteorite needs its complete authored timeline.
- Spell destinations stay in board coordinates while the camera pans. Clip large screen-space effects to the arena; avoid dimming the interface.

## Knight repairs

The front uses complete source pieces. The right view now includes torso backing copied from the original body asset, with its own scene region, underneath the moving arm. The back shoulder pivots inward to maintain overlap during swings; its body region excludes stray pixels below the boots. Keep scene definitions and `pieces.json` synchronized.

The left view still has a small authored sword and a largely combined body/shield/cape. Full independent arm, cape, and shield motion in every perspective requires additional separated artwork. Do not promise equivalent articulation across those rigs.

## Review captures

`--capture-menu` includes `/tmp/premove-knight-poses.png` and `/tmp/premove-attack-impact.png`. These are visual previews, not gameplay or LAN assertions. Review all directions during windup, contact, recovery, and walking; then review simultaneous attacks in an actual match.

## Design references

- [Animation principles for games](https://www.gamedeveloper.com/production/the-12-principles-of-animation-in-video-games): anticipation, readable staging, and follow-through.
- [Riot's clarity guidance](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/): preserve silhouettes and match effects to gameplay importance.
- [Turn-based RPG combat design](https://www.gamedeveloper.com/design/12-ways-to-improve-turn-based-rpg-combat-systems): make terrain and tactical choices readable.
