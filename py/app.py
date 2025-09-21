# app.py
import multiprocessing
import task_notification_service
import task_monitoring_service

if __name__ == "__main__":
    p1 = multiprocessing.Process(target=task_notification_service.main)
    p2 = multiprocessing.Process(target=task_monitoring_service.main)

    p1.start()
    p2.start()

    p1.join()
    p2.join()
