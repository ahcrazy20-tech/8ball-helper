# 8-Ball Helper - Predicted Ball & Lines

This is your starter kit to build an aim helper that calculates predicted ball paths.

## How it works - 4 Steps

### 1. Screen Capture
Capture the game window (Gameloop, Miniclip web, or Android emulator).

### 2. Ball & Table Detection
Two ways:
- **Simple (start here):** Color detection with OpenCV - white ball is white, table is green
- **Advanced:** YOLOv8-seg model trained to detect balls, holes, guidelines [2]

### 3. Physics Calculation
- Find cue ball -> target ball vector
- Use **Ghost Ball method**: imagine where cue ball needs to be to pot target
- Calculate angle to pocket
- For cushion shots: reflect vector like a mirror `angle_in = angle_out`

### 4. Overlay Lines
Draw prediction lines on top of game using transparent window.

---

## GitHub Projects You Should Fork / Study

I found these for you:

1.  **ChetoAI-8-ball-pool** - Best modern example [2]
    - Uses YOLOv11m-seg + DirectX 11 overlay + ONNX Runtime
    - Real-time extended guidelines
    - Repo: https://github.com/KOJORICH01/ChetoAI-8-ball-pool

2.  **8-Ball-Pool-Ball-Path-Prediction** - Gameloop hack [1]
    - x86 hack library, shows ball path + auto-aim
    - C++ / D2DOverlay
    - Repo: https://github.com/Uday1236/8-Ball-Pool-Ball-Path-Prediction

3.  **pool-shot-predictor** - Simplest Python starter
    - Pure Python + OpenCV, ghost ball method
    - Repo: https://github.com/lliamsymonds04/pool-shot-predictor

4.  **8-Ball-Pool-Analysis** - Video analysis
    - Analyses footage and shows optimal shot predictions
    - Repo: https://github.com/brandonabela/8-Ball-Pool-Analysis

## Your Roadmap

**Week 1 - Python Prototype (what I built for you here):**
- Run `main.py` -> it detects balls by color and draws prediction lines
- Test on screenshot of 8 Ball Pool

**Week 2 - Upgrade Detection:**
- Train YOLOv8 on 8-ball dataset (Roboflow has datasets)
- Replace color detection with YOLO model like ChetoAI does [2]

**Week 3 - Physics & Cushions:**
- Add 1-cushion bank shot prediction (reflect line off table borders)
- Add collision detection ball-to-ball

**Week 4 - Overlay:**
- If on Windows Gameloop: build DirectX 11 transparent overlay (see ChetoAI)
- If on PC/Web: use Python transparent Tkinter window or OBS overlay

## How GitHub Helps You

1. Create new repo `8ball-helper`
2. Push this starter code
3. Fork `lliamsymonds04/pool-shot-predictor` and `KOJORICH01/ChetoAI-8-ball-pool` to study code
4. Use GitHub Actions to build exe later

## Important Note
Use this for learning / offline practice. Using it in online ranked matches can get your account banned in Miniclip 8 Ball Pool. The safest is to practice on screenshots/video first.

## How to Run This Starter

```bash
pip install -r requirements.txt
python main.py --image test_screenshot.png
# or for live screen capture:
python main.py --live
```

Press Q to quit, C to capture new screenshot.
