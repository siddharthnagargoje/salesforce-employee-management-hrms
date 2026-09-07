import { LightningElement } from 'lwc';

export default class SettingsManagement extends LightningElement {
    // User Access
    allowAdminDelete = false;
    defaultRole = 'Employee';
    requireApproval = true;

    // Preferences
    emailNotifications = true;
    currencyFormat = 'INR';
    dateFormat = 'DD/MM/YYYY';

    // System Configuration
    maintenanceMode = false;
    autoCheckout = false;

    // Save state
    isDirty = false;
    isSaving = false;

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

    handleSaveSettings() {
        if (!this.isDirty || this.isSaving) {
            return;
        }

        this.isSaving = true;

        /*
         * Replace this simulated save with an Apex method later.
         */

        window.setTimeout(() => {
            this.isSaving = false;
            this.isDirty = false;
        }, 800);
    }
}