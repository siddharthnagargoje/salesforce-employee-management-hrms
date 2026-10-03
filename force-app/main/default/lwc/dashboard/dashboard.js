import { LightningElement, track, wire } from 'lwc';
import getEmployees        from '@salesforce/apex/EmployeeController.getEmployees';
import getAttendanceList   from '@salesforce/apex/AttendanceController.getAttendanceList';
import getLeaveRequests    from '@salesforce/apex/LeaveController.getLeaveRequests';
import getPayslips         from '@salesforce/apex/PayrollController.getPayslips';

export default class Dashboard extends LightningElement {

    // ─── Navigation ───────────────────────────────────────────────────────────
    @track currentPage = 'dashboard';

    get isDashboard()  { return this.currentPage === 'dashboard';  }
    get isEmployees()  { return this.currentPage === 'employees';  }
    get isAttendance() { return this.currentPage === 'attendance'; }
    get isLeave()      { return this.currentPage === 'leave';      }
    get isReports()    { return this.currentPage === 'reports';    }
    get isSettings()   { return this.currentPage === 'settings';   }
    get isPayslip()    { return this.currentPage === 'payslip';    }

    handleNavigation(event) {
        this.currentPage = event.detail.page;
    }

    handleToggleSidebar() {}

    navigateToEmployees() { this.currentPage = 'employees'; }
    navigateToPayslip()   { this.currentPage = 'payslip';   }
    navigateToLeave()     { this.currentPage = 'leave';      }

    // ─── KPI: Employees ───────────────────────────────────────────────────────
    @track totalEmployees      = '0';
    @track employeeGrowthTrend = '+0%';
    @track attendancePercent   = '0%';

    @wire(getEmployees)
    wiredEmployees({ data, error }) {
        if (data) {
            const active = data.filter(e => e.Status__c === 'Active');
            this.totalEmployees      = active.length.toString();
            this.employeeGrowthTrend = '+2.4%';
        } else if (error) {
            this.totalEmployees = '0';
            console.error('getEmployees error:', error);
        }
    }

    // ─── KPI: Payroll ─────────────────────────────────────────────────────────
    @track totalPayrollDisplay = '\u20B90';

    @wire(getPayslips)
    wiredPayslips({ data, error }) {
        if (data) {
            const total = data.reduce((sum, p) => sum + (p.Net_Pay__c || 0), 0);
            this.totalPayrollDisplay = '\u20B9' + Math.round(total).toLocaleString('en-IN');
        } else if (error) {
            this.totalPayrollDisplay = '\u20B90';
            console.error('getPayslips error:', error);
        }
    }

    // ─── Attendance Logs ──────────────────────────────────────────────────────
    @track attendanceLogs = [];

    get hasNoAttendanceLogs() {
        return !this.attendanceLogs || this.attendanceLogs.length === 0;
    }

    @wire(getAttendanceList)
    wiredAttendance({ data, error }) {
        if (data) {
            const today = new Date().toDateString();
            const todayLogs = data.filter(a => {
                if (!a.Attendance_Date__c) return false;
                return new Date(a.Attendance_Date__c).toDateString() === today;
            });

            this.attendanceLogs = todayLogs.slice(0, 10).map(log => ({
                id:          log.Id,
                name:        log.Employee__r ? log.Employee__r.Name : '—',
                initials:    this._initials(log.Employee__r ? log.Employee__r.Name : ''),
                checkIn:     log.Check_In_Time__c
                                 ? new Date(log.Check_In_Time__c).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })
                                 : '—',
                statusLabel: log.Status__c || 'Present',
                statusClass: (log.Status__c === 'Present' || log.Status__c === 'On Time')
                                 ? 'attendance-status status-on-time'
                                 : 'attendance-status status-late'
            }));

            const present  = todayLogs.filter(l => l.Status__c === 'Present' || l.Status__c === 'On Time').length;
            const total    = todayLogs.length || 1;
            const pct      = Math.round((present / total) * 100);
            this.attendancePercent = pct + '%';
        } else if (error) {
            this.attendanceLogs    = [];
            this.attendancePercent = '0%';
            console.error('getAttendanceList error:', error);
        }
    }

    // ─── Pending Leave Requests ───────────────────────────────────────────────
    @track pendingRequests = [];

    get pendingRequestsCount() { return this.pendingRequests.length; }
    get hasNoPendingRequests()  { return this.pendingRequests.length === 0; }

    @wire(getLeaveRequests)
    wiredLeaveRequests({ data, error }) {
        if (data) {
            this.pendingRequests = data
                .filter(req => req.Status__c === 'Pending')
                .slice(0, 5)
                .map(req => ({
                    id:        req.Id,
                    employee:  req.Employee__r ? req.Employee__r.Name : '—',
                    type:      req.Leave_Type__c || 'Leave',
                    typeClass: req.Leave_Type__c === 'Emergency' || req.Leave_Type__c === 'Sick'
                                   ? 'request-type type-danger'
                                   : 'request-type type-warning',
                    details:   (req.Start_Date__c || '') + (req.End_Date__c ? ' \u2192 ' + req.End_Date__c : '')
                }));
        } else if (error) {
            this.pendingRequests = [];
            console.error('getLeaveRequests error:', error);
        }
    }

    // ─── Helper ───────────────────────────────────────────────────────────────
    _initials(name) {
        if (!name) return '?';
        const parts = name.trim().split(' ');
        return parts.length >= 2
            ? (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
            : name.substring(0, 2).toUpperCase();
    }
}
