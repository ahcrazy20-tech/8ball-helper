# 🛡️ SAFETY GUIDE - How to Not Get Banned

## Risk Levels

| Mode | Risk | Detection |
|------|------|-----------|
| Play with Friends (private) | 🟢 Very Low | No server checks, only manual report |
| Practice / Offline | 🟢 Very Low | No server |
| 1v1 Random (coins) | 🟡 Medium | Server stats analysis |
| Tournaments | 🔴 High | Manual review, high stakes |
| Ranked / Leaderboard | 🔴 Very High | Active anti-cheat |

**Rule #1**: Only use in Play With Friends or Practice. Never in ranked.

## Safety Features in Code

### 1. Panic Hide (Most Important)
- **Gesture**: 3-finger double tap OR 2-finger long press
- **Effect**: Instantly hides overlay, disables helper
- **Restore**: 4-finger double tap to restore
- **When to use**: Friends look at screen, someone asks to see your phone, you feel watched

### 2. Tiny Toggle
- Old version had big 90x35 button "Helper ON" - very obvious
- New version: 10x10 dot at (3,35) - top-left corner, alpha 0.3, looks like dust
- **Long press dot** (1.5s) to make it visible temporarily
- Tap to toggle

### 3. Screen Capture Auto-Hide
- If you start screen recording (Control Center -> Record), overlay auto-hides
- When recording stops, it reappears after 1 second
- Prevents accidental stream leak

### 4. Background Hide
- When you switch apps, overlay hides
- Prevents overlay showing in app switcher screenshot

### 5. Humanization
- Ghost ball position has ±1.5px random jitter
- Angle has ±0.5° noise
- Timing has ±0.03s jitter
- Makes you look human, not bot

### 6. Bundle Check
- Dylib only activates in `com.miniclip.8ballpool`
- If injected into other app by mistake, it does nothing
- Prevents crash and detection in other apps

## How to Use Safely - Step by Step

### Before Game
1. Inject dylib with innocent name (`libUnityGraphics.dylib`) via TrollFools
2. Respring
3. Open 8 Ball Pool
4. Wait 3-7 seconds (random delay) - overlay appears
5. Check tiny dot at top-left - if visible, helper is ON
6. Do NOT show friends

### During Game
1. Play normally for first 2-3 games WITHOUT using lines (build legit stats)
2. When you want to use helper, glance at lines quickly, then shoot
3. Don't stare at lines for 10 seconds - looks suspicious
4. Miss sometimes intentionally! 100% accuracy is bot flag.
5. If friend says "how you always win?", say you practice, then disable for a game
6. Use panic gesture if someone looks

### After Game
1. If you want to be extra safe, disable helper (tap dot) when not needed
2. Don't keep overlay on 24/7
3. Clear app from background occasionally

## What Causes Bans (Real Reports)

From Reddit and iOSGods:

1. **Perfect win streak**: 20 wins in a row with 95% pot rate -> flagged
2. **Impossible shots**: Potting 60°+ cut shots consistently -> flagged
3. **Reported by players**: Friends report you, Miniclip manually reviews
4. **Jailbreak detection**: Using old jailbreak bypass instead of TrollStore -> instant
5. **Screenshot with overlay**: Posted screenshot on Discord with yellow/green lines visible -> banned
6. **Using in tournament**: High-stakes games have manual review

## How to Avoid Each

1. **Win streak**: Lose intentionally sometimes. Keep win rate < 80%
2. **Impossible shots**: We already filter >55° shots. Don't attempt crazy shots even if line shows.
3. **Reports**: Only use with trusted friends, not randoms who will report
4. **Jailbreak**: Use TrollStore method, not jailbreak
5. **Screenshot**: Enable auto-hide on capture, use panic gesture
6. **Tournament**: Don't use in tournaments at all

## Emergency - What if You Get Warning?

Miniclip usually gives warning before ban:
- "Unusual activity detected"
- Coins reset
- Temporary ban

If you get warning:
1. Immediately uninstall injected version
2. Install clean version from App Store
3. Don't inject for 2 weeks
4. Play legit to rebuild trust score
5. If banned, appeal saying "my brother played on my phone"

## Advanced Safety - For Paranoid

### Use Alt Account
- Don't use helper on main account with expensive cues
- Use alt account for fun with friends

### Use VPN? Not needed
- 8 Ball Pool doesn't IP ban, only account ban
- VPN doesn't help with behavior detection

### Don't Use Auto-Clicker
- Some people combine aim helper with auto-clicker - very detectable
- Our dylib is visual only, no auto-shoot - safer

### Check for Updates
- When Miniclip updates game, they may add new anti-cheat
- Wait 1-2 days after update, check Reddit if others banned
- Update dylib if needed

## Safety Checklist

Before each session:

- [ ] Dylib renamed to innocent name?
- [ ] Using TrollFools (not jailbreak)?
- [ ] Only Play With Friends?
- [ ] Panic gesture working? (test 3-finger double tap)
- [ ] Screen capture hide enabled?
- [ ] Ready to miss intentionally?
- [ ] Friends trusted not to report?

If all yes, you're good.

## Legal & Ethical

- This tool is for educational purposes and private games with friends
- Using in ranked/tournaments for coins/money is against ToS and unfair
- Don't sell or distribute as cheat - use privately
- Respect friends - if they don't want you to use helper, don't

## Summary

Safety = **Human behavior + Private use + Panic hide**

The dylib is already stealthy, but your behavior matters more than code.

- Be human: miss, take time, don't be perfect
- Be private: only with trusted friends
- Be ready: know panic gesture

Stay safe! 🛡️
