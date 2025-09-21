#!/usr/bin/env python3
"""
MechLink Task Notification Service
Monitors Firestore tasks and sends notifications when tasks exceed estimated time
"""

import time
import threading
from datetime import datetime
from typing import Dict, Any, Optional
import firebase_admin
from firebase_admin import credentials, firestore, messaging

class TaskNotificationService:
    def __init__(self):
        """Initialize the task notification service"""
        self.firebase_app = None
        self.firestore_client = None
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
            
            # Initialize Firestore client
            self.firestore_client = firestore.client()
            
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
                self._check_all_tasks_for_notifications()
                time.sleep(self.check_interval)
            except Exception as e:
                print(f"Error in task notification monitoring loop: {e}")
                time.sleep(self.check_interval)
    
    def _check_all_tasks_for_notifications(self):
        """Check all tasks in Firestore for time exceeded notifications"""
        try:
            # Get all tasks that are inProgress, have estimatedTime, and not yet notified
            tasks_query = (self.firestore_client.collection('tasks')
                          .where('status', '==', 'inProgress')
                          .where('isNotified', '==', False))
            
            tasks = tasks_query.get()
            
            print(f"Checking {len(tasks)} active tasks for time exceeded notifications...")
            
            for task_doc in tasks:
                task_data = task_doc.to_dict()
                task_id = task_doc.id
                task_data['id'] = task_id  # Add document ID to task data
                
                self._check_single_task(task_id, task_data)
                
        except Exception as e:
            print(f"Error checking all tasks for notifications: {e}")
    
    def _check_single_task(self, task_id: str, task_data: Dict[str, Any]):
        """Check a single task for time exceeded notification"""
        try:
            # Extract task information
            task_title = task_data.get('title', 'Unknown Task')
            estimated_time_hours = task_data.get('estimatedTime', 0)  # in hours
            actual_time_seconds = task_data.get('actualTime', 0)  # in seconds
            
            # Skip if no estimated time is set
            if not estimated_time_hours or estimated_time_hours <= 0:
                return
                
            # Skip if no actual time recorded yet
            if not actual_time_seconds or actual_time_seconds <= 0:
                return
            
            estimated_seconds = int(estimated_time_hours * 3600)  # convert hours to seconds
            
            # Check if actual time exceeds estimated time
            if actual_time_seconds >= estimated_seconds:
                actual_time_hours = round(actual_time_seconds / 3600, 1)
                
                print(f"Task '{task_title}' ({task_id}) has exceeded estimated time:")
                print(f"  Estimated: {estimated_time_hours}h | Actual: {actual_time_hours}h")
                
                # Find mechanic and device ID for this task
                mechanic_id, device_id = self._find_mechanic_and_device_for_task(task_id)
                
                if mechanic_id and device_id:
                    # Send notification
                    self._send_time_exceeded_notification(
                        mechanic_id, task_data, device_id, actual_time_seconds
                    )
                    
                    # Mark task as notified
                    self._mark_task_as_notified(task_id)
                    
                    print(f"Notification sent for task {task_id} to mechanic {mechanic_id}")
                else:
                    print(f"Could not find mechanic/device for task {task_id}, skipping notification")
                    
        except Exception as e:
            print(f"Error checking single task {task_id}: {e}")
    
    def _find_mechanic_and_device_for_task(self, task_id: str) -> tuple[Optional[str], Optional[str]]:
        """Find mechanic ID and device ID for a given task"""
        try:
            # Method 1: Check if task has a direct mechanic assignment
            # This would require adding mechanicId to task documents
            
            # Method 2: Find from job assignment
            # Get the task's job and find assigned mechanic
            task_doc = self.firestore_client.collection('tasks').document(task_id).get()
            if not task_doc.exists:
                return None, None
                
            task_data = task_doc.to_dict()
            job_id = task_data.get('jobId')
            
            if job_id:
                job_doc = self.firestore_client.collection('jobs').document(job_id).get()
                if job_doc.exists:
                    job_data = job_doc.to_dict()
                    mechanic_id = job_data.get('assignedMechanicId')
                    
                    if mechanic_id:
                        # Get device ID for this mechanic
                        device_id = self._get_device_id_for_mechanic(mechanic_id)
                        return mechanic_id, device_id
            
            return None, None
            
        except Exception as e:
            print(f"Error finding mechanic for task {task_id}: {e}")
            return None, None
    
    def _get_device_id_for_mechanic(self, mechanic_id: str) -> Optional[str]:
        """Get the most recent device ID for a mechanic"""
        try:
            # Method 1: Check recent login sessions or device registrations
            # For now, we'll use a simple approach - check if there's a device ID pattern
            # In a real implementation, you might store device tokens in Firestore
            
            # Method 2: Generate a device ID pattern (temporary solution)
            # This assumes device IDs follow the pattern from the auth service
            # In production, you'd want to store device tokens properly
            
            # For now, return a placeholder that indicates we need proper device management
            return f"device_{mechanic_id}_notification"
            
        except Exception as e:
            print(f"Error getting device ID for mechanic {mechanic_id}: {e}")
            return None
    
    def _send_time_exceeded_notification(self, mechanic_id: str, task_data: Dict[str, Any], device_id: str, actual_time_seconds: int):
        """Send FCM notification when task exceeds estimated time"""
        try:
            task_id = task_data.get('id', '')
            task_title = task_data.get('title', 'Task')
            estimated_time_hours = task_data.get('estimatedTime', 0)
            
            # Convert actual time to hours for display
            actual_time_hours = round(actual_time_seconds / 3600, 1)
            
            # Get mechanic info
            mechanic_info = self._get_mechanic_info(mechanic_id)
            mechanic_name = mechanic_info.get('name', 'Mechanic') if mechanic_info else 'Mechanic'
            
            # Create notification
            notification = messaging.Notification(
                title="⏰ Task Time Exceeded",
                body=f"'{task_title}' has exceeded its estimated time of {estimated_time_hours}h (current: {actual_time_hours}h)."
            )
            
            # Create data payload
            data = {
                'type': 'task_time_exceeded',
                'taskId': task_id,
                'mechanicId': mechanic_id,
                'mechanicName': mechanic_name,
                'taskTitle': task_title,
                'estimatedTime': str(estimated_time_hours),
                'actualTime': str(actual_time_seconds),
                'actualTimeHours': str(actual_time_hours),
                'timestamp': str(int(time.time()))
            }
            
            # Create message
            message = messaging.Message(
                notification=notification,
                data=data,
                token=device_id
            )
            
            # Send notification
            response = messaging.send(message)
            print(f"Time exceeded notification sent: {response}")
            
            # Create notification record in Firestore
            self._create_notification_record(
                mechanic_id,
                "⏰ Task Time Exceeded",
                f"'{task_title}' has exceeded its estimated time of {estimated_time_hours}h (current: {actual_time_hours}h).",
                'task_time_exceeded',
                task_id
            )
            
        except Exception as e:
            print(f"Error sending time exceeded notification: {e}")
    
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
        """Create a notification record in Firestore"""
        try:
            notification_data = {
                'mechanicId': mechanic_id,
                'title': title,
                'message': message,
                'created': datetime.now(),
                'type': notification_type,
                'taskId': task_id,
                'read': False
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
        try:
            # Count tasks that need notification
            pending_notifications = (self.firestore_client.collection('tasks')
                                   .where('status', '==', 'inProgress')
                                   .where('isNotified', '==', False)
                                   .get())
            
            # Count total active tasks
            active_tasks = (self.firestore_client.collection('tasks')
                          .where('status', '==', 'inProgress')
                          .get())
            
            return {
                'monitoring_status': self.monitoring,
                'check_interval': self.check_interval,
                'active_tasks': len(active_tasks),
                'pending_notifications': len(pending_notifications)
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
