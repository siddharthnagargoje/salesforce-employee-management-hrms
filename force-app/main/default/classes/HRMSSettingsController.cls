/**
 * @description Dedicated controller for HRMS system configuration and preference storage.
 *              Persists global settings in the HRMS_Setting__c custom object.
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
                       Auto_Checkout__c
                FROM HRMS_Setting__c
                WHERE Name = :DEFAULT_SETTING_KEY
                LIMIT 1
            ];

            if (!settings.isEmpty()) {
                return settings[0];
            }

            // Return default unsaved template if not yet seeded
            return new HRMS_Setting__c(
                Name = DEFAULT_SETTING_KEY,
                Allow_Admin_Delete__c = false,
                Default_Role__c = 'Employee',
                Require_Approval__c = true,
                Email_Notifications__c = true,
                Currency_Format__c = 'INR',
                Date_Format__c = 'DD/MM/YYYY',
                Maintenance_Mode__c = false,
                Auto_Checkout__c = false
            );
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
}
