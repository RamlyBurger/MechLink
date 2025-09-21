#!/usr/bin/env python3
"""
MechLink Task Notification Service
Monitors Realtime Database recordings and sends notifications when tasks exceed estimated time
"""

import time
import threading
from datetime import datetime
from typing import Dict, Any, Optional
import firebase_admin
from firebase_admin import credentials, firestore, messaging, db

class TaskNotificationService:
    def __init__(self):
        """Initialize the task notification service"""
        self.firebase_app = None
        self.firestore_client = None
        self.db_ref = None
        self.monitoring = False
        self.monitor_thread = None
        
        # Configuration
        self.check_interval = 30  # Check every 30 seconds
        
        self._initialize_firebase()
    
    def _initialize_firebase(self):
        """Initialize Firebase Admin SDK"""
        try:
            # Initialize Firebase Admin SDK
            cred = credentials.Certificate('py/mechlink-34628-firebase-adminsdk-fbsvc-6d305dc93a.json')
            self.firebase_app = firebase_admin.initialize_app(cred, {
                'databaseURL': 'https://mechlink-34628-default-rtdb.asia-southeast1.firebasedatabase.app'
            })
            
            # Initialize Firestore client and Realtime Database
            self.firestore_client = firestore.client()
            self.db_ref = db.reference('/')
            
            print("Firebase initialized successfully for Task Notification Service")
            
        except Exception as e:
            print(f"Failed to initialize Firebase: {e}")
            raise
    
    def start_monitoring(self):
        """Start monitoring tasks for notifications"""
        if self.monitoring:
            print("Task notification monitoring already started")
            return
        
        self.monitoring = True
        self.monitor_thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self.monitor_thread.start()
        print("Task notification service started")
    
    def stop_monitoring(self):
        """Stop monitoring tasks"""
        self.monitoring = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=10)
        print("Task notification service stopped")
    
    def _monitor_loop(self):
        """Main monitoring loop"""
        print("Starting task notification monitoring loop...")
        
        while self.monitoring:
            try:
                self._check_all_recordings()
                time.sleep(self.check_interval)
            except Exception as e:
                print(f"Error in task notification monitoring loop: {e}")
                time.sleep(self.check_interval)
    
    def _check_all_recordings(self):
        """Check all active recordings in Realtime Database"""
        try:
            print("Checking all active recordings...")
            
            # Get all current recordings from Realtime Database
            current_recordings = self.db_ref.get() or {}
            
            print(f"Found {len(current_recordings)} recordings in Realtime Database")
            
            checked_count = 0
            for mechanic_id, recording_data in current_recordings.items():
                if isinstance(recording_data, dict):
                    # Extract recording data
                    device_id = recording_data.get('deviceId', '')
                    duration = recording_data.get('duration', 0)  # in seconds
                    is_notified = recording_data.get('isNotified', False)
                    job_id = recording_data.get('jobId', '')
                    status = recording_data.get('status', '')
                    task_id = recording_data.get('taskId', '')
                    
                    print(f"Recording {mechanic_id}: taskId={task_id}, duration={duration}s, isNotified={is_notified}, status={status}")
                    
                    # Only check running recordings that haven't been notified
                    if task_id and status == 'running' and not is_notified:
                        self._check_task_duration(task_id, duration, mechanic_id, device_id)
                        checked_count += 1
                    elif is_notified:
                        print(f"  -> Already notified, skipping")
                    elif status != 'running':
                        print(f"  -> Not running (status: {status}), skipping")
                    else:
                        print(f"  -> No taskId, skipping")
            
            print(f"Checked {checked_count} active recordings")
                
        except Exception as e:
            print(f"Error checking recordings: {e}")
            import traceback
            traceback.print_exc()
    
    def _check_task_duration(self, task_id: str, duration: int, mechanic_id: str, device_id: str):
        """Check if task duration exceeds estimated time"""
        try:
            # Get task data from Firestore
            task_doc = self.firestore_client.collection('tasks').document(task_id).get()
            if not task_doc.exists:
                print(f"  -> Task {task_id} not found in Firestore")
                return
            
            task_data = task_doc.to_dict()
            task_title = task_data.get('title', 'Unknown Task')
            estimated_time_seconds = task_data.get('estimatedTime', 0)  # in seconds
            
            print(f"  -> Task '{task_title}': duration={duration}s, estimatedTime={estimated_time_seconds}s")
            
            # Skip if no estimated time is set
            if not estimated_time_seconds or estimated_time_seconds <= 0:
                print(f"  -> No estimated time set, skipping")
                return
            
            # Check if duration exceeds estimated time
            if duration >= estimated_time_seconds:
                duration_hours = round(duration / 3600, 1)
                estimated_hours = round(estimated_time_seconds / 3600, 1)
                
                print(f"  -> ✅ EXCEEDED! Duration {duration_hours}h >= Estimated {estimated_hours}h")
                
                # Send notification
                self._send_time_exceeded_notification(mechanic_id, task_data, device_id, duration)
                
                # Mark as notified in Realtime Database
                self._mark_recording_as_notified(mechanic_id)
                
                print(f"  -> 📱 Notification sent and marked as notified")
            else:
                print(f"  -> Within time limit")
                
        except Exception as e:
            print(f"Error checking task {task_id}: {e}")
            import traceback
            traceback.print_exc()
    
    def _send_time_exceeded_notification(self, mechanic_id: str, task_data: Dict[str, Any], device_id: str, duration: int):
        """Send FCM notification when task exceeds estimated time"""
        try:
            task_id = task_data.get('id', '')
            task_title = task_data.get('title', 'Task')
            estimated_time_seconds = task_data.get('estimatedTime', 0)
            
            # Convert to hours for display
            duration_hours = round(duration / 3600, 1)
            estimated_hours = round(estimated_time_seconds / 3600, 1)
            
            # Get mechanic info
            mechanic_info = self._get_mechanic_info(mechanic_id)
            mechanic_name = mechanic_info.get('name', 'Mechanic') if mechanic_info else 'Mechanic'
            
            # Create notification
            notification = messaging.Notification(
                title="⏰ Task has exceeded estimated time",
                body=f"'{task_title}' has exceeded its estimated time of {estimated_hours}h (current: {duration_hours}h)."
            )
            
            # Create data payload
            data = {
                'mechanicId': mechanic_id,
                'mechanicName': mechanic_name,
                'taskTitle': task_title,
                'estimatedTime': str(estimated_time_seconds),
                'duration': str(duration),
                'estimatedTimeHours': str(estimated_hours),
                'durationHours': str(duration_hours),
                'timestamp': str(int(time.time()))
            }
            
            # Only send FCM if we have a valid device token
            if device_id and not device_id.startswith('device_'):
                # Create message
                message = messaging.Message(
                    notification=notification,
                    data=data,
                    token=device_id
                )
                
                # Send notification
                response = messaging.send(message)
                print(f"FCM notification sent: {response}")
            else:
                print(f"Skipping FCM (invalid token): {device_id}")
            
            # Create notification record in Firestore
            notification_id = self._create_notification_record(
                mechanic_id,
                "⏰ Task Time Exceeded",
                f"'{task_title}' has exceeded its estimated time of {estimated_hours}h (current: {duration_hours}h).",
                'task_time_exceeded',
                task_id  # Include task_id for reference
            )
            
            print(f"  -> 📱 Notification sent and marked as notified")
            
        except Exception as e:
            print(f"Error sending time exceeded notification: {e}")
    
    def _mark_recording_as_notified(self, mechanic_id: str):
        """Mark recording as notified in Realtime Database"""
        try:
            self.db_ref.child(mechanic_id).child('isNotified').set(True)
            
        except Exception as e:
            print(f"Error marking recording {mechanic_id} as notified: {e}")
    
    def _mark_task_as_notified(self, task_id: str):
        """Mark task as notified in Firestore"""
        try:
            self.firestore_client.collection('tasks').document(task_id).update({
                'isNotified': True,
                'notifiedAt': datetime.now()
            })
            
        except Exception as e:
            print(f"Error marking task {task_id} as notified: {e}")
    
    def _create_notification_record(self, mechanic_id: str, title: str, message: str, notification_type: str, task_id: str = ''):
        """Create a notification record in Firestore with document ID included"""
        try:
            # Generate a new document reference to get the ID
            doc_ref = self.firestore_client.collection('notifications').document()
            notification_id = doc_ref.id
            
            notification_data = {
                'id': notification_id,  # Include the document ID in the data
                'mechanicId': mechanic_id,
                'title': title,
                'message': message,
                'created': datetime.now(),
                'type': notification_type
            }
            
            # If task_id is provided, include it
            if task_id:
                notification_data['taskId'] = task_id
            
            # Set the document with the generated ID
            doc_ref.set(notification_data)
            print(f"Notification record created for mechanic {mechanic_id}")
            print(f"  -> Notification ID: {notification_id}")
            
            return notification_id
            
        except Exception as e:
            print(f"Error creating notification record: {e}")
            return None
    
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
        try:
            # Count total active tasks
            active_tasks = (self.firestore_client.collection('tasks')
                          .where('status', '==', 'inProgress')
                          .get())
            
            # Count tasks that might need notification (manually check since compound queries are limited)
            pending_count = 0
            for task_doc in active_tasks:
                task_data = task_doc.to_dict()
                is_notified = task_data.get('isNotified', False)
                if not is_notified:
                    pending_count += 1
            
            return {
                'monitoring_status': self.monitoring,
                'check_interval': self.check_interval,
                'active_tasks': len(active_tasks),
                'pending_notifications': pending_count
            }
        except Exception as e:
            print(f"Error getting statistics: {e}")
            return {
                'monitoring_status': self.monitoring,
                'check_interval': self.check_interval,
                'error': str(e)
            }

def main():
    """Main function to run the task notification service"""
    print("Starting MechLink Task Notification Service...")
    
    try:
        # Create and start the notification service
        service = TaskNotificationService()
        service.start_monitoring()
        
        print("Task notification service started successfully. Press Ctrl+C to stop.")
        
        # Keep the service running
        while True:
            time.sleep(300)  # Print stats every 5 minutes
            stats = service.get_statistics()
            print(f"Task notification stats: {stats}")
            
    except KeyboardInterrupt:
        print("Received shutdown signal...")
        service.stop_monitoring()
        print("Task notification service stopped gracefully")
    except Exception as e:
        print(f"Service error: {e}")
        if 'service' in locals():
            service.stop_monitoring()

if __name__ == "__main__":
    main()
