import { LightningElement, wire, track } from 'lwc';
import getSettings from '@salesforce/apex/HRMSSettingsController.getSettings';
import saveSettings from '@salesforce/apex/HRMSSettingsController.saveSettings';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class SettingsManagement extends LightningElement {
    // User Access
    @track allowAdminDelete = false;
    @track defaultRole = 'Employee';
    @track requireApproval = true;

    // Preferences
    @track emailNotifications = true;
    @track currencyFormat = 'INR';
    @track dateFormat = 'DD/MM/YYYY';

    // System Configuration
    @track maintenanceMode = false;
    @track autoCheckout = false;

    // Save state
    @track isDirty = false;
    @track isSaving = false;

    settingRecordId;
    wiredSettingsResult;

    @wire(getSettings)
    wiredSettings(result) {
        this.wiredSettingsResult = result;
        const { data, error } = result;
        if (data) {
            this.settingRecordId = data.Id;
            this.allowAdminDelete = data.Allow_Admin_Delete__c === true;
            this.defaultRole = data.Default_Role__c || 'Employee';
            this.requireApproval = data.Require_Approval__c !== false;
            this.emailNotifications = data.Email_Notifications__c !== false;
            this.currencyFormat = data.Currency_Format__c || 'INR';
            this.dateFormat = data.Date_Format__c || 'DD/MM/YYYY';
            this.maintenanceMode = data.Maintenance_Mode__c === true;
            this.autoCheckout = data.Auto_Checkout__c === true;
            this.isDirty = false;
        } else if (error) {
            this.showToast('Error', 'Failed to load system settings from Salesforce: ' + (error.body?.message || error.message), 'error');
        }
    }

    toggleAdminDelete() {
        this.allowAdminDelete = !this.allowAdminDelete;
        this.markAsDirty();
    }

    toggleApprovalRequired() {
        this.requireApproval = !this.requireApproval;
        this.markAsDirty();
    }

    toggleEmailNotifications() {
        this.emailNotifications = !this.emailNotifications;
        this.markAsDirty();
    }

    toggleMaintenanceMode() {
        this.maintenanceMode = !this.maintenanceMode;
        this.markAsDirty();
    }

    toggleAutoCheckout() {
        this.autoCheckout = !this.autoCheckout;
        this.markAsDirty();
    }

    handleDefaultRoleChange(event) {
        this.defaultRole = event.target.value;
        this.markAsDirty();
    }

    handleCurrencyChange(event) {
        this.currencyFormat = event.target.value;
        this.markAsDirty();
    }

    handleDateFormatChange(event) {
        this.dateFormat = event.target.value;
        this.markAsDirty();
    }

    markAsDirty() {
        this.isDirty = true;
    }

    get adminDeleteToggleClass() {
        return this.getToggleClass(this.allowAdminDelete);
    }

    get approvalToggleClass() {
        return this.getToggleClass(this.requireApproval);
    }

    get emailNotifToggleClass() {
        return this.getToggleClass(this.emailNotifications);
    }

    get maintenanceToggleClass() {
        return this.getToggleClass(this.maintenanceMode);
    }

    get autoCheckoutToggleClass() {
        return this.getToggleClass(this.autoCheckout);
    }

    getToggleClass(value) {
        return value ? 'toggle-pill toggle-on' : 'toggle-pill';
    }

    get notificationStatus() {
        return this.emailNotifications ? 'Enabled' : 'Disabled';
    }

    get saveStatusText() {
        if (this.isSaving) {
            return 'Saving changes...';
        }

        return this.isDirty
            ? 'Unsaved changes'
            : 'All changes saved';
    }

    get saveHelpText() {
        if (this.isSaving) {
            return 'Please wait while your settings are saved.';
        }

        return this.isDirty
            ? 'Review your changes before saving.'
            : 'Your preferences are up to date.';
    }

    get saveButtonText() {
        return this.isSaving ? 'Saving' : 'Save Changes';
    }

    get saveStatusClass() {
        if (this.isSaving) {
            return 'save-status save-status-saving';
        }

        return this.isDirty
            ? 'save-status save-status-pending'
            : 'save-status save-status-saved';
    }

    get saveIndicatorClass() {
        if (this.isSaving) {
            return 'save-indicator save-indicator-saving';
        }

        return this.isDirty
            ? 'save-indicator save-indicator-pending'
            : 'save-indicator save-indicator-saved';
    }

    async handleSaveSettings() {
        if (!this.isDirty || this.isSaving) {
            return;
        }

        this.isSaving = true;

        const payload = {
            sobjectType: 'HRMS_Setting__c',
            Id: this.settingRecordId,
            Allow_Admin_Delete__c: this.allowAdminDelete,
            Default_Role__c: this.defaultRole,
            Require_Approval__c: this.requireApproval,
            Email_Notifications__c: this.emailNotifications,
            Currency_Format__c: this.currencyFormat,
            Date_Format__c: this.dateFormat,
            Maintenance_Mode__c: this.maintenanceMode,
            Auto_Checkout__c: this.autoCheckout
        };

        try {
            const saved = await saveSettings({ config: payload });
            this.settingRecordId = saved.Id;
            this.isDirty = false;
            this.showToast('Success', 'System configuration saved successfully.', 'success');
            await refreshApex(this.wiredSettingsResult);
        } catch (error) {
            this.showToast('Error', 'Failed to save settings: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}