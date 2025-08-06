Avsar App is a corporate mobile application designed to enable employees to securely, quickly, and efficiently access department-specific files, while providing managers with powerful tools for user management, internal communication, and file change tracking.

Department-Based File Access:
Users can only view and open folders assigned to their own department.
Files can be opened directly within the app for quick review without unnecessary downloads.

Real-Time Automatic Notification System:
Any addition, deletion, or modification to shared folders is detected instantly.
Managers receive real-time notifications when a change occurs.
Tapping a notification takes the user directly to the file, allowing immediate review of the changes.

Direct Messaging & Targeted Notifications:
Managers can send topic-based or user-specific messages and notifications.
Employees can view these in the "My Notifications" screen, check details, and reply if necessary.

User & Role Management:
Managers can add, update, or remove user accounts and change user roles directly from the application.
Roles automatically define department-based access permissions.

Technical Stack:

Mobile Application: Flutter (Dart)

Backend API: Python FastAPI

Database: PostgreSQL

Real-Time File Monitoring: Python watchdog library

Notification System: Firebase Cloud Messaging (FCM)

Authentication & Authorization: JWT-based session management

Secure Data Storage: .env environment variables, flutter_secure_storage for sensitive data

Server Location:
The backend services and file monitoring system run on the company’s main server machine.
All file access and API requests are restricted to the internal company network (192.168.x.x),
ensuring the system is fully protected and inaccessible from outside.
