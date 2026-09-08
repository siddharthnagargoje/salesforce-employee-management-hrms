import { LightningElement, wire, track } from 'lwc';

import getEmployees from '@salesforce/apex/EmployeeController.getEmployees';
import getAttendanceList from '@salesforce/apex/EmployeeController.getAttendanceList';
import getLeaveRequests from '@salesforce/apex/EmployeeController.getLeaveRequests';

export default class Dashboard extends LightningElement {
    @track currentPage = 'dashboard';
    @track totalEmployees = 0;
    @track totalPayrollSum = 0;
    @track attendanceLogs = [];
    @track pendingRequests = [];
    @track attendancePercent = '0%';
    @track employeeGrowthTrend = '';

    @wire(getEmployees)
    wiredEmployees({ error, data }) {
        if (data) {
            this.totalEmployees = data.length;

            this.totalPayrollSum = data.reduce((sum, employee) => {
                return sum + (parseFloat(employee.Salary__c) || 0);
            }, 0);

            this.employeeGrowthTrend =
                `↑ ${Math.floor((data.length / 10) * 100)}% vs last month`;
        } else if (error) {
            console.error('Error loading employees:', error);
            this.totalEmployees = 0;
            this.totalPayrollSum = 0;
        }
    }

    @wire(getAttendanceList)
    wiredAttendance({ error, data }) {
        if (data) {
            this.attendanceLogs = data.map((log) => {
                const employeeName = log.Employee__r
                    ? log.Employee__r.Name
                    : 'Unknown Employee';

                const status = log.Status__c || 'Not Marked';

                return {
                    id: log.Id,
                    name: employeeName,
                    initials: this.getInitials(employeeName),
                    checkIn: log.Check_In__c
                        ? new Date(log.Check_In__c).toLocaleTimeString(
                            'en-IN',
                            {
                                hour: '2-digit',
                                minute: '2-digit'
                            }
                        )
                        : '--',
                    statusLabel: status,
                    statusClass:
                        status === 'Present'
                            ? 'attendance-status status-on-time'
                            : 'attendance-status status-late'
                };
            });

            const presentCount = this.attendanceLogs.filter(
                (log) => log.statusLabel === 'Present'
            ).length;

            this.attendancePercent = this.attendanceLogs.length
                ? `${Math.round(
                    (presentCount / this.attendanceLogs.length) * 100
                )}%`
                : '0%';
        } else if (error) {
            console.error('Error loading attendance:', error);
            this.attendanceLogs = [];
            this.attendancePercent = '0%';
        }
    }

    @wire(getLeaveRequests)
    wiredRequests({ error, data }) {
        if (data) {
            this.pendingRequests = data
                .filter((request) => request.Status__c === 'Pending')
                .map((request) => {
                    const leaveType = request.Leave_Type__c || 'Request';

                    return {
                        id: request.Id,
                        employee: request.Employee__r
                            ? request.Employee__r.Name
                            : 'Unknown Employee',
                        type: leaveType,
                        details:
                            `${request.Start_Date__c} - ` +
                            `${request.End_Date__c}`,
                        typeClass:
                            leaveType === 'Sick Leave'
                                ? 'request-type type-danger'
                                : 'request-type type-warning'
                    };
                });
        } else if (error) {
            console.error('Error loading requests:', error);
            this.pendingRequests = [];
        }
    }

    getInitials(name) {
        if (!name) {
            return '--';
        }

        const parts = name.trim().split(' ');

        const first = parts[0]
            ? parts[0].charAt(0)
            : '';

        const last = parts.length > 1
            ? parts[parts.length - 1].charAt(0)
            : '';

        return `${first}${last}`.toUpperCase();
    }

    get totalPayrollDisplay() {
        return `₹${this.totalPayrollSum.toLocaleString('en-IN', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        })}`;
    }

    renderedCallback() {
        const donutEl = this.template.querySelector('.donut-chart');
        if (donutEl) {
            const percentage = parseInt(this.attendancePercent, 10) || 0;
            donutEl.style.setProperty('--attendance-progress', `${percentage}%`);
        }
    }

    get pendingRequestsCount() {
        return this.pendingRequests ? this.pendingRequests.length : 0;
    }

    get hasNoPendingRequests() {
        return this.pendingRequests.length === 0;
    }

    get hasNoAttendanceLogs() {
        return !this.attendanceLogs || this.attendanceLogs.length === 0;
    }

    handleNavigation(event) {
        const targetPage = event.detail.toLowerCase().trim();

        const pageMap = {
            dashboard: 'dashboard',
            employees: 'employees',
            employee: 'employees',
            attendance: 'attendance',
            attendances: 'attendance',
            leave: 'leave',
            leaves: 'leave',
            reports: 'reports',
            report: 'reports',
            settings: 'settings',
            setting: 'settings',
            payslip: 'payslip',
            payslips: 'payslip'
        };

        this.currentPage = pageMap[targetPage] || 'dashboard';
    }

    handleToggleSidebar(event) {
        this.isSidebarCollapsed = event.detail.isCollapsed;
    }

    navigateToEmployees() {
        this.currentPage = 'employees';
    }

    navigateToPayslip() {
        this.currentPage = 'payslip';
    }

    navigateToLeave() {
        this.currentPage = 'leave';
    }

    get isDashboard() {
        return this.currentPage === 'dashboard';
    }

    get isEmployees() {
        return this.currentPage === 'employees';
    }

    get isAttendance() {
        return this.currentPage === 'attendance';
    }

    get isLeave() {
        return this.currentPage === 'leave';
    }

    get isReports() {
        return this.currentPage === 'reports';
    }

    get isSettings() {
        return this.currentPage === 'settings';
    }

    get isPayslip() {
        return this.currentPage === 'payslip';
    }
}