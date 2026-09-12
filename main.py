"""
8-Ball Helper - Starter
Usage:
  python main.py --image screenshot.png   -> analyze image
  python main.py --live                   -> live screen capture
"""
import cv2
import argparse
import numpy as np
import sys

from detector import TableDetector
from physics import calculate_shot, find_best_shot, predict_cushion_path, ghost_ball_position

def draw_predictions(image, cue_ball, balls, pockets, table_bounds, best_shot=None):
    overlay = image.copy()
    
    x_min, y_min, x_max, y_max = table_bounds
    # Draw table bounds
    cv2.rectangle(overlay, (x_min, y_min), (x_max, y_max), (0,255,0), 2)
    
    # Draw pockets
    for px, py in pockets:
        cv2.circle(overlay, (px, py), 18, (0,0,255), 2)
        cv2.circle(overlay, (px, py), 5, (0,0,255), -1)
    
    # Draw balls
    if cue_ball:
        cv2.circle(overlay, cue_ball, 12, (255,255,255), -1)
        cv2.circle(overlay, cue_ball, 12, (0,0,0), 2)
        cv2.putText(overlay, "CUE", (cue_ball[0]-15, cue_ball[1]-18), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255,255,255), 2)
    
    for i, b in enumerate(balls):
        cv2.circle(overlay, b, 10, (255,0,0), -1)
        cv2.circle(overlay, b, 10, (255,255,255), 1)
    
    # Draw all possible shots lightly
    if cue_ball and balls and pockets:
        for ball in balls:
            for pocket in pockets:
                shot = calculate_shot(cue_ball, ball, pocket, ball_radius=12)
                if shot['angle'] > 45:  # skip hard shots
                    continue
                ghost = shot['ghost_pos']
                # Cue to ghost line (white, dashed style)
                cv2.line(overlay, cue_ball, ghost, (200,200,200), 1, cv2.LINE_AA)
                # Ghost ball
                cv2.circle(overlay, ghost, 10, (255,255,255), 1)
                # Target to pocket
                cv2.line(overlay, ball, pocket, (100,100,255), 1, cv2.LINE_AA)
    
    # Draw BEST shot with thick lines
    if best_shot:
        ball = best_shot['target_ball']
        pocket = best_shot['pocket']
        shot = best_shot['shot']
        ghost = shot['ghost_pos']
        
        print(f"\n[BEST SHOT]")
        print(f"Target Ball: {ball} -> Pocket: {pocket}")
        print(f"Angle: {shot['angle']:.1f}° (lower = easier)")
        print(f"Distance cue->ghost: {shot['distance_cue_to_ghost']:.0f}px")
        
        # Main prediction lines
        cv2.line(overlay, cue_ball, ghost, (0,255,255), 3)  # Yellow - cue path
        cv2.circle(overlay, ghost, 11, (0,255,255), 2)       # Ghost ball
        
        # Extend cue line backwards for aiming help
        cue_dir = shot['cue_dir']
        ext_start = (int(cue_ball[0] - cue_dir[0]*100), int(cue_ball[1] - cue_dir[1]*100))
        cv2.line(overlay, ext_start, cue_ball, (0,255,255), 1, cv2.LINE_AA)
        
        cv2.line(overlay, ball, pocket, (0,255,0), 3)  # Green - target to pocket
        
        # Predict cushion after pocket? Or predict if cue will bounce
        # Show cue path after hit with cushion bounce
        cushion_path = predict_cushion_path(ghost, shot['target_dir'], table_bounds, max_bounces=1)
        for i in range(len(cushion_path)-1):
            cv2.line(overlay, cushion_path[i], cushion_path[i+1], (255,255,0), 2, cv2.LINE_AA)
        
        # Labels
        cv2.putText(overlay, f"BEST {shot['angle']:.0f} deg", (ball[0]+15, ball[1]), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0,255,0), 2)
    
    # Blend
    cv2.addWeighted(overlay, 0.85, image, 0.15, 0, image)
    return image

def process_image(image_path):
    img = cv2.imread(image_path)
    if img is None:
        print(f"Could not read {image_path}")
        return
    
    detector = TableDetector()
    table_bounds, pockets = detector.detect_table(img)
    cue_ball, balls = detector.detect_balls(img, table_bounds)
    
    print(f"Table: {table_bounds}")
    print(f"Pockets: {len(pockets)} found")
    print(f"Cue: {cue_ball}")
    print(f"Balls: {len(balls)} found - {balls}")
    
    if not cue_ball:
        print("WARNING: Cue ball not detected. Click on image to set it manually.")
        # Let user click
        clone = img.copy()
        cv2.imshow("Click cue ball, then press any key", clone)
        def click_event(event, x, y, flags, param):
            if event == cv2.EVENT_LBUTTONDOWN:
                param[0] = (x,y)
                cv2.circle(clone, (x,y), 12, (255,255,255), -1)
                cv2.imshow("Click cue ball, then press any key", clone)
        temp = [None]
        cv2.setMouseCallback("Click cue ball, then press any key", click_event, temp)
        cv2.waitKey(0)
        if temp[0]:
            cue_ball = temp[0]
        cv2.destroyAllWindows()
    
    best = None
    if cue_ball and balls:
        best = find_best_shot(cue_ball, balls, pockets, ball_radius=12)
    
    result = draw_predictions(img, cue_ball, balls, pockets, table_bounds, best)
    
    cv2.imshow("8Ball Helper - Prediction (Q to quit)", result)
    cv2.waitKey(0)
    cv2.destroyAllWindows()
    
    cv2.imwrite("output_prediction.jpg", result)
    print("Saved to output_prediction.jpg")

def live_mode():
    try:
        import mss
    except ImportError:
        print("Install mss: pip install mss")
        return
    
    detector = TableDetector()
    sct = mss.mss()
    monitor = sct.monitors[1]  # full screen
    
    print("Live mode - Press Q to quit, S to save screenshot")
    print("Put 8 Ball Pool window in view...")
    
    while True:
        screenshot = np.array(sct.grab(monitor))
        img = cv2.cvtColor(screenshot, cv2.COLOR_BGRA2BGR)
        # Resize for speed
        img = cv2.resize(img, (1280, 720))
        
        table_bounds, pockets = detector.detect_table(img)
        cue_ball, balls = detector.detect_balls(img, table_bounds)
        
        best = None
        if cue_ball and balls:
            best = find_best_shot(cue_ball, balls, pockets, ball_radius=10)
        
        result = draw_predictions(img, cue_ball, balls, pockets, table_bounds, best)
        
        cv2.imshow("8Ball Helper LIVE", result)
        key = cv2.waitKey(30) & 0xFF
        if key == ord('q'):
            break
        if key == ord('s'):
            cv2.imwrite("live_screenshot.png", screenshot)
            print("Saved live_screenshot.png")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", type=str, help="Path to table screenshot")
    parser.add_argument("--live", action="store_true", help="Live screen capture")
    args = parser.parse_args()
    
    if args.live:
        live_mode()
    elif args.image:
        process_image(args.image)
    else:
        print("Provide --image or --live")
        print("Example: python main.py --image test.png")
        print("Creating demo image...")
        # Create synthetic demo
        demo = np.zeros((600, 1000, 3), dtype=np.uint8)
        demo[:] = (35, 100, 35)  # green table
        # Fake balls
        cv2.circle(demo, (200,300), 12, (255,255,255), -1)  # cue
        cv2.circle(demo, (500,300), 10, (255,0,0), -1)
        cv2.circle(demo, (600,250), 10, (0,0,255), -1)
        cv2.imwrite("demo_table.jpg", demo)
        process_image("demo_table.jpg")
