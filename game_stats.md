# Game Scaling Stats — Hard Mode Redesign (v2)

Goal: turn a gentle linear grind into a real challenge curve, with 5x more enemies on screen, steeper HP scaling, boss-wave spikes, and a few systems that give players actual decisions to make instead of just "upgrade turret, repeat."

---

## 1. Enemy Spawn Count Per Wave (NEW — this didn't exist in v1)

Your original sheet only defined per-enemy stats, not how many spawn. Here's a baseline curve plus the 5x version you asked for.

| Wave | Old-style baseline count | **New count (x5)** |
|------|---------------------------|---------------------|
| 1    | 3                         | **15**               |
| 2    | 4                         | **20**               |
| 3    | 4                         | **20**               |
| 4    | 5                         | **25**               |
| 5    | 6                         | **30**               |
| 6    | 6                         | **30**               |
| 7    | 7                         | **35**               |
| 8    | 7                         | **35**               |
| 9    | 8                         | **40**               |
| 10   | 9                         | **45**               |

Formula: `spawn_count(wave) = floor(3 + wave * 0.6) * 5`

⚠️ Balance note: 5x spawns with the *old* per-wave spawn timing will feel like a wall. Pair this with a faster spawn interval curve (see §5) or players will get overwhelmed by sheer density rather than difficulty — that reads as unfair, not hard.

---

## 2. Enemy Health & Coins — Steeper Curve + Boss Waves

Changes from v1:
- HP growth raised from **+15%/wave → +22%/wave** (compounding)
- Every **5th wave is a Boss Wave**: HP gets an extra **x1.35** spike, then eases off the wave after (gives players a breather + a clear "this one's the hard one" signal)
- Coin bonus now increases every **2 waves** instead of every 3, to keep the economy from falling behind the harder curve

| Wave | UFO-A HP | UFO-A Coins | UFO-B HP | UFO-B Coins | UFO-C HP | UFO-C Coins | UFO-D HP | UFO-D Coins | Boss Wave? |
|------|---------:|------------:|---------:|------------:|---------:|------------:|---------:|------------:|:----------:|
| 1    | 80       | 2           | 120      | 4           | 180      | 7           | 260      | 10          |            |
| 2    | 98       | 2           | 146      | 4           | 220      | 7           | 317      | 10          |            |
| 3    | 119      | 3           | 179      | 5           | 268      | 8           | 387      | 11          |            |
| 4    | 145      | 3           | 218      | 5           | 327      | 8           | 472      | 11          |            |
| 5    | 239      | 4           | 359      | 6           | 538      | 9           | 778      | 12          | 🔥 Boss    |
| 6    | 216      | 4           | 324      | 6           | 486      | 9           | 703      | 12          |            |
| 7    | 264      | 5           | 396      | 7           | 594      | 10          | 857      | 13          |            |
| 8    | 322      | 5           | 483      | 7           | 724      | 10          | 1046     | 13          |            |
| 9    | 393      | 6           | 589      | 8           | 883      | 11          | 1276     | 14          |            |
| 10   | 647      | 6           | 970      | 8           | 1455     | 11          | 2102     | 14          | 🔥 Boss    |
| 11   | 584      | 7           | 877      | 9           | 1315     | 12          | 1899     | 15          |            |
| 12   | 713      | 7           | 1069     | 9           | 1604     | 12          | 2317     | 15          |            |
| 13   | 870      | 8           | 1305     | 10          | 1957     | 13          | 2827     | 16          |            |
| 14   | 1061     | 8           | 1592     | 10          | 2388     | 13          | 3449     | 16          |            |
| 15   | 1748     | 9           | 2622     | 11          | 3932     | 14          | 5680     | 17          | 🔥 Boss    |

Formula: `hp(wave) = base_hp * 1.22^(wave-1) * (1.35 if wave % 5 == 0 else 1)`
`coins(wave) = base_coins + floor((wave-1) / 2)`

---

## 3. Turret Damage & Cost — Steeper Growth + Real Cost Curve

v1 only had a damage curve with no cost attached — that means upgrading is always correct with no tradeoff. Adding a cost curve makes "upgrade now vs. save for a second turret" an actual decision.

| Level | Damage (+45%/lvl) | Upgrade Cost (x1.55/lvl) |
|-------|-------------------:|---------------------------:|
| 1     | 35.0                | 100                         |
| 2     | 50.8                | 155                         |
| 3     | 73.6                | 240                         |
| 4     | 106.7               | 372                         |
| 5     | 154.7               | 577                         |
| 6     | 224.3               | 895                         |
| 7     | 325.3               | 1,387                       |
| 8     | 471.7               | 2,149                       |
| 9     | 683.9               | 3,332                       |
| 10    | 991.7               | 5,164                       |

Formula: `damage(lvl) = 35 * 1.45^(lvl-1)`
`cost(lvl) = 100 * 1.55^(lvl-1)`

---

## 4. New Enemy Variants (adds decision-making, not just bigger numbers)

Flat HP scaling alone gets boring — players just build one strong turret type and never adapt. A few archetypes fix that:

- **Shielded (UFO-S):** immune to the first hit each wave-cycle, or takes reduced damage from single-target turrets — forces AoE/splash investment.
- **Swarm (UFO-Sw):** very low HP, very high count, fast — punishes single-target snipers, rewards AoE.
- **Regenerator (UFO-R):** heals a % of max HP per second if not hit for 2+ seconds — punishes weak/slow DPS, rewards sustained fire.
- **Armored (UFO-Ar):** flat damage reduction per hit (not %) — punishes low-damage-high-fire-rate turrets, rewards heavy hitters.
- **Runner (UFO-Rn):** 2x move speed, low HP — tests slow/reaction-based turrets (ice/slow towers become valuable).

Each variant should show up starting at different wave thresholds (e.g., Swarm from wave 3, Armored from wave 6, Regenerator from wave 9) so the toolkit players need keeps expanding.

---

## 5. Spawn Timing / Density Curve

To make the 5x enemy count feel intense rather than just "wait longer":

`spawn_interval(wave) = max(0.15, 0.6 - wave * 0.02)` seconds between spawns

This tightens pacing as waves increase, so later waves feel genuinely frantic instead of just numerically bigger.

---

## 6. Other Systems Worth Adding

- **Enrage timer:** if a wave takes too long to clear, remaining enemies get a damage/speed buff — discourages turtling with one overpowered turret.
- **Turret cap / grid limits:** a maximum number of turret slots forces build diversity instead of "just spam turrets."
- **Elite mutators (roguelike-style):** every 5 waves, randomly apply a modifier to that wave (e.g., "+30% speed," "immune to slow," "splits on death") — keeps repeat playthroughs from feeling identical.
- **Path-based scaling:** on multi-path maps, scale enemy stats per-path independently so players can't just wall off the easy lane.
- **Overkill/splash falloff tuning:** if you add AoE turrets, make sure splash damage doesn't trivialize the Swarm variant above — cap splash targets or add falloff.
- **Difficulty modes:** expose `HP_GROWTH`, `BOSS_WAVE_MOD`, and spawn count multiplier as difficulty-tier constants (Normal/Hard/Nightmare) rather than hardcoding — you'll want to tune these after playtesting anyway.

---

## 7. Suggested Playtesting Checklist

- [ ] Time-to-kill a single Wave-1 UFO-A with a Level-1 turret should be ~1-2 seconds (currently 35 dmg vs 80 hp ≈ 2 hits)
- [ ] Verify a fully-upgraded Level-10 turret can still one-or-two-shot early-wave trash by wave 10-12 (power fantasy check)
- [ ] Confirm coin income keeps pace with upgrade costs — plot cumulative coins earned vs. cumulative upgrade cost by wave 10
- [ ] Confirm boss waves (5, 10, 15) feel like spikes, not walls — playtesters should die *sometimes*, not always