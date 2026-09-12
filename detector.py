import cv2
import numpy as np

class TableDetector:
    def __init__(self):
        # HSV ranges - you will need to tune for your screen
        self.table_lower = np.array([35, 40, 40])
        self.table_upper = np.array([85, 255, 255])
        
        # Ball colors (rough)
        self.white_lower = np.array([0, 0, 180])
        self.white_upper = np.array([180, 50, 255])

    def detect_table(self, image):
        """Detect green table area and return bounds + pockets"""
        hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
        mask = cv2.inRange(hsv, self.table_lower, self.table_upper)
        
        # Clean mask
        kernel = np.ones((15,15), np.uint8)
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
        
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if not contours:
            h, w = image.shape[:2]
            return (50, 50, w-50, h-50), []  # fallback
        
        # Biggest contour = table
        biggest = max(contours, key=cv2.contourArea)
        x,y,w,h = cv2.boundingRect(biggest)
        
        # Estimate 6 pockets (corners + middle)
        pockets = [
            (x, y),                    # top-left
            (x + w//2, y),             # top-middle
            (x + w, y),                # top-right
            (x, y + h),                # bottom-left
            (x + w//2, y + h),         # bottom-middle
            (x + w, y + h),            # bottom-right
        ]
        
        bounds = (x, y, x+w, y+h)
        return bounds, pockets

    def detect_balls(self, image, table_bounds):
        """Simple ball detection - replace with YOLO later"""
        x_min, y_min, x_max, y_max = table_bounds
        roi = image[y_min:y_max, x_min:x_max]
        
        # Convert to grayscale and detect circles
        gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
        gray = cv2.medianBlur(gray, 5)
        
        # Hough circles - good for balls
        circles = cv2.HoughCircles(
            gray, cv2.HOUGH_GRADIENT, dp=1.2, minDist=20,
            param1=100, param2=15, minRadius=8, maxRadius=25
        )
        
        balls = []
        cue_ball = None
        
        if circles is not None:
            circles = np.uint16(np.around(circles))
            for (cx, cy, r) in circles[0, :]:
                abs_x = x_min + cx
                abs_y = y_min + cy
                
                # Check if white (cue ball)
                hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
                # small region around ball
                y1, y2 = max(0, abs_y-5), min(image.shape[0], abs_y+5)
                x1, x2 = max(0, abs_x-5), min(image.shape[1], abs_x+5)
                patch = hsv[y1:y2, x1:x2]
                if patch.size == 0:
                    continue
                mean_v = np.mean(patch[:,:,2])
                mean_s = np.mean(patch[:,:,1])
                
                # White ball has high V, low S
                if mean_v > 180 and mean_s < 60:
                    cue_ball = (abs_x, abs_y)
                else:
                    balls.append((abs_x, abs_y))
        
        return cue_ball, balls

    def detect_with_yolo_placeholder(self, image):
        """
        TODO: Replace with YOLOv8 detection like ChetoAI does
        Example:
        from ultralytics import YOLO
        model = YOLO('8ball_yolo.pt')
        results = model(image)
        """
        pass
