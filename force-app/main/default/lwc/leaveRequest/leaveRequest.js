import { LightningElement, wire, track } from 'lwc';
import getEmployees from '@salesforce/apex/EmployeeController.getEmployees';
import getUsers from '@salesforce/apex/LeaveController.getUsers';
import createLeaveRequest from '@salesforce/apex/LeaveController.createLeaveRequest';
import getLeaveRequests from '@salesforce/apex/LeaveController.getLeaveRequests';
import updateLeaveStatus from '@salesforce/apex/LeaveController.updateLeaveStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

const ROW_ACTIONS = [
    { label: 'Approve Request', name: 'approve', iconName: 'utility:check' },
    { label: 'Reject Request', name: 'reject', iconName: 'utility:close' }
];

export default class LeaveManagement extends LightningElement {
    @track employeeOptions = [];
    @track userOptions = [];
    @track leaveList = [];
    @track isModalOpen = false;
    @track isLoading = false;

    // Form fields
    employeeId = '';
    approvedBy = '';
    appliedDate = '';
    startDate = '';
    endDate = '';
    leaveType = '';
    status = '';
    reason = '';
    totalDays = '';

    // Review Modal state
    @track isReviewModalOpen = false;
    selectedLeaveId = '';
    selectedLeaveEmployee = '';
    reviewTargetStatus = '';
    reviewComments = '';

    leaveTypeOptions = [
        { label: 'Casual Leave', value: 'Casual Leave' },
        { label: 'Sick Leave', value: 'Sick Leave' },
        { label: 'Paid Leave', value: 'Paid Leave' },
        { label: 'Loss Of Pay', value: 'Loss Of Pay' },
        { label: 'Work From Home', value: 'Work From Home' }
    ];

    statusOptions = [
        { label: 'Pending', value: 'Pending' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Rejected', value: 'Rejected' }
    ];

    columns = [
        { label: 'Name(s)', fieldName: 'EmployeeName', type: 'text', cellAttributes: { class: 'font-weight-medium' } },
        { label: 'Applied Date', fieldName: 'Applied_Date__c', type: 'date' },
        { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date' },
        { label: 'End Date', fieldName: 'End_Date__c', type: 'date' },
        { label: 'Type', fieldName: 'Leave_Type__c', type: 'text' },
        { label: 'Reason(s)', fieldName: 'Reason__c', type: 'text' },
        { label: 'Status', fieldName: 'Status__c', type: 'text', cellAttributes: { class: 'status-text-weight' } },
        {
            type: 'action',
            typeAttributes: { rowActions: ROW_ACTIONS }
        }
    ];

    wiredLeaveResult;

    connectedCallback() {
        this.setToday();
    }

    @wire(getEmployees)
    wiredEmployeeList({ data, error }) {
        if (data) {
            this.employeeOptions = data.map(emp => ({ label: emp.Name, value: emp.Id }));
        } else if (error) {
            this.showToast('Error', 'Unable to load employees.', 'error');
        }
    }

    @wire(getUsers)
    wiredUserList({ data, error }) {
        if (data) {
            this.userOptions = data.map(user => ({ label: user.Name, value: user.Id }));
        } else if (error) {
            this.showToast('Error', 'Unable to load users.', 'error');
        }
    }

    @wire(getLeaveRequests)
    wiredLeaveRequests(result) {
        this.wiredLeaveResult = result;
        const { data, error } = result;
        if (data) {
            this.leaveList = data.map(lr => ({
                ...lr,
                EmployeeName: lr.Employee__r ? lr.Employee__r.Name : ''
            }));
        } else if (error) {
            this.showToast('Error', 'Unable to load leave requests.', 'error');
        }
    }

    openFormModal() {
        this.isModalOpen = true;
    }

    closeFormModal() {
        this.isModalOpen = false;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        this.selectedLeaveId = row.Id;
        this.selectedLeaveEmployee = row.EmployeeName || 'Employee';
        this.reviewComments = '';

        if (actionName === 'approve') {
            this.reviewTargetStatus = 'Approved';
            this.isReviewModalOpen = true;
        } else if (actionName === 'reject') {
            this.reviewTargetStatus = 'Rejected';
            this.isReviewModalOpen = true;
        }
    }

    closeReviewModal() {
        this.isReviewModalOpen = false;
        this.selectedLeaveId = '';
        this.selectedLeaveEmployee = '';
        this.reviewTargetStatus = '';
        this.reviewComments = '';
    }

    handleReviewCommentsChange(event) {
        this.reviewComments = event.target.value;
    }

    get reviewModalTitle() {
        return `${this.reviewTargetStatus} Leave Request`;
    }

    get reviewActionIcon() {
        return this.reviewTargetStatus === 'Approved' ? 'action:approval' : 'action:reject';
    }

    get confirmReviewButtonLabel() {
        return `Confirm ${this.reviewTargetStatus}`;
    }

    get reviewConfirmVariant() {
        return this.reviewTargetStatus === 'Approved' ? 'brand' : 'destructive';
    }

    async submitLeaveReview() {
        if (!this.selectedLeaveId || !this.reviewTargetStatus) {
            return;
        }

        this.isLoading = true;
        try {
            await updateLeaveStatus({
                leaveId: this.selectedLeaveId,
                status: this.reviewTargetStatus,
                comments: this.reviewComments
            });
            this.showToast('Success', `Leave request has been ${this.reviewTargetStatus.toLowerCase()}.`, 'success');
            this.closeReviewModal();
            await refreshApex(this.wiredLeaveResult);
        } catch (error) {
            this.showToast('Error', 'Failed to update leave status: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleQuickApply(event) {
        const selectedType = event.currentTarget.dataset.type;
        this.leaveType = selectedType;
        this.status = 'Pending';
        this.openFormModal();
    }

    setToday() {
        const today = new Date().toISOString().split('T')[0];
        this.appliedDate = today;
        this.startDate = today;
        this.endDate = today;
        this.calculateTotalDays();
    }

    handleEmployeeChange(event) { this.employeeId = event.detail.value; }
    handleApprovedByChange(event) { this.approvedBy = event.detail.value; }
    handleAppliedDateChange(event) { this.appliedDate = event.detail.value; }
    handleStartDateChange(event) { this.startDate = event.detail.value; this.calculateTotalDays(); }
    handleEndDateChange(event) { this.endDate = event.detail.value; this.calculateTotalDays(); }
    handleLeaveTypeChange(event) { this.leaveType = event.detail.value; }
    handleStatusChange(event) { this.status = event.detail.value; }
    handleReasonChange(event) { this.reason = event.detail.value; }

    calculateTotalDays() {
        if (this.startDate && this.endDate) {
            const start = new Date(this.startDate);
            const end = new Date(this.endDate);
            if (!isNaN(start) && !isNaN(end) && end >= start) {
                const diffTime = end.getTime() - start.getTime();
                this.totalDays = Math.floor(diffTime / (1000 * 60 * 60 * 24)) + 1;
                return;
            }
        }
        this.totalDays = '';
    }

    saveLeaveRequest() {
        if (!this.employeeId || !this.appliedDate || !this.startDate || !this.endDate || !this.leaveType || !this.status || !this.reason) {
            this.showToast('Warning', 'Please fill all required field forms.', 'error');
            return;
        }
        if (this.endDate < this.startDate) {
            this.showToast('Validation Error', 'End Date cannot be verified before Start Date.', 'error');
            return;
        }

        this.isLoading = true;
        createLeaveRequest({
            employeeId: this.employeeId,
            appliedDate: this.appliedDate,
            approvedById: this.approvedBy,
            startDate: this.startDate,
            endDate: this.endDate,
            leaveType: this.leaveType,
            reason: this.reason,
            status: this.status
        })
        .then(() => {
            this.showToast('Success', 'Leave application submitted successfully.', 'success');
            this.resetForm();
            this.closeFormModal();
            return refreshApex(this.wiredLeaveResult);
        })
        .catch(error => {
            const message = error?.body?.message || 'Transaction failed.';
            this.showToast('Error', message, 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    resetForm() {
        this.employeeId = '';
        this.approvedBy = '';
        this.setToday();
        this.leaveType = '';
        this.status = '';
        this.reason = '';
        this.calculateTotalDays();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}