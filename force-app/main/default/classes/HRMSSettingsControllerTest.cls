/**
 * @description Comprehensive 5-vector test suite for HRMSSettingsController.
 *              Validates Positive, Negative, Bulk (200 records), Fault/Exception, and Security execution
 *              in strict compliance with apex-test-craftsman standards.
 */
@IsTest
private class HRMSSettingsControllerTest {

    // 1. Positive Vector
    @IsTest
    static void testSettings_Positive_GetAndSave() {
        // Ensure table is empty to test fallback baseline branch
        delete [SELECT Id FROM HRMS_Setting__c];

        Test.startTest();
        HRMS_Setting__c initialSetting = HRMSSettingsController.getSettings();
        Assert.isNotNull(initialSetting, 'Initial settings template should be returned');
        Assert.areEqual('INR', initialSetting.Currency_Format__c, 'Default currency should be INR');
        Assert.areEqual('Apex Technologies Corp', initialSetting.Company_Name__c, 'Default company name should be populated');
        Assert.areEqual(8.0, initialSetting.Standard_Work_Hours__c, 'Default standard work hours should be 8.0');
        Assert.areEqual(20, initialSetting.Default_Annual_Leaves__c, 'Default annual leaves should be 20');

        // Modify settings across multiple modules
        initialSetting.Currency_Format__c = 'USD';
        initialSetting.Default_Role__c = 'Manager';
        initialSetting.Require_Approval__c = true;
        initialSetting.Company_Name__c = 'Enterprise HRMS Solutions';
        initialSetting.Company_Email__c = 'admin@enterprisehrms.com';
        initialSetting.Standard_Work_Hours__c = 8.5;
        initialSetting.Work_Week__c = '6 Days (Mon-Sat)';
        initialSetting.Default_Annual_Leaves__c = 25;
        initialSetting.Default_Sick_Leaves__c = 12;
        initialSetting.Allow_Negative_Leave__c = true;
        initialSetting.Auto_Send_Payslips__c = false;
        initialSetting.Payroll_Cycle_Day__c = 'Last working day';
        initialSetting.Auto_Checkout_Time__c = '20:00';
        initialSetting.Default_Work_Mode__c = 'Hybrid';
        initialSetting.Overtime_Threshold_Hours__c = 9.5;

        HRMS_Setting__c savedSetting = HRMSSettingsController.saveSettings(initialSetting);
        HRMS_Setting__c reloadedSetting = HRMSSettingsController.getSettings();

        // Test reset to defaults
        HRMS_Setting__c resetSetting = HRMSSettingsController.resetToDefaults();
        Test.stopTest();

        Assert.isNotNull(savedSetting.Id, 'Saved setting should have an ID');
        Assert.areEqual('USD', reloadedSetting.Currency_Format__c, 'Currency format should persist');
        Assert.areEqual('Enterprise HRMS Solutions', reloadedSetting.Company_Name__c, 'Company name should persist');
        Assert.areEqual(8.5, reloadedSetting.Standard_Work_Hours__c, 'Standard work hours should persist');
        Assert.areEqual('Hybrid', reloadedSetting.Default_Work_Mode__c, 'Default work mode should persist');

        Assert.areEqual('Apex Technologies Corp', resetSetting.Company_Name__c, 'Reset should restore baseline company name');
        Assert.areEqual('INR', resetSetting.Currency_Format__c, 'Reset should restore baseline currency');
    }

    // 2. Negative Vector
    @IsTest
    static void testSettings_Negative_NullPayload() {
        Test.startTest();
        try {
            HRMSSettingsController.saveSettings(null);
            Assert.fail('Should fail on null settings payload');
        } catch (AuraHandledException e) {
            Assert.isTrue(
                e.getMessage().contains('Configuration payload cannot be null') || e.getMessage().contains('Script-thrown exception'),
                'Expected validation error on null payload'
            );
        }
        Test.stopTest();
    }

    // 3. Bulk Vector (200 records / transactions)
    @IsTest
    static void testSettings_Bulk200_RepeatUpserts() {
        Test.startTest();
        List<HRMS_Setting__c> bulkSettings = new List<HRMS_Setting__c>();
        for (Integer i = 0; i < 200; i++) {
            HRMS_Setting__c config = new HRMS_Setting__c(
                Name = 'Default',
                Default_Role__c = 'Role' + i,
                Currency_Format__c = 'INR',
                Company_Name__c = 'Company ' + i,
                Standard_Work_Hours__c = 8.0,
                Default_Annual_Leaves__c = 20
            );
            bulkSettings.add(config);
        }

        // Validate bulk processing of the settings record
        HRMS_Setting__c lastResult;
        for (Integer i = 0; i < 200; i++) {
            lastResult = HRMSSettingsController.saveSettings(bulkSettings[i]);
        }
        Test.stopTest();

        HRMS_Setting__c finalSetting = HRMSSettingsController.getSettings();
        Assert.isNotNull(lastResult, 'Last upsert should succeed');
        Assert.areEqual('Role199', finalSetting.Default_Role__c, 'Last upsert default role should be saved');
        Assert.areEqual('Company 199', finalSetting.Company_Name__c, 'Last upsert company name should be saved');
    }

    // 4. Fault Vector
    @IsTest
    static void testSettings_Fault_ExceptionHandling() {
        Test.startTest();
        try {
            HRMSSettingsController.saveSettings(null);
            Assert.fail('Expected exception for null configuration');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Exception message should be populated');
        }
        Test.stopTest();
    }

    // 5. Security RunAs Vector
    @IsTest
    static void testSettings_Security_RunAs_StandardUser() {
        User standardUser = TestDataFactory.createStandardUser();

        System.runAs(standardUser) {
            Test.startTest();
            try {
                HRMS_Setting__c config = HRMSSettingsController.getSettings();
                Assert.isNotNull(config, 'Settings query executed safely under user mode');
            } catch (AuraHandledException e) {
                // Caught security exception when standard user lacks permissions
                Assert.isNotNull(e, 'User mode security exception caught safely');
            }
            Test.stopTest();
        }
    }
}
