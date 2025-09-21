// Job Statistics Overview (FEASIBLE - JobStatus enum)
const Text(
'Job Statistics',
style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
),
Text('Total Jobs: 1'),
Text('Assigned Jobs: 1'),
Text('Accepted Jobs: 1'),
Text('In Progress Jobs: 1'),
Text('Completed Jobs: 1'),
Text('On Hold Jobs: 3'),
Text('Cancelled Jobs: 2'),

// Job Priority Distribution (FEASIBLE - Priority enum)
const Text(
'Priority Distribution',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text(' High Priority: 18 jobs (38%)'),
Text('🟡 Medium Priority: 21 jobs (45%)'),
Text('🟢 Low Priority: 8 jobs (17%)'),

// Service Type Analysis (FEASIBLE - ServiceType enum)
const Text(
'Service Type Breakdown',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('🚗 Vehicle Services: 32 jobs (68%)'),
Text('🚜 Equipment Services: 15 jobs (32%)'),

// Time Performance (FEASIBLE - estimatedDuration vs actualDuration)
const Text(
'Time Performance Metrics',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Total Estimated Hours: 148.5 hours'),
Text('Total Actual Hours: 156.5 hours'),
Text('Time Variance: +8.0 hours (+5.4%)'),
Text('Average Job Duration: 3.3 hours'),
Text('Jobs Completed Within Estimate: 18/27 (67%)'),
Text('Jobs Over Estimate: 9/27 (33%)'),

// Cost Analysis (FEASIBLE - estimatedCost vs actualCost)
const Text(
'Cost Analysis',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Total Estimated Cost: \$22,450'),
Text('Total Actual Cost: \$23,120'),
Text('Cost Variance: +\$670 (+3.0%)'),
Text('Average Job Cost: \$491'),
Text('Jobs Under Budget: 15/27 (56%)'),
Text('Jobs Over Budget: 12/27 (44%)'),

// Task Analytics (FEASIBLE - TaskStatus enum)
const Text(
'Task Performance',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Total Tasks: 142'),
Text('Completed Tasks: 98 (69%)'),
Text('In Progress Tasks: 23 (16%)'),
Text('Pending Tasks: 21 (15%)'),
Text('Average Task Estimated Time: 1.6 hours'),
Text('Average Task Actual Time: 1.8 hours'),
Text('Task Time Variance: +0.2 hours (+12.5%)'),

// Date-based Analytics (FEASIBLE - assignedAt, startedAt, completedAt)
const Text(
'Timeline Analytics',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Average Time from Assigned to Started: 1.2 days'),
Text('Average Time from Started to Completed: 2.8 days'),
Text('Jobs Started Today: 3'),
Text('Jobs Completed Today: 2'),
Text('Jobs Assigned This Week: 8'),
Text('Jobs Completed This Week: 12'),

// Notes Analytics (FEASIBLE - NoteType and NoteStatus enums)
const Text(
'Notes & Issues Analysis',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Total Notes: 89'),
Text('🔴 Problem Notes: 34 (38%)'),
Text('📋 Request Notes: 28 (31%)'),
Text('✅ Completion Notes: 27 (31%)'),
Text('Pending Note Issues: 8'),
Text('Solved Note Issues: 31'),
Text('Completed Note Items: 27'),
Text('Note Resolution Rate: 87%'),

// Parts Analysis (FEASIBLE - parts list from Job)
const Text(
'Parts Usage',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Most Frequently Used Parts:'),
Text('1. Brake Pads: 24 jobs'),
Text('2. Oil Filter: 18 jobs'),
Text('3. Hydraulic Oil: 15 jobs'),
Text('4. Spark Plugs: 12 jobs'),
Text('5. Air Filter: 10 jobs'),
Text('Total Part Types Used: 47'),
Text('Average Parts per Job: 3.2'),

// Vehicle Analytics (FEASIBLE - Vehicle model attributes)
const Text(
'Vehicle Analysis',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Total Vehicles Serviced: 28'),
Text(
'Vehicle Makes: Toyota (8), Ford (6), Honda (5), Chevrolet (4), Others (5)',
),
Text('Average Vehicle Year: 2017'),
Text('Oldest Vehicle: 2009'),
Text('Newest Vehicle: 2024'),
Text('Average Mileage: 67,500 miles'),

// Equipment Analytics (FEASIBLE - Equipment model attributes)
const Text(
'Equipment Analysis',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Total Equipment Serviced: 15'),
Text(
'Equipment Categories: Heavy Machinery (8), Tools (4), Diagnostic (3)',
),
Text(
'Equipment Conditions: Excellent (2), Good (8), Fair (4), Poor (1)',
),
Text('Average Equipment Year: 2019'),
Text(
'Equipment Manufacturers: Caterpillar (5), Komatsu (3), Others (7)',
),

// Customer Analytics (FEASIBLE - Customer model and job relationships)
const Text(
'Customer Insights',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Total Active Customers: 23'),
Text('Customers with Multiple Jobs: 18'),
Text('New Customers This Month: 5'),
Text('Average Jobs per Customer: 2.0'),
Text('Most Active Customer: 7 jobs'),
Text('Customer Retention (repeat jobs): 78%'),

// Mechanic Performance (FEASIBLE - mechanicId relationships)
const Text(
'Mechanic Performance',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Jobs Assigned to Current Mechanic: 15'),
Text('Jobs Completed by Current Mechanic: 12'),
Text('Current Mechanic Efficiency: 94%'),
Text(
'Current Mechanic Specialization: ${_authService.currentMechanic?['specialization'] ?? 'N/A'}',
),
Text(
'Current Mechanic Department: ${_authService.currentMechanic?['department'] ?? 'N/A'}',
),

// Specialization Analysis (FEASIBLE - Mechanic.specialization)
const Text(
'Specialization Distribution',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Brake Systems & Engine Diagnostics: 12 jobs'),
Text('Heavy Machinery & Hydraulics: 8 jobs'),
Text('Electrical Systems: 7 jobs'),
Text('Transmission & Drivetrain: 6 jobs'),
Text('General Automotive: 5 jobs'),

// Weekly Workload (FEASIBLE - based on job dates)
const Text(
'Weekly Workload Distribution',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Monday: ████████ 8.2 hours (4 jobs)'),
Text('Tuesday: ██████ 6.5 hours (3 jobs)'),
Text('Wednesday: ██████████ 9.1 hours (5 jobs)'),
Text('Thursday: ███████ 7.3 hours (3 jobs)'),
Text('Friday: █████████ 8.8 hours (4 jobs)'),
Text('Weekend: ██ 2.1 hours (1 emergency)'),

// Digital Signoff Analytics (FEASIBLE - digitalSignOff field)
const Text(
'Digital Signoff Status',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Jobs with Digital Signoff: 25/27 (93%)'),
Text('Jobs Pending Signoff: 2'),
Text('Average Days to Signoff: 0.8 days'),
Text('Signoff Completion Rate: 93%'),

// Job Title Analysis (FEASIBLE - Job.title field)
const Text(
'Common Job Types',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Brake System Work: 12 jobs'),
Text('Engine Diagnostics: 8 jobs'),
Text('Oil Change & Maintenance: 7 jobs'),
Text('Hydraulic System Service: 6 jobs'),
Text('Electrical Troubleshooting: 5 jobs'),
Text('Transmission Service: 4 jobs'),

// Task Order Analysis (FEASIBLE - Task.order field)
const Text(
'Task Workflow Analysis',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Average Tasks per Job: 5.3'),
Text('Most Complex Job: 12 tasks'),
Text('Simplest Job: 2 tasks'),
Text('Tasks Completed in Order: 87%'),
Text('Tasks Requiring Rework: 5'),

// Photo Documentation (FEASIBLE - photos fields in Note, Vehicle, Equipment)
const Text(
'Documentation Statistics',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Notes with Photos: 34/89 (38%)'),
Text('Vehicles with Photos: 22/28 (79%)'),
Text('Equipment with Photos: 12/15 (80%)'),
Text('Total Photos in System: 127'),
Text('Average Photos per Documentation: 2.1'),

const SizedBox(height: 20),

// === NEW ANALYTICS FROM PROPOSED MODEL ADDITIONS ===

// Financial Analytics (FEASIBLE - from Mechanic.monthlySalary)
const Text(
'Financial & Labor Cost Analysis',
style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.green,
),
),
Text('Total Monthly Payroll: \$84,500'),
Text('Average Mechanic Salary: \$4,225/month'),
Text('Labor Cost per Hour: \$28.50'),
Text('Total Labor Costs This Month: \$18,720'),
Text('Labor Cost per Job: \$398 average'),
Text('Salary Distribution:'),
Text('  • Senior Mechanics: \$5,200-6,800/month'),
Text('  • Mid-level Mechanics: \$3,800-4,600/month'),
Text('  • Junior Mechanics: \$2,900-3,400/month'),
Text('Labor Cost Efficiency: 84% (vs industry standard)'),
Text('Cost per Completed Job: \$693 (labor + materials)'),

// Salary Performance Correlation (FEASIBLE - salary vs job metrics)
const Text(
'Salary vs Performance Analysis',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('High Salary + High Performance: 8 mechanics'),
Text('High Salary + Low Performance: 2 mechanics'),
Text('Average Salary + High Performance: 6 mechanics'),
Text('Salary vs Efficiency Correlation: +0.73'),
Text('ROI per Mechanic (Revenue/Salary):'),
Text('  • Top Performer: 3.2x ROI'),
Text('  • Average Performer: 2.1x ROI'),
Text('  • Needs Improvement: 1.4x ROI'),

// System Usage Analytics (FEASIBLE - from Mechanic system usage fields)
const Text(
'System Usage & Digital Engagement',
style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.blue,
),
),
Text('Total System Logins This Month: 1,247'),
Text('Average Logins per Mechanic: 62 logins/month'),
Text('Average Session Duration: 4.2 hours'),
Text('Most Active User: 127 logins this month'),
Text('Least Active User: 18 logins this month'),
Text('Peak Usage Hours: 8:00-10:00 AM, 2:00-4:00 PM'),
Text('Mobile App Usage: 78% of sessions'),
Text('Desktop Usage: 22% of sessions'),
Text('Weekend Usage: 12% of total sessions'),

// Digital Adoption Metrics (FEASIBLE - system usage patterns)
const Text(
'Digital Adoption & Engagement',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Daily Active Users: 18/20 mechanics (90%)'),
Text('Weekly Active Users: 20/20 mechanics (100%)'),
Text('Average Days Between Logins: 1.2 days'),
Text('Session Completion Rate: 94%'),
Text('Feature Usage:'),
Text('  • Job Management: 100% of users'),
Text('  • Notes System: 85% of users'),
Text('  • Photo Upload: 72% of users'),
Text('  • Digital Signoff: 68% of users'),

// Usage vs Productivity (FEASIBLE - system usage vs job performance)
const Text(
'Usage vs Productivity Correlation',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('High Usage + High Productivity: 12 mechanics'),
Text('High Usage + Low Productivity: 3 mechanics'),
Text('Low Usage + High Productivity: 2 mechanics'),
Text('System Usage vs Job Completion: +0.68 correlation'),
Text('Session Duration vs Quality: +0.41 correlation'),
Text('Login Frequency vs Customer Ratings: +0.52 correlation'),

// Customer Satisfaction Analytics (FEASIBLE - from Job.customerRating)
const Text(
'Customer Satisfaction & Quality Metrics',
style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.orange,
),
),
Text('Overall Customer Satisfaction: 4.6/5.0 ⭐'),
Text('Total Customer Ratings: 27 jobs rated'),
Text('Rating Distribution:'),
Text('  ⭐⭐⭐⭐⭐ 5 Stars: 15 jobs (56%)'),
Text('  ⭐⭐⭐⭐ 4 Stars: 8 jobs (30%)'),
Text('  ⭐⭐⭐ 3 Stars: 3 jobs (11%)'),
Text('  ⭐⭐ 2 Stars: 1 job (4%)'),
Text('  ⭐ 1 Star: 0 jobs (0%)'),
Text('Customer Satisfaction Trend: +0.3 stars (vs last month)'),

// Satisfaction by Category (FEASIBLE - rating vs job attributes)
const Text(
'Satisfaction by Service Category',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Brake Systems: 4.8/5.0 (12 ratings)'),
Text('Engine Diagnostics: 4.5/5.0 (8 ratings)'),
Text('Hydraulic Systems: 4.4/5.0 (7 ratings)'),
Text('Electrical Systems: 4.7/5.0 (5 ratings)'),
Text('Vehicle Services: 4.7/5.0 (18 ratings)'),
Text('Equipment Services: 4.4/5.0 (9 ratings)'),
Text('Regular Priority Jobs: 4.7/5.0 (23 ratings)'),

// Mechanic Customer Ratings (FEASIBLE - rating by mechanic)
const Text(
'Mechanic Performance Ratings',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Current Mechanic Average: 4.8/5.0 ⭐'),
Text('Top Rated Mechanic: 4.9/5.0'),
Text('Department Average: 4.6/5.0'),
Text('Ratings Above 4.5: 18/20 mechanics (90%)'),
Text('Ratings Below 4.0: 1/20 mechanics (5%)'),
Text('Customer Feedback Response Rate: 87%'),

// Quality vs Time Correlation (FEASIBLE - rating vs job duration)
const Text(
'Quality vs Efficiency Analysis',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Jobs Completed On Time + High Rating: 18/27 (67%)'),
Text('Jobs Over Time + High Rating: 7/27 (26%)'),
Text('Jobs Under Time + Low Rating: 2/27 (7%)'),
Text('Rating vs Completion Time: -0.12 correlation'),
Text('Rating vs Cost Accuracy: +0.34 correlation'),
Text('Quality vs Speed Balance: Optimized'),

// Task Quality Analytics (FEASIBLE - from Task rating/difficulty field)
const Text(
'Task Quality & Complexity Analysis',
style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.purple,
),
),
Text('Average Task Quality Rating: 4.4/5.0'),
Text('Task Difficulty Distribution:'),
Text('  🔴 High Complexity: 23 tasks (16%)'),
Text('  🟡 Medium Complexity: 67 tasks (47%)'),
Text('  🟢 Low Complexity: 52 tasks (37%)'),
Text('Task Quality by Complexity:'),
Text('  • High Complexity Tasks: 4.1/5.0 avg rating'),
Text('  • Medium Complexity Tasks: 4.4/5.0 avg rating'),
Text('  • Low Complexity Tasks: 4.6/5.0 avg rating'),

// Task Performance Analysis (FEASIBLE - task metrics)
const Text(
'Task Performance Insights',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Task Completion Quality: 91%'),
Text('Tasks Requiring Rework: 5 (3.5%)'),
Text('Time vs Complexity Correlation: +0.78'),
Text('Quality vs Complexity Correlation: -0.23'),
Text('Most Challenging Task Type: Engine Diagnostics'),
Text('Highest Quality Task Type: Brake Maintenance'),
Text('Task Satisfaction Improvement: +0.2 (vs last month)'),

// Advanced Cross-Metric Analysis (FEASIBLE - combining all new fields)
const Text(
'Advanced Performance Insights',
style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.red,
),
),
Text('Cost per Satisfied Customer: \$693'),
Text('Revenue per Happy Customer: \$1,247'),
Text('ROI on Customer Satisfaction: 180%'),
Text('High Salary + High Ratings: Strong correlation (+0.67)'),
Text('System Usage + Customer Satisfaction: +0.52 correlation'),
Text('Digital Engagement Impact: +12% customer ratings'),
Text('Quality Improvement ROI: 240% return'),

// Department Performance Summary (FEASIBLE - aggregated metrics)
const Text(
'Department Performance Summary',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
Text('Overall Department Efficiency: 87%'),
Text('Cost Efficiency vs Industry: +15% better'),
Text('Customer Satisfaction vs Target: +0.6 stars'),
Text('Digital Adoption Rate: 94%'),
Text('Quality Improvement YoY: +18%'),
Text('Labor Cost Optimization: 12% savings achieved'),
Text('Performance Score: 4.7/5.0 (Excellent)'),