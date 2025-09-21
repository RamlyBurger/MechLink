#!/usr/bin/env python3
"""
Simple MechLink Task Monitoring Service
Monitors Firebase Realtime Database and continues recording when app goes to sleep
"""

import json
import time
from datetime import datetime
from typing import Dict, Any, Optional
import firebase_admin
from firebase_admin import credentials, db, firestore, messaging
import threading

class TaskMonitoringService:
    def __init__(self):
        """Initialize the task monitoring service"""
        self.firebase_app = None
        self.db_ref = None
        self.firestore_client = None
        self.monitoring = False
        self.monitor_thread = None
        
        # Track recordings and their last known durations
        self.tracked_recordings: Dict[str, Dict[str, Any]] = {}
        
        # Configuration
        self.check_interval = 1  # Check every second
        self.sleep_detection_timeout = 5  # 5 seconds without change = app is sleeping
        
        self._initialize_firebase()
    
    def _initialize_firebase(self):
        """Initialize Firebase Admin SDK"""
        try:
            # Initialize Firebase Admin SDK
            cred = credentials.Certificate('py/mechlink-34628-firebase-adminsdk-fbsvc-6d305dc93a.json')
            self.firebase_app = firebase_admin.initialize_app(cred, {
                'databaseURL': 'https://mechlink-34628-default-rtdb.asia-southeast1.firebasedatabase.app'
            })
            
            # Initialize database references
            self.db_ref = db.reference('/')
            self.firestore_client = firestore.client()
            
            print("Firebase initialized successfully")
            
        except Exception as e:
            print(f"Failed to initialize Firebase: {e}")
            raise
    
    def start_monitoring(self):
        """Start monitoring task recordings"""
        if self.monitoring:
            print("Monitoring already started")
            return
        
        self.monitoring = True
        self.monitor_thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self.monitor_thread.start()
        print("Task monitoring service started")
    
    def stop_monitoring(self):
        """Stop monitoring task recordings"""
        self.monitoring = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=10)
        print("Task monitoring service stopped")
    
    def _monitor_loop(self):
        """Main monitoring loop"""
        print("Starting monitoring loop...")
        
        while self.monitoring:
            try:
                self._check_recordings()
                time.sleep(self.check_interval)
            except Exception as e:
                print(f"Error in monitoring loop: {e}")
                time.sleep(self.check_interval)
    
    def _check_recordings(self):
        """Check all active recordings"""
        try:
            # Get all current recordings from Realtime Database
            current_recordings = self.db_ref.get() or {}
            current_time = datetime.now()
            
            for mechanic_id, recording_data in current_recordings.items():
                if isinstance(recording_data, dict) and recording_data.get('status') == 'running':
                    self._process_recording(mechanic_id, recording_data, current_time)
            
            # Clean up recordings that are no longer in database
            mechanics_to_remove = []
            for mechanic_id in self.tracked_recordings:
                if mechanic_id not in current_recordings:
                    print(f"Recording removed from database: {mechanic_id}")
                    mechanics_to_remove.append(mechanic_id)
            
            for mechanic_id in mechanics_to_remove:
                del self.tracked_recordings[mechanic_id]
                
        except Exception as e:
            print(f"Error checking recordings: {e}")
    
    def _process_recording(self, mechanic_id: str, recording_data: Dict[str, Any], current_time: datetime):
        """Process a single recording"""
        try:
            task_id = recording_data.get('taskId', '')
            duration = recording_data.get('duration', 0)
            device_id = recording_data.get('deviceId', '')
            is_notified = recording_data.get('isNotified', False)
            
            # Check if this is a new recording or existing one
            if mechanic_id not in self.tracked_recordings:
                # New recording detected
                self.tracked_recordings[mechanic_id] = {
                    'taskId': task_id,
                    'lastDuration': duration,
                    'lastUpdateTime': current_time,
                    'isBackgroundRecording': False,
                    'deviceId': device_id,
                    'isNotified': is_notified
                }
                print(f"New recording detected: Mechanic {mechanic_id}, Task {task_id}")
                return
            
            tracked = self.tracked_recordings[mechanic_id]
            
            # Check if duration has changed (app is active)
            if duration != tracked['lastDuration']:
                # App is active and updating
                if tracked['isBackgroundRecording']:
                    print(f"App resumed recording: Mechanic {mechanic_id}, Task {task_id}")
                    tracked['isBackgroundRecording'] = False
                
                tracked['lastDuration'] = duration
                tracked['lastUpdateTime'] = current_time
                return
            
            # Duration hasn't changed - check if app might be sleeping
            time_since_update = (current_time - tracked['lastUpdateTime']).total_seconds()
            
            if time_since_update >= self.sleep_detection_timeout and not tracked['isBackgroundRecording']:
                # App appears to be sleeping, start background recording
                print(f"App appears to be sleeping, starting background recording: Mechanic {mechanic_id}, Task {task_id}")
                tracked['isBackgroundRecording'] = True
                self._start_background_recording(mechanic_id, recording_data)
            
            elif tracked['isBackgroundRecording']:
                # Continue background recording
                self._continue_background_recording(mechanic_id, recording_data)
            
            # Check if task has reached estimated time and send notification
            if not is_notified:
                self._check_estimated_time_notification(mechanic_id, recording_data)
                
        except Exception as e:
            print(f"Error processing recording for mechanic {mechanic_id}: {e}")
    
    def _start_background_recording(self, mechanic_id: str, recording_data: Dict[str, Any]):
        """Start background recording when app goes to sleep"""
        try:
            print(f"Starting background recording for mechanic {mechanic_id}")
            # The background recording will be handled by _continue_background_recording
            
        except Exception as e:
            print(f"Error starting background recording: {e}")
    
    def _continue_background_recording(self, mechanic_id: str, recording_data: Dict[str, Any]):
        """Continue recording in background"""
        try:
            current_duration = recording_data.get('duration', 0)
            new_duration = current_duration + 1
            
            # Update duration in Realtime Database
            self.db_ref.child(mechanic_id).child('duration').set(new_duration)
            
            # Update our tracking
            self.tracked_recordings[mechanic_id]['lastDuration'] = new_duration
            self.tracked_recordings[mechanic_id]['lastUpdateTime'] = datetime.now()
            
            if new_duration % 300 == 0:  # Log every 5 minutes
                print(f"Background recording: Mechanic {mechanic_id}, Duration: {new_duration}s")
                
        except Exception as e:
            print(f"Error continuing background recording: {e}")
    
    def _check_estimated_time_notification(self, mechanic_id: str, recording_data: Dict[str, Any]):
        """Check if task has reached estimated time and send notification"""
        try:
            task_id = recording_data.get('taskId', '')
            current_duration = recording_data.get('duration', 0)
            device_id = recording_data.get('deviceId', '')
            
            if not task_id or not device_id:
                return
            
            # Get task data from Firestore
            task_doc = self.firestore_client.collection('tasks').document(task_id).get()
            if not task_doc.exists:
                return
            
            task_data = task_doc.to_dict()
            estimated_time_hours = task_data.get('estimatedTime', 0)  # in hours
            estimated_seconds = int(estimated_time_hours * 3600)  # convert hours to seconds
            
            # Check if current duration has reached or exceeded estimated time
            if current_duration >= estimated_seconds:
                print(f"Task {task_id} has reached estimated time ({estimated_time_hours} hours)")
                
                # Send notification
                self._send_estimated_time_notification(mechanic_id, task_data, device_id, current_duration)
                
                # Mark as notified
                self.db_ref.child(mechanic_id).child('isNotified').set(True)
                self.tracked_recordings[mechanic_id]['isNotified'] = True
                
        except Exception as e:
            print(f"Error checking estimated time notification: {e}")
    
    def _send_estimated_time_notification(self, mechanic_id: str, task_data: Dict[str, Any], device_id: str, current_duration: int):
        """Send notification when task reaches estimated time"""
        try:
            task_title = task_data.get('title', 'Task')
            estimated_time_hours = task_data.get('estimatedTime', 0)
            
            # Get mechanic info
            mechanic_info = self._get_mechanic_info(mechanic_id)
            mechanic_name = mechanic_info.get('name', 'Mechanic') if mechanic_info else 'Mechanic'
            
            # Format current duration
            current_hours = current_duration / 3600
            current_minutes = current_duration // 60
            
            # Create notification
            notification = messaging.Notification(
                title="⏰ Estimated Time Reached",
                body=f"Hi {mechanic_name}! '{task_title}' has reached its estimated time of {estimated_time_hours} hours. Current time: {current_minutes} minutes."
            )
            
            # Create data payload
            data = {
                'type': 'estimated_time_reached',
                'taskId': task_data.get('id', ''),
                'estimatedTime': str(estimated_time_hours),
                'currentDuration': str(current_duration)
            }
            
            # Create message
            message = messaging.Message(
                notification=notification,
                data=data,
                token=device_id
            )
            
            # Send notification
            response = messaging.send(message)
            print(f"Estimated time notification sent: {response}")
            
            # Create notification record in Firestore
            self._create_notification_record(
                mechanic_id, 
                "⏰ Estimated Time Reached",
                f"'{task_title}' has reached its estimated time of {estimated_time_hours} hours.",
                'estimated_time_reached',
                task_data.get('id', '')
            )
            
        except Exception as e:
            print(f"Error sending estimated time notification: {e}")
    
    def _create_notification_record(self, mechanic_id: str, title: str, message: str, notification_type: str, task_id: str = ''):
        """Create a notification record in Firestore"""
        try:
            notification_data = {
                'mechanicId': mechanic_id,
                'title': title,
                'message': message,
                'created': datetime.now(),
                'type': notification_type,
                'taskId': task_id
            }
            
            self.firestore_client.collection('notifications').add(notification_data)
            print(f"Notification record created for mechanic {mechanic_id}")
            
        except Exception as e:
            print(f"Error creating notification record: {e}")
    
    def _get_mechanic_info(self, mechanic_id: str) -> Optional[Dict[str, Any]]:
        """Get mechanic information from Firestore"""
        try:
            mechanic_doc = self.firestore_client.collection('mechanics').document(mechanic_id).get()
            if mechanic_doc.exists:
                return mechanic_doc.to_dict()
            return None
        except Exception as e:
            print(f"Error getting mechanic info: {e}")
            return None
    
    def get_statistics(self) -> Dict[str, Any]:
        """Get monitoring statistics"""
        background_recordings = sum(1 for r in self.tracked_recordings.values() if r.get('isBackgroundRecording', False))
        
        return {
            'total_recordings': len(self.tracked_recordings),
            'background_recordings': background_recordings,
            'monitoring_status': self.monitoring,
            'check_interval': self.check_interval
        }

def main():
    """Main function to run the monitoring service"""
    print("Starting Simple MechLink Task Monitoring Service...")
    
    try:
        # Create and start the monitoring service
        service = TaskMonitoringService()
        service.start_monitoring()
        
        print("Service started successfully. Press Ctrl+C to stop.")
        
        # Keep the service running
        while True:
            time.sleep(300)  # Print stats every 5 minutes
            stats = service.get_statistics()
            print(f"Service stats: {stats}")
            
    except KeyboardInterrupt:
        print("Received shutdown signal...")
        service.stop_monitoring()
        print("Service stopped gracefully")
    except Exception as e:
        print(f"Service error: {e}")
        if 'service' in locals():
            service.stop_monitoring()

if __name__ == "__main__":
    main()
