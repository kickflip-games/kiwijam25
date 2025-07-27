#!/usr/bin/env python3
"""
Simple Index Finger Tracking Client for Godot
Tracks only the right hand index finger tip position and sends to Godot TCP server.
"""

import cv2
import mediapipe as mp
import socket
import json
import time
import argparse
from typing import Optional, Dict, Any
import math

def euclidean_distance(a, b):
    return math.sqrt((a['x'] - b['x'])**2 + (a['y'] - b['y'])**2 + (a['z'] - b['z'])**2)

class SimpleFingerTracker:
    def __init__(self, 
                 host: str = 'localhost', 
                 port: int = 12345,
                 show_visualization: bool = True,
                 detection_confidence: float = 0.3,
                 tracking_confidence: float = 0.3):
        
        # Socket setup - CLIENT mode (connects to Godot server)
        self.host = host
        self.port = port
        self.client_socket = None
        self.connected = False
        
        # MediaPipe setup - simplified for single hand
        self.mp_hands = mp.solutions.hands
        self.hands = self.mp_hands.Hands(
            static_image_mode=False,
            max_num_hands=1,  # Only track one hand
            min_detection_confidence=detection_confidence,
            min_tracking_confidence=tracking_confidence,
            # model_complexity=0  # Use the simplest model for speed
        )
        self.mp_drawing = mp.solutions.drawing_utils
        
        # Visualization setup
        self.show_visualization = show_visualization
        
        # Data storage
        self.frame_count = 0
        self.last_finger_pos = None
        
        # FPS calculation
        self.fps_counter = 0
        self.fps_start_time = time.time()
        self.current_fps = 0
        
        print(f"Simple Finger Tracker Client initialized - Target: {host}:{port}")
        print(f"Detection confidence: {detection_confidence}, Tracking confidence: {tracking_confidence}")

    def connect_to_godot_server(self):
        """Connect to Godot TCP server"""
        try:
            self.client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.client_socket.connect((self.host, self.port))
            self.connected = True
            print(f"✓ Connected to Godot server at {self.host}:{self.port}")
            return True
        except Exception as e:
            print(f"✗ Failed to connect to Godot server: {e}")
            self.connected = False
            return False

    def try_reconnect(self):
        """Attempt to reconnect to Godot server"""
        if self.connected:
            return True
        
        print("🔄 Attempting to reconnect to Godot...")
        self.cleanup_connection()
        return self.connect_to_godot_server()

    def send_finger_data(self, finger_data: Dict[str, Any]):
        """Send finger position to Godot server"""
        if not self.connected or not self.client_socket:
            return
            
        try:
            message = json.dumps(finger_data) + '\n'
            self.client_socket.send(message.encode('utf-8'))
            
            # Reduced logging: only print every 5 seconds instead of every 60 frames
            if finger_data.get('frame_count', 0) % 150 == 0:
                print(f"✓ Sending data... Frame: {finger_data.get('frame_count', 0)}")
                
        except Exception as e:
            print(f"✗ Connection lost: {e}")
            self.connected = False

    def extract_index_finger_position(self, results) -> Optional[Dict[str, Any]]:
        """Extract right hand index finger tip position from MediaPipe results,
        also detect closed fist and fast movement.
        """

        if not results.multi_hand_landmarks or not results.multi_handedness:
            return None

        for hand_landmarks, handedness in zip(results.multi_hand_landmarks, results.multi_handedness):
            hand_label = handedness.classification[0].label

            if hand_label == "Right":
                INDEX_FINGER_TIP = 8
                INDEX_MCP = 5
                MIDDLE_TIP = 12
                RING_TIP = 16
                PINKY_TIP = 20
                MIDDLE_MCP = 9
                RING_MCP = 13
                PINKY_MCP = 17

                def is_finger_curled(tip_idx, mcp_idx):
                    tip = hand_landmarks.landmark[tip_idx]
                    mcp = hand_landmarks.landmark[mcp_idx]
                    return (tip.y - mcp.y) > -0.05  # tip below mcp (positive y is down)

                if len(hand_landmarks.landmark) > PINKY_TIP:
                    # Get index finger tip
                    finger_tip = hand_landmarks.landmark[INDEX_FINGER_TIP]

                    # Check for closed fist
                    is_closed_fist = all([
                        is_finger_curled(INDEX_FINGER_TIP, INDEX_MCP),
                        is_finger_curled(MIDDLE_TIP, MIDDLE_MCP),
                        is_finger_curled(RING_TIP, RING_MCP),
                        is_finger_curled(PINKY_TIP, PINKY_MCP)
                    ])

                    # Build current position
                    finger_data = {
                        'x': round(finger_tip.x, 3),
                        'y': round(finger_tip.y, 3),
                        'z': round(finger_tip.z, 3),
                        'h': True,
                        'c': is_closed_fist,
                        'f': False  # default, will update below
                    }

                    # Detect fast movement
                    if hasattr(self, 'last_finger_pos') and self.last_finger_pos is not None:
                        dist = euclidean_distance(finger_data, self.last_finger_pos)
                        if dist > 0.15:  # tweak this threshold as needed
                            finger_data['fast'] = True

                    self.last_finger_pos = finger_data
                    return finger_data

        return {
            'x': None,
            'y': None,
            'z': None,
            'h': False,
            'c': False,
            'f': False
        }

    def draw_finger_tracking(self, image, results):
        """Draw only the index finger tip on the image"""
        if not results.multi_hand_landmarks or not results.multi_handedness:
            return image
        
        height, width = image.shape[:2]
        
        # Find and draw right hand index finger
        for hand_landmarks, handedness in zip(results.multi_hand_landmarks, results.multi_handedness):
            hand_label = handedness.classification[0].label
            
            if hand_label == "Right":
                INDEX_FINGER_TIP = 8
                
                if len(hand_landmarks.landmark) > INDEX_FINGER_TIP:
                    finger_tip = hand_landmarks.landmark[INDEX_FINGER_TIP]
                    
                    # Convert normalized coordinates to pixel coordinates
                    x = int(finger_tip.x * width)
                    y = int(finger_tip.y * height)

                    color = (0, 255, 0)
                    if self.last_finger_pos.get('fist'):
                        color = (0, 0, 255)  # red for fist
                    elif self.last_finger_pos.get('fast'):
                        color = (0, 255, 255)  # yellow for fast

                    cv2.circle(image, (x, y), 15, color, -1)
                    
                    # Draw a large circle for the index finger tip
                    cv2.circle(image, (x, y), 15, (0, 255, 0), -1)
                    cv2.circle(image, (x, y), 20, (255, 255, 255), 3)
                    
                    # Draw coordinates text
                    cv2.putText(image, f"({finger_tip.x:.2f}, {finger_tip.y:.2f})", 
                               (x + 25, y), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
        
        return image

    def add_info_overlay(self, image, finger_data):
        """Add information overlay to the image"""
        # Background for text
        overlay = image.copy()
        cv2.rectangle(overlay, (10, 10), (350, 130), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.7, image, 0.3, 0, image)
        
        # FPS display
        fps_color = (0, 255, 0) if self.current_fps >= 25 else (255, 255, 0) if self.current_fps >= 15 else (0, 0, 255)
        cv2.putText(image, f"FPS: {self.current_fps:.1f}", (20, 35), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, fps_color, 2)
        
        # Connection status
        connection_text = "CONNECTED TO GODOT" if self.connected else "DISCONNECTED (auto-retry)"
        connection_color = (0, 255, 0) if self.connected else (0, 0, 255)
        cv2.putText(image, connection_text, (20, 55), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, connection_color, 2)
        
        # Hand detection status
        if finger_data and finger_data['h']:
            status_text = "RIGHT HAND DETECTED"
            status_color = (0, 255, 0)
        else:
            status_text = "NO RIGHT HAND"
            status_color = (0, 0, 255)
        
        cv2.putText(image, status_text, (20, 75), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, status_color, 2)
        
        # Server info
        cv2.putText(image, f"Godot: {self.host}:{self.port}", (20, 95), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 0), 1)
        
        # Instructions
        cv2.putText(image, "Press 'q' to quit, 'v' to toggle, 'r' to reconnect", (20, 115), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.4, (200, 200, 200), 1)

    def run(self, camera_id: int = 0):
        """Main loop for finger tracking"""
        # Connect to Godot server
        if not self.connect_to_godot_server():
            print("Could not connect to Godot. Make sure Godot is running first!")
            print("The script will keep trying to connect...")
        
        # Setup camera
        cap = cv2.VideoCapture(camera_id)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 320)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 240)
        cap.set(cv2.CAP_PROP_FPS, 60)
        
        if not cap.isOpened():
            print("Error: Could not open camera")
            return
        
        print("Starting finger tracking...")
        print("Show your RIGHT HAND to the camera")
        print("Press 'q' to quit, 'v' to toggle visualization, 'r' to reconnect")
        
        last_reconnect_attempt = 0
        reconnect_interval = 3.0  # Try to reconnect every 3 seconds
        
        try:
            while True:
                ret, frame = cap.read()
                if not ret:
                    print("Error: Could not read frame")
                    break
                
                self.frame_count += 1
                
                # Calculate FPS every second
                self.fps_counter += 1
                current_time = time.time()
                if current_time - self.fps_start_time >= 1.0:
                    self.current_fps = self.fps_counter / (current_time - self.fps_start_time)
                    self.fps_counter = 0
                    self.fps_start_time = current_time
                
                # Auto-reconnect logic
                current_time = time.time()
                if not self.connected and (current_time - last_reconnect_attempt) > reconnect_interval:
                    last_reconnect_attempt = current_time
                    self.try_reconnect()
                
                # Flip frame horizontally for mirror effect
                frame = cv2.flip(frame, 1)
                
                # Convert BGR to RGB for MediaPipe
                rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                
                # Process frame with MediaPipe
                results = self.hands.process(rgb_frame)
                
                # Extract finger position
                finger_data = self.extract_index_finger_position(results)
                
                # Send to Godot server (only if connected)
                if finger_data and self.connected:
                    self.send_finger_data(finger_data)
                
                # Visualization
                if self.show_visualization:
                    # Draw finger tracking
                    annotated_frame = self.draw_finger_tracking(frame, results)
                    
                    # Add info overlay
                    self.add_info_overlay(annotated_frame, finger_data)
                    
                    # Display frame
                    cv2.imshow('Index Finger Tracking - CLIENT', annotated_frame)
                
                # Handle key presses
                key = cv2.waitKey(1) & 0xFF
                if key == ord('q'):
                    break
                elif key == ord('v'):
                    self.show_visualization = not self.show_visualization
                    if not self.show_visualization:
                        cv2.destroyAllWindows()
                elif key == ord('r'):
                    # Manual reconnect
                    print("🔄 Manual reconnect requested...")
                    self.try_reconnect()
        
        except KeyboardInterrupt:
            print("\nShutting down...")
        
        finally:
            self.cleanup(cap)

    def cleanup_connection(self):
        """Clean up socket connection"""
        if self.client_socket:
            try:
                self.client_socket.close()
            except:
                pass
        self.client_socket = None
        self.connected = False

    def cleanup(self, cap):
        """Clean up all resources"""
        # Close camera
        cap.release()
        cv2.destroyAllWindows()
        
        # Close socket connection
        self.cleanup_connection()
        
        print("Cleanup complete")

def main():
    parser = argparse.ArgumentParser(description='Simple Index Finger Tracking Client for Godot')
    parser.add_argument('--host', default='localhost', help='Godot server host (default: localhost)')
    parser.add_argument('--port', type=int, default=12345, help='Godot server port (default: 12345)')
    parser.add_argument('--camera', type=int, default=0, help='Camera ID (default: 0)')
    parser.add_argument('--no-viz', action='store_true', help='Disable visualization window')
    parser.add_argument('--detection-confidence', type=float, default=0.3, help='Min detection confidence (default: 0.3)')
    parser.add_argument('--tracking-confidence', type=float, default=0.3, help='Min tracking confidence (default: 0.3)')
    
    args = parser.parse_args()
    

    print("FINGER TRACKER CLIENT FOR GODOT")
    print("=" * 50)
    
    # Create and run finger tracker
    tracker = SimpleFingerTracker(
        host=args.host,
        port=args.port,
        show_visualization=not args.no_viz,
        detection_confidence=args.detection_confidence,
        tracking_confidence=args.tracking_confidence
    )
    
    tracker.run(camera_id=args.camera)

if __name__ == "__main__":
    main()