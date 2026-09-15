/**
 * @description Dedicated controller for HRMS system configuration and preference storage.
 *              Persists global settings in the HRMS_Setting__c custom object across all HRMS modules:
 *              Company profile, Attendance policies, Leave rules, Payroll configuration, Security, and System preferences.
 */
public with sharing class HRMSSettingsController {

    private static final String DEFAULT_SETTING_KEY = 'Default';

    private static AuraHandledException createAuraHandledException(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }

    /**
     * @description Fetches the active system configuration or creates default baseline.
     */
    @AuraEnabled(cacheable=true)
    public static HRMS_Setting__c getSettings() {
        try {
            List<HRMS_Setting__c> settings = [
                SELECT Id,
                       Name,
                       Allow_Admin_Delete__c,
                       Default_Role__c,
                       Require_Approval__c,
                       Email_Notifications__c,
                       Currency_Format__c,
                       Date_Format__c,
                       Maintenance_Mode__c,
                       Auto_Checkout__c,
                       Company_Name__c,
                       Company_Email__c,
                       Standard_Work_Hours__c,
                       Work_Week__c,
                       Default_Annual_Leaves__c,
                       Default_Sick_Leaves__c,
                       Allow_Negative_Leave__c,
                       Auto_Send_Payslips__c,
                       Payroll_Cycle_Day__c,
                       Auto_Checkout_Time__c,
                       Default_Work_Mode__c,
                       Overtime_Threshold_Hours__c
                FROM HRMS_Setting__c
                WHERE Name = :DEFAULT_SETTING_KEY
                LIMIT 1
            ];

            if (!settings.isEmpty()) {
                return settings[0];
            }

            // Return default unsaved baseline template if not yet seeded
            return getDefaultBaseline();
        } catch (Exception e) {
            throw createAuraHandledException('Error loading HRMS settings: ' + e.getMessage());
        }
    }

    /**
     * @description Saves updated configuration settings to the database.
     */
    @AuraEnabled
    public static HRMS_Setting__c saveSettings(HRMS_Setting__c config) {
        try {
            if (config == null) {
                throw new IllegalArgumentException('Configuration payload cannot be null.');
            }

            config.Name = DEFAULT_SETTING_KEY;
            upsert config Name;
            return config;
        } catch (Exception e) {
            throw createAuraHandledException('Error saving HRMS settings: ' + e.getMessage());
        }
    }

    /**
     * @description Resets system configuration back to factory baseline settings.
     */
    @AuraEnabled
    public static HRMS_Setting__c resetToDefaults() {
        try {
            HRMS_Setting__c baseline = getDefaultBaseline();
            List<HRMS_Setting__c> existing = [
                SELECT Id
                FROM HRMS_Setting__c
                WHERE Name = :DEFAULT_SETTING_KEY
                LIMIT 1
            ];
            if (!existing.isEmpty()) {
                baseline.Id = existing[0].Id;
            }
            upsert baseline Name;
            return baseline;
        } catch (Exception e) {
            throw createAuraHandledException('Error resetting HRMS settings: ' + e.getMessage());
        }
    }

    /**
     * @description Builds the standard default baseline configuration record.
     */
    public static HRMS_Setting__c getDefaultBaseline() {
        return new HRMS_Setting__c(
            Name = DEFAULT_SETTING_KEY,
            Allow_Admin_Delete__c = false,
            Default_Role__c = 'Employee',
            Require_Approval__c = true,
            Email_Notifications__c = true,
            Currency_Format__c = 'INR',
            Date_Format__c = 'DD/MM/YYYY',
            Maintenance_Mode__c = false,
            Auto_Checkout__c = false,
            Company_Name__c = 'Apex Technologies Corp',
            Company_Email__c = 'hr@apextechnologies.com',
            Standard_Work_Hours__c = 8.0,
            Work_Week__c = '5 Days (Mon-Fri)',
            Default_Annual_Leaves__c = 20,
            Default_Sick_Leaves__c = 10,
            Allow_Negative_Leave__c = false,
            Auto_Send_Payslips__c = true,
            Payroll_Cycle_Day__c = '28th of every month',
            Auto_Checkout_Time__c = '19:00',
            Default_Work_Mode__c = 'Office',
            Overtime_Threshold_Hours__c = 9.0
        );
    }
}
