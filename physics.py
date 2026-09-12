import numpy as np
import math

def get_distance(p1, p2):
    return math.hypot(p1[0]-p2[0], p1[1]-p2[1])

def normalize(v):
    norm = np.linalg.norm(v)
    if norm == 0:
        return v
    return v / norm

def reflect_vector(incident, normal):
    """Reflect incident vector off a surface with given normal"""
    incident = np.array(incident, dtype=float)
    normal = np.array(normal, dtype=float)
    normal = normalize(normal)
    return incident - 2 * np.dot(incident, normal) * normal

def ghost_ball_position(target_ball, pocket, ball_radius):
    """
    Ghost ball method: Where cue ball center must be to pot target into pocket
    target_ball -> pocket vector, go back by 2*radius
    """
    target = np.array(target_ball, dtype=float)
    pocket = np.array(pocket, dtype=float)
    
    direction = pocket - target
    direction = normalize(direction)
    
    ghost = target - direction * (ball_radius * 2)
    return tuple(ghost.astype(int)), tuple(direction)

def calculate_shot(cue_ball, target_ball, pocket, ball_radius=15):
    """
    Returns:
    - ghost_pos: where cue should hit
    - cue_to_ghost vector
    - target_to_pocket vector
    - angle difference (lower = easier shot)
    """
    ghost_pos, target_dir = ghost_ball_position(target_ball, pocket, ball_radius)
    
    cue = np.array(cue_ball, dtype=float)
    ghost = np.array(ghost_pos, dtype=float)
    
    cue_dir = normalize(ghost - cue)
    
    # Angle between cue->ghost and target->pocket
    # If 0 degrees, it's a straight shot
    dot = np.clip(np.dot(cue_dir, target_dir), -1.0, 1.0)
    angle = math.degrees(math.acos(dot))
    
    return {
        'ghost_pos': ghost_pos,
        'cue_dir': cue_dir,
        'target_dir': target_dir,
        'angle': angle,
        'distance_cue_to_ghost': get_distance(cue_ball, ghost_pos),
        'distance_target_to_pocket': get_distance(target_ball, pocket)
    }

def predict_cushion_path(start, direction, table_bounds, max_bounces=2):
    """
    Predict path with cushion bounces
    table_bounds = (x_min, y_min, x_max, y_max)
    """
    x_min, y_min, x_max, y_max = table_bounds
    path = [start]
    pos = np.array(start, dtype=float)
    dir_vec = normalize(np.array(direction, dtype=float))
    
    for _ in range(max_bounces):
        # Find intersection with each wall
        t_values = []
        
        # Left wall (x = x_min)
        if dir_vec[0] != 0:
            t = (x_min - pos[0]) / dir_vec[0]
            if t > 0:
                y = pos[1] + t * dir_vec[1]
                if y_min <= y <= y_max:
                    t_values.append((t, 'left', np.array([1,0])))
        # Right wall
        if dir_vec[0] != 0:
            t = (x_max - pos[0]) / dir_vec[0]
            if t > 0:
                y = pos[1] + t * dir_vec[1]
                if y_min <= y <= y_max:
                    t_values.append((t, 'right', np.array([-1,0])))
        # Top wall
        if dir_vec[1] != 0:
            t = (y_min - pos[1]) / dir_vec[1]
            if t > 0:
                x = pos[0] + t * dir_vec[0]
                if x_min <= x <= x_max:
                    t_values.append((t, 'top', np.array([0,1])))
        # Bottom wall
        if dir_vec[1] != 0:
            t = (y_max - pos[1]) / dir_vec[1]
            if t > 0:
                x = pos[0] + t * dir_vec[0]
                if x_min <= x <= x_max:
                    t_values.append((t, 'bottom', np.array([0,-1])))
        
        if not t_values:
            break
            
        t_values.sort(key=lambda x: x[0])
        t, wall, normal = t_values[0]
        
        hit_point = pos + dir_vec * t
        path.append(tuple(hit_point.astype(int)))
        
        # Reflect
        dir_vec = reflect_vector(dir_vec, normal)
        pos = hit_point + dir_vec * 2  # move slightly off wall
    
    # Add final extension
    final_point = pos + dir_vec * 500
    path.append(tuple(final_point.astype(int)))
    
    return path

def find_best_shot(cue_ball, balls, pockets, ball_radius=15):
    """Find easiest shot (lowest angle)"""
    best = None
    best_score = float('inf')
    
    for ball in balls:
        for pocket in pockets:
            shot = calculate_shot(cue_ball, ball, pocket, ball_radius)
            # Score = angle + distance factor (closer is easier)
            score = shot['angle'] + shot['distance_cue_to_ghost'] * 0.01
            
            if score < best_score:
                best_score = score
                best = {
                    'target_ball': ball,
                    'pocket': pocket,
                    'shot': shot,
                    'score': score
                }
    return best
