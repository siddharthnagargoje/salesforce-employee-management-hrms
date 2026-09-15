import { LightningElement, wire, track } from 'lwc';
import getSettings from '@salesforce/apex/HRMSSettingsController.getSettings';
import saveSettings from '@salesforce/apex/HRMSSettingsController.saveSettings';
import resetToDefaults from '@salesforce/apex/HRMSSettingsController.resetToDefaults';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class SettingsManagement extends LightningElement {
    // 1. Organization & General
    @track companyName = 'Apex Technologies Corp';
    @track companyEmail = 'hr@apextechnologies.com';
    @track workWeek = '5 Days (Mon-Fri)';
    @track standardWorkHours = 8.0;

    // 2. Attendance & Work
    @track autoCheckout = false;
    @track autoCheckoutTime = '19:00';
    @track overtimeThresholdHours = 9.0;
    @track defaultWorkMode = 'Office';

    // 3. Leaves & Time Off
    @track requireApproval = true;
    @track defaultAnnualLeaves = 20;
    @track defaultSickLeaves = 10;
    @track allowNegativeLeave = false;

    // 4. Payroll & Finance
    @track currencyFormat = 'INR';
    @track payrollCycleDay = '28th of every month';
    @track autoSendPayslips = true;

    // 5. Access & Security
    @track allowAdminDelete = false;
    @track defaultRole = 'Employee';

    // 6. System Preferences
    @track emailNotifications = true;
    @track dateFormat = 'DD/MM/YYYY';
    @track maintenanceMode = false;

    // Navigation & Search State
    @track activeTab = 'all';
    @track searchQuery = '';

    // Save & Modal States
    @track isDirty = false;
    @track isSaving = false;
    @track isResetting = false;
    @track isResetModalOpen = false;

    settingRecordId;
    wiredSettingsResult;
    originalSettings = {};

    connectedCallback() {
        this.keyboardSaveHandler = this.handleKeyDown.bind(this);
        window.addEventListener('keydown', this.keyboardSaveHandler);
    }

    disconnectedCallback() {
        if (this.keyboardSaveHandler) {
            window.removeEventListener('keydown', this.keyboardSaveHandler);
        }
    }

    handleKeyDown(event) {
        if ((event.ctrlKey || event.metaKey) && event.key === 's') {
            event.preventDefault();
            if (this.isDirty && !this.isSaving) {
                this.handleSaveSettings();
            }
        }
    }

    @wire(getSettings)
    wiredSettings(result) {
        this.wiredSettingsResult = result;
        const { data, error } = result;
        if (data) {
            this.loadSettingsData(data);
        } else if (error) {
            this.showToast('Error Loading Settings', error.body?.message || error.message, 'error');
        }
    }

    loadSettingsData(data) {
        this.settingRecordId = data.Id;
        this.companyName = data.Company_Name__c || 'Apex Technologies Corp';
        this.companyEmail = data.Company_Email__c || 'hr@apextechnologies.com';
        this.workWeek = data.Work_Week__c || '5 Days (Mon-Fri)';
        this.standardWorkHours = data.Standard_Work_Hours__c !== undefined && data.Standard_Work_Hours__c !== null ? Number(data.Standard_Work_Hours__c) : 8.0;

        this.autoCheckout = data.Auto_Checkout__c === true;
        this.autoCheckoutTime = data.Auto_Checkout_Time__c || '19:00';
        this.overtimeThresholdHours = data.Overtime_Threshold_Hours__c !== undefined && data.Overtime_Threshold_Hours__c !== null ? Number(data.Overtime_Threshold_Hours__c) : 9.0;
        this.defaultWorkMode = data.Default_Work_Mode__c || 'Office';

        this.requireApproval = data.Require_Approval__c !== false;
        this.defaultAnnualLeaves = data.Default_Annual_Leaves__c !== undefined && data.Default_Annual_Leaves__c !== null ? Number(data.Default_Annual_Leaves__c) : 20;
        this.defaultSickLeaves = data.Default_Sick_Leaves__c !== undefined && data.Default_Sick_Leaves__c !== null ? Number(data.Default_Sick_Leaves__c) : 10;
        this.allowNegativeLeave = data.Allow_Negative_Leave__c === true;

        this.currencyFormat = data.Currency_Format__c || 'INR';
        this.payrollCycleDay = data.Payroll_Cycle_Day__c || '28th of every month';
        this.autoSendPayslips = data.Auto_Send_Payslips__c !== false;

        this.allowAdminDelete = data.Allow_Admin_Delete__c === true;
        this.defaultRole = data.Default_Role__c || 'Employee';

        this.emailNotifications = data.Email_Notifications__c !== false;
        this.dateFormat = data.Date_Format__c || 'DD/MM/YYYY';
        this.maintenanceMode = data.Maintenance_Mode__c === true;

        // Snapshot original data for discard tracking
        this.originalSettings = {
            companyName: this.companyName,
            companyEmail: this.companyEmail,
            workWeek: this.workWeek,
            standardWorkHours: this.standardWorkHours,
            autoCheckout: this.autoCheckout,
            autoCheckoutTime: this.autoCheckoutTime,
            overtimeThresholdHours: this.overtimeThresholdHours,
            defaultWorkMode: this.defaultWorkMode,
            requireApproval: this.requireApproval,
            defaultAnnualLeaves: this.defaultAnnualLeaves,
            defaultSickLeaves: this.defaultSickLeaves,
            allowNegativeLeave: this.allowNegativeLeave,
            currencyFormat: this.currencyFormat,
            payrollCycleDay: this.payrollCycleDay,
            autoSendPayslips: this.autoSendPayslips,
            allowAdminDelete: this.allowAdminDelete,
            defaultRole: this.defaultRole,
            emailNotifications: this.emailNotifications,
            dateFormat: this.dateFormat,
            maintenanceMode: this.maintenanceMode
        };

        this.isDirty = false;
    }

    markAsDirty() {
        this.isDirty = true;
    }

    // --- Tab Navigation Handlers ---
    handleTabChange(event) {
        const tab = event.currentTarget.dataset.tab;
        if (tab) {
            this.activeTab = tab;
        }
    }

    handleKpiOrgClick() {
        this.activeTab = 'org';
    }

    handleKpiAttendanceClick() {
        this.activeTab = 'attendance';
    }

    handleKpiLeavesClick() {
        this.activeTab = 'leaves';
    }

    handleKpiPayrollClick() {
        this.activeTab = 'payroll';
    }

    // --- Search Handler ---
    handleSearchInput(event) {
        this.searchQuery = event.target.value.toLowerCase().trim();
    }

    clearSearch() {
        this.searchQuery = '';
    }

    get hasSearchQuery() {
        return Boolean(this.searchQuery && this.searchQuery.length > 0);
    }

    // --- Form Controls Handlers ---
    // Organization
    handleCompanyNameChange(event) {
        this.companyName = event.target.value;
        this.markAsDirty();
    }

    handleCompanyEmailChange(event) {
        this.companyEmail = event.target.value;
        this.markAsDirty();
    }

    handleWorkWeekChange(event) {
        this.workWeek = event.target.value;
        this.markAsDirty();
    }

    handleStandardWorkHoursChange(event) {
        const val = parseFloat(event.target.value);
        this.standardWorkHours = isNaN(val) ? 8.0 : Math.max(4, Math.min(14, val));
        this.markAsDirty();
    }

    // Attendance
    toggleAutoCheckout() {
        this.autoCheckout = !this.autoCheckout;
        this.markAsDirty();
    }

    handleAutoCheckoutTimeChange(event) {
        this.autoCheckoutTime = event.target.value;
        this.markAsDirty();
    }

    handleOvertimeThresholdChange(event) {
        const val = parseFloat(event.target.value);
        this.overtimeThresholdHours = isNaN(val) ? 9.0 : Math.max(6, Math.min(16, val));
        this.markAsDirty();
    }

    handleDefaultWorkModeChange(event) {
        this.defaultWorkMode = event.target.value;
        this.markAsDirty();
    }

    // Leaves
    toggleApprovalRequired() {
        this.requireApproval = !this.requireApproval;
        this.markAsDirty();
    }

    handleAnnualLeavesChange(event) {
        const val = parseInt(event.target.value, 10);
        this.defaultAnnualLeaves = isNaN(val) ? 20 : Math.max(0, Math.min(60, val));
        this.markAsDirty();
    }

    handleSickLeavesChange(event) {
        const val = parseInt(event.target.value, 10);
        this.defaultSickLeaves = isNaN(val) ? 10 : Math.max(0, Math.min(40, val));
        this.markAsDirty();
    }

    toggleNegativeLeave() {
        this.allowNegativeLeave = !this.allowNegativeLeave;
        this.markAsDirty();
    }

    // Payroll
    handleCurrencyChange(event) {
        this.currencyFormat = event.target.value;
        this.markAsDirty();
    }

    handlePayrollCycleChange(event) {
        this.payrollCycleDay = event.target.value;
        this.markAsDirty();
    }

    toggleAutoSendPayslips() {
        this.autoSendPayslips = !this.autoSendPayslips;
        this.markAsDirty();
    }

    // Security
    toggleAdminDelete() {
        this.allowAdminDelete = !this.allowAdminDelete;
        this.markAsDirty();
    }

    handleDefaultRoleChange(event) {
        this.defaultRole = event.target.value;
        this.markAsDirty();
    }

    // System
    toggleEmailNotifications() {
        this.emailNotifications = !this.emailNotifications;
        this.markAsDirty();
    }

    handleDateFormatChange(event) {
        this.dateFormat = event.target.value;
        this.markAsDirty();
    }

    toggleMaintenanceMode() {
        this.maintenanceMode = !this.maintenanceMode;
        this.markAsDirty();
    }

    // --- Discard Changes ---
    handleDiscardChanges() {
        this.companyName = this.originalSettings.companyName;
        this.companyEmail = this.originalSettings.companyEmail;
        this.workWeek = this.originalSettings.workWeek;
        this.standardWorkHours = this.originalSettings.standardWorkHours;
        this.autoCheckout = this.originalSettings.autoCheckout;
        this.autoCheckoutTime = this.originalSettings.autoCheckoutTime;
        this.overtimeThresholdHours = this.originalSettings.overtimeThresholdHours;
        this.defaultWorkMode = this.originalSettings.defaultWorkMode;
        this.requireApproval = this.originalSettings.requireApproval;
        this.defaultAnnualLeaves = this.originalSettings.defaultAnnualLeaves;
        this.defaultSickLeaves = this.originalSettings.defaultSickLeaves;
        this.allowNegativeLeave = this.originalSettings.allowNegativeLeave;
        this.currencyFormat = this.originalSettings.currencyFormat;
        this.payrollCycleDay = this.originalSettings.payrollCycleDay;
        this.autoSendPayslips = this.originalSettings.autoSendPayslips;
        this.allowAdminDelete = this.originalSettings.allowAdminDelete;
        this.defaultRole = this.originalSettings.defaultRole;
        this.emailNotifications = this.originalSettings.emailNotifications;
        this.dateFormat = this.originalSettings.dateFormat;
        this.maintenanceMode = this.originalSettings.maintenanceMode;
        this.isDirty = false;
        this.showToast('Changes Discarded', 'Settings reverted back to currently loaded values.', 'info');
    }

    // --- Save Settings ---
    async handleSaveSettings() {
        if (!this.isDirty || this.isSaving) {
            return;
        }

        this.isSaving = true;

        const payload = {
            sobjectType: 'HRMS_Setting__c',
            Id: this.settingRecordId,
            Company_Name__c: this.companyName,
            Company_Email__c: this.companyEmail,
            Work_Week__c: this.workWeek,
            Standard_Work_Hours__c: this.standardWorkHours,
            Auto_Checkout__c: this.autoCheckout,
            Auto_Checkout_Time__c: this.autoCheckoutTime,
            Overtime_Threshold_Hours__c: this.overtimeThresholdHours,
            Default_Work_Mode__c: this.defaultWorkMode,
            Require_Approval__c: this.requireApproval,
            Default_Annual_Leaves__c: this.defaultAnnualLeaves,
            Default_Sick_Leaves__c: this.defaultSickLeaves,
            Allow_Negative_Leave__c: this.allowNegativeLeave,
            Currency_Format__c: this.currencyFormat,
            Payroll_Cycle_Day__c: this.payrollCycleDay,
            Auto_Send_Payslips__c: this.autoSendPayslips,
            Allow_Admin_Delete__c: this.allowAdminDelete,
            Default_Role__c: this.defaultRole,
            Email_Notifications__c: this.emailNotifications,
            Date_Format__c: this.dateFormat,
            Maintenance_Mode__c: this.maintenanceMode
        };

        try {
            const saved = await saveSettings({ config: payload });
            this.settingRecordId = saved.Id;
            this.isDirty = false;
            this.loadSettingsData(saved);
            this.showToast('Settings Saved', 'HRMS configuration successfully updated across all modules.', 'success');
            await refreshApex(this.wiredSettingsResult);
        } catch (error) {
            this.showToast('Save Failed', error.body?.message || error.message, 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // --- Reset Modal Handlers ---
    openResetModal() {
        this.isResetModalOpen = true;
    }

    closeResetModal() {
        this.isResetModalOpen = false;
    }

    async handleConfirmReset() {
        this.isResetting = true;
        try {
            const resetResult = await resetToDefaults();
            this.loadSettingsData(resetResult);
            this.closeResetModal();
            this.showToast('Defaults Restored', 'All HRMS policies have been reset to factory baseline.', 'success');
            await refreshApex(this.wiredSettingsResult);
        } catch (error) {
            this.showToast('Reset Failed', error.body?.message || error.message, 'error');
        } finally {
            this.isResetting = false;
        }
    }

    // --- Search Filter Matching Getters ---
    matchesFilter(textList) {
        if (!this.hasSearchQuery) {
            return true;
        }
        return textList.some(txt => txt && txt.toLowerCase().includes(this.searchQuery));
    }

    get matchesSearchCompanyName() {
        return this.matchesFilter(['Organization Company Name', 'Branding', 'Legal Entity', 'Portal Title', this.companyName]);
    }

    get matchesSearchCompanyEmail() {
        return this.matchesFilter(['HR Department Contact Email', 'Support Email', 'Reply-to', 'Notifications Dispatch', this.companyEmail]);
    }

    get matchesSearchWorkWeek() {
        return this.matchesFilter(['Work Week Model', 'Working Days', 'Schedule', 'Weekend', this.workWeek]);
    }

    get matchesSearchStandardHours() {
        return this.matchesFilter(['Standard Daily Working Hours', 'Daily Work Hours', 'Shift Length', 'Workday', String(this.standardWorkHours)]);
    }

    get matchesSearchAutoCheckout() {
        return this.matchesFilter(['Automated Shift Check-Out', 'Auto Clock Out', 'Midnight Cutoff', 'Auto Checkout']);
    }

    get matchesSearchAutoCheckoutTime() {
        return this.matchesFilter(['Auto Check-Out Cutoff Time', 'Shift End Cutoff', 'Clock-out Time', this.autoCheckoutTime]);
    }

    get matchesSearchOvertime() {
        return this.matchesFilter(['Daily Overtime Threshold', 'OT Hours', 'Overtime Cutoff', String(this.overtimeThresholdHours)]);
    }

    get matchesSearchWorkMode() {
        return this.matchesFilter(['Default Work Mode for Staff', 'Office Hybrid Remote', 'Telecommute', this.defaultWorkMode]);
    }

    get matchesSearchRequireApproval() {
        return this.matchesFilter(['Require Manager Approval for Leaves', 'Leave Workflow', 'Leave Authorization', 'Auto-approval']);
    }

    get matchesSearchAnnualLeaves() {
        return this.matchesFilter(['Default Annual Paid Leave Quota', 'Vacation Days', 'PTO Allowance', 'Annual Quota', String(this.defaultAnnualLeaves)]);
    }

    get matchesSearchSickLeaves() {
        return this.matchesFilter(['Default Sick Medical Leave Quota', 'Sick Leave', 'Medical Days', String(this.defaultSickLeaves)]);
    }

    get matchesSearchNegativeLeave() {
        return this.matchesFilter(['Allow Negative Advance Leave Balance', 'Unpaid Leave', 'Emergency Leave', 'Negative Balance']);
    }

    get matchesSearchCurrency() {
        return this.matchesFilter(['Display Currency Symbol', 'Payroll Currency', 'INR USD EUR GBP', 'Dollar Rupee Euro Pound', this.currencyFormat]);
    }

    get matchesSearchPayrollCycle() {
        return this.matchesFilter(['Monthly Payroll Processing Cycle', 'Pay Day', 'Salary Disbursement', 'Disbursement Cycle', this.payrollCycleDay]);
    }

    get matchesSearchAutoSendPayslips() {
        return this.matchesFilter(['Auto-Email Payslips on Generation', 'PDF Emailing', 'Payslip Dispatch', 'Automatic Payslip']);
    }

    get matchesSearchAdminDelete() {
        return this.matchesFilter(['Allow HR Admins to Delete Records', 'Delete Access', 'Admin Privileges', 'Data Deletion']);
    }

    get matchesSearchDefaultRole() {
        return this.matchesFilter(['Default Role for New Users', 'User Access', 'Provisioning', 'Manager Employee HR Admin', this.defaultRole]);
    }

    get matchesSearchEmailNotif() {
        return this.matchesFilter(['Global Email Notifications', 'System Email Alerts', 'Notification Preferences']);
    }

    get matchesSearchDateFormat() {
        return this.matchesFilter(['Global Date Display Format', 'Date Standard', 'DD/MM/YYYY MM/DD/YYYY YYYY-MM-DD', this.dateFormat]);
    }

    get matchesSearchMaintenance() {
        return this.matchesFilter(['Maintenance Mode', 'System Lock', 'Downtime', 'Read-only Mode']);
    }

    // Category visibility based on active tab and search query
    get showOrgCategory() {
        const tabMatch = this.activeTab === 'all' || this.activeTab === 'org';
        const hasVisibleRows = this.matchesSearchCompanyName || this.matchesSearchCompanyEmail || this.matchesSearchWorkWeek || this.matchesSearchStandardHours;
        return tabMatch && hasVisibleRows;
    }

    get showAttendanceCategory() {
        const tabMatch = this.activeTab === 'all' || this.activeTab === 'attendance';
        const hasVisibleRows = this.matchesSearchAutoCheckout || this.matchesSearchAutoCheckoutTime || this.matchesSearchOvertime || this.matchesSearchWorkMode;
        return tabMatch && hasVisibleRows;
    }

    get showLeavesCategory() {
        const tabMatch = this.activeTab === 'all' || this.activeTab === 'leaves';
        const hasVisibleRows = this.matchesSearchRequireApproval || this.matchesSearchAnnualLeaves || this.matchesSearchSickLeaves || this.matchesSearchNegativeLeave;
        return tabMatch && hasVisibleRows;
    }

    get showPayrollCategory() {
        const tabMatch = this.activeTab === 'all' || this.activeTab === 'payroll';
        const hasVisibleRows = this.matchesSearchCurrency || this.matchesSearchPayrollCycle || this.matchesSearchAutoSendPayslips;
        return tabMatch && hasVisibleRows;
    }

    get showSecurityCategory() {
        const tabMatch = this.activeTab === 'all' || this.activeTab === 'security';
        const hasVisibleRows = this.matchesSearchAdminDelete || this.matchesSearchDefaultRole;
        return tabMatch && hasVisibleRows;
    }

    get showSystemCategory() {
        const tabMatch = this.activeTab === 'all' || this.activeTab === 'system';
        const hasVisibleRows = this.matchesSearchEmailNotif || this.matchesSearchDateFormat || this.matchesSearchMaintenance;
        return tabMatch && hasVisibleRows;
    }

    get filteredCount() {
        let count = 0;
        if (this.matchesSearchCompanyName) count++;
        if (this.matchesSearchCompanyEmail) count++;
        if (this.matchesSearchWorkWeek) count++;
        if (this.matchesSearchStandardHours) count++;
        if (this.matchesSearchAutoCheckout) count++;
        if (this.matchesSearchAutoCheckoutTime) count++;
        if (this.matchesSearchOvertime) count++;
        if (this.matchesSearchWorkMode) count++;
        if (this.matchesSearchRequireApproval) count++;
        if (this.matchesSearchAnnualLeaves) count++;
        if (this.matchesSearchSickLeaves) count++;
        if (this.matchesSearchNegativeLeave) count++;
        if (this.matchesSearchCurrency) count++;
        if (this.matchesSearchPayrollCycle) count++;
        if (this.matchesSearchAutoSendPayslips) count++;
        if (this.matchesSearchAdminDelete) count++;
        if (this.matchesSearchDefaultRole) count++;
        if (this.matchesSearchEmailNotif) count++;
        if (this.matchesSearchDateFormat) count++;
        if (this.matchesSearchMaintenance) count++;
        return count;
    }

    get isSearchEmpty() {
        return this.hasSearchQuery && this.filteredCount === 0;
    }

    get totalSettingsCount() {
        return 20;
    }

    // --- Tab CSS Classes ---
    get allTabClass() {
        return this.activeTab === 'all' ? 'tab-item tab-active' : 'tab-item';
    }

    get orgTabClass() {
        return this.activeTab === 'org' ? 'tab-item tab-active' : 'tab-item';
    }

    get attendanceTabClass() {
        return this.activeTab === 'attendance' ? 'tab-item tab-active' : 'tab-item';
    }

    get leavesTabClass() {
        return this.activeTab === 'leaves' ? 'tab-item tab-active' : 'tab-item';
    }

    get payrollTabClass() {
        return this.activeTab === 'payroll' ? 'tab-item tab-active' : 'tab-item';
    }

    get securityTabClass() {
        return this.activeTab === 'security' ? 'tab-item tab-active' : 'tab-item';
    }

    get systemTabClass() {
        return this.activeTab === 'system' ? 'tab-item tab-active' : 'tab-item';
    }

    // --- Header & Status Badges ---
    get systemStatusText() {
        return this.maintenanceMode ? 'Maintenance Mode' : 'System Operational';
    }

    get systemStatusBadgeClass() {
        return this.maintenanceMode ? 'status-pill status-pill-warning' : 'status-pill status-pill-healthy';
    }

    get systemStatusDotClass() {
        return this.maintenanceMode ? 'status-dot status-dot-warning' : 'status-dot status-dot-healthy';
    }

    get headerStatusDotClass() {
        return this.maintenanceMode ? 'header-dot header-dot-warning' : 'header-dot header-dot-healthy';
    }

    // --- Toggle Classes & Badges ---
    getToggleClass(val) {
        return val ? 'toggle-pill toggle-on' : 'toggle-pill';
    }

    get autoCheckoutToggleClass() {
        return this.getToggleClass(this.autoCheckout);
    }

    get autoCheckoutStateLabel() {
        return this.autoCheckout ? 'ACTIVE' : 'OFF';
    }

    get autoCheckoutStatusBadgeClass() {
        return this.autoCheckout ? 'state-badge state-badge-active' : 'state-badge state-badge-inactive';
    }

    get approvalToggleClass() {
        return this.getToggleClass(this.requireApproval);
    }

    get approvalStateLabel() {
        return this.requireApproval ? 'REQUIRED' : 'AUTO-APPROVE';
    }

    get approvalStatusBadgeClass() {
        return this.requireApproval ? 'state-badge state-badge-active' : 'state-badge state-badge-inactive';
    }

    get negativeLeaveToggleClass() {
        return this.getToggleClass(this.allowNegativeLeave);
    }

    get negativeLeaveStateLabel() {
        return this.allowNegativeLeave ? 'ALLOWED' : 'RESTRICTED';
    }

    get negativeLeaveStatusBadgeClass() {
        return this.allowNegativeLeave ? 'state-badge state-badge-active' : 'state-badge state-badge-inactive';
    }

    get autoSendPayslipsToggleClass() {
        return this.getToggleClass(this.autoSendPayslips);
    }

    get autoSendPayslipsStateLabel() {
        return this.autoSendPayslips ? 'AUTO-DISPATCH' : 'MANUAL';
    }

    get autoSendPayslipsStatusBadgeClass() {
        return this.autoSendPayslips ? 'state-badge state-badge-active' : 'state-badge state-badge-inactive';
    }

    get adminDeleteToggleClass() {
        return this.getToggleClass(this.allowAdminDelete);
    }

    get adminDeleteStateLabel() {
        return this.allowAdminDelete ? 'ENABLED' : 'DISABLED';
    }

    get adminDeleteStatusBadgeClass() {
        return this.allowAdminDelete ? 'state-badge state-badge-active' : 'state-badge state-badge-inactive';
    }

    get emailNotifToggleClass() {
        return this.getToggleClass(this.emailNotifications);
    }

    get emailNotifStateLabel() {
        return this.emailNotifications ? 'ENABLED' : 'MUTED';
    }

    get emailNotifStatusBadgeClass() {
        return this.emailNotifications ? 'state-badge state-badge-active' : 'state-badge state-badge-inactive';
    }

    get maintenanceToggleClass() {
        return this.getToggleClass(this.maintenanceMode);
    }

    get maintenanceStateLabel() {
        return this.maintenanceMode ? 'ENABLED' : 'OFF';
    }

    get maintenanceStatusBadgeClass() {
        return this.maintenanceMode ? 'state-badge state-badge-warning' : 'state-badge state-badge-inactive';
    }

    // --- KPI & Preview Computations ---
    get attendanceSummaryText() {
        return this.autoCheckout ? `Auto-Checkout at ${this.autoCheckoutTime}` : 'Manual Clock-Out Only';
    }

    get overtimeSummaryText() {
        return `Overtime threshold: >${this.overtimeThresholdHours}h / day`;
    }

    get leaveApprovalSummaryText() {
        return this.requireApproval ? 'Manager Approval Required' : 'Instant Auto-Approval';
    }

    get leaveQuotaSummaryText() {
        return `${this.defaultAnnualLeaves} Annual + ${this.defaultSickLeaves} Sick Days`;
    }

    get sampleDateDisplay() {
        const d = new Date();
        const day = String(d.getDate()).padStart(2, '0');
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const year = d.getFullYear();

        if (this.dateFormat === 'MM/DD/YYYY') {
            return `${month}/${day}/${year} (e.g. 09/15/2026)`;
        } else if (this.dateFormat === 'YYYY-MM-DD') {
            return `${year}-${month}-${day} (e.g. 2026-09-15)`;
        }
        return `${day}/${month}/${year} (e.g. 15/09/2026)`;
    }

    get sampleCurrencyDisplay() {
        const symbolMap = {
            INR: '₹ 85,000.00',
            USD: '$ 6,250.00',
            EUR: '€ 5,800.00',
            GBP: '£ 4,950.00'
        };
        return symbolMap[this.currencyFormat] || `${this.currencyFormat} 85,000.00`;
    }

    get totalLeaveDaysPool() {
        return Number(this.defaultAnnualLeaves || 0) + Number(this.defaultSickLeaves || 0);
    }

    get weeklyWorkloadSummary() {
        let daysCount = 5;
        if (this.workWeek && this.workWeek.includes('6 Days')) {
            daysCount = 6;
        } else if (this.workWeek && this.workWeek.includes('4 Days')) {
            daysCount = 4;
        }
        const totalWeekly = (Number(this.standardWorkHours) * daysCount).toFixed(1);
        return `${totalWeekly}h / Week (${daysCount} Days × ${this.standardWorkHours}h)`;
    }

    // --- Save Bar States ---
    get isSavingOrClean() {
        return !this.isDirty || this.isSaving;
    }

    get saveButtonText() {
        return this.isSaving ? 'Saving...' : 'Save Settings';
    }

    get saveStatusText() {
        if (this.isSaving) {
            return 'Saving configuration to Salesforce...';
        }
        return this.isDirty ? 'Unsaved changes detected' : 'All policies up to date';
    }

    get saveHelpText() {
        if (this.isSaving) {
            return 'Please wait while changes are validated and committed.';
        }
        return this.isDirty
            ? 'Press Ctrl + S or click Save Settings to commit your updates.'
            : 'Changes take effect immediately across all HRMS modules.';
    }

    get saveStatusClass() {
        if (this.isSaving) return 'save-status save-status-saving';
        return this.isDirty ? 'save-status save-status-pending' : 'save-status save-status-saved';
    }

    get saveIndicatorClass() {
        if (this.isSaving) return 'save-indicator save-indicator-saving';
        return this.isDirty ? 'save-indicator save-indicator-pending' : 'save-indicator save-indicator-saved';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}