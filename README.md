Workflow:
The app starts from login page, then mechanic login to enter dashboard, it will then show a bottom navigation (4 buttons Dashboard, Job, Note, Profile)
1. Dashboard page has some simple data analysis
2. Job page has list of Job
3. Note page has list of written notes (Pending)
4. Profile page has account information

1. In the Job page, it has searching, filtering, sorting features.
2. When a job is clicked, it will eneter Job detail page. 
3. Job detail page is where Mechanic can accept the job. It has a button to enter customer details page. It has a button to enter service history page. It has a button to enter Task page.
3.1. Customer details page will show the particular customer details.
3.2. Service history page will show all the service request, job, tasks made to this particular vehicle/equipment id.
3.3. Task page will show all the tasks allocated by the manager mechanics to this particular job id.
3.3.1 Task page has left/right button to go to previous/next task
3.3.2 Task page has a start, pause, continue, stop button to record the time the task start, end, and its duration.
3.3.3 Task page has a section for mechanic to write note (Can write text and upload image) linked to current task
4. After the user Accepted the Job, it will show note button. Clicking note will enter the note list page to display note linked to this jobid only or taskid under this jobid.
5. After mechanic has finished the all the tasks, the job detail page will show a complete job button
6. Clicking the complete job button will enter a signoff page
7. Signoff page has a section for customers to signoff on the screen
8. It has a complete button in Signoff page to complete the job

IMPORTANT Instruction:
Think longer for better response, focus on FUNCTIONS and LOGICS only, 0% and no UI
Access the data via firestore by referring the firestore-collection-data folder instead of using the model folders, you must refer to how they are named and linked between data inside the example data from firestore-collection-data folders

When the app first started, it will open up init screen page, in this page, it has 2 button "Load data" and "Skipped", the Load Data button will remove all the data in the firestore database, then it will loop through all the json file in fire-collections-data folder to save each of the data to the firestore database. Skipped button will proceed to login page. In main.dart, put a variable, if the variable is true then enter this init page else directly skipped it and enter login page