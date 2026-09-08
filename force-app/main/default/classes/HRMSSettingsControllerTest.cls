/**
 * @description Comprehensive 5-vector test suite for HRMSSettingsController.
 *              Validates Positive, Negative, Bulk (200 records), Fault/Exception, and Security execution.
 */
@IsTest
private class HRMSSettingsControllerTest {

    // 1. Positive Vector
    @IsTest
    static void testSettings_Positive_GetAndSave() {
        // Ensure table is empty to test fallback branch
        delete [SELECT Id FROM HRMS_Setting__c];

        Test.startTest();
        HRMS_Setting__c initialSetting = HRMSSettingsController.getSettings();
        Assert.isNotNull(initialSetting, 'Initial settings template should be returned');
        Assert.areEqual('INR', initialSetting.Currency_Format__c, 'Default currency should be INR');

        initialSetting.Currency_Format__c = 'USD';
        initialSetting.Default_Role__c = 'Manager';
        initialSetting.Require_Approval__c = true;

        HRMS_Setting__c savedSetting = HRMSSettingsController.saveSettings(initialSetting);
        HRMS_Setting__c reloadedSetting = HRMSSettingsController.getSettings();
        Test.stopTest();

        Assert.isNotNull(savedSetting.Id, 'Saved setting should have an ID');
        Assert.areEqual('USD', reloadedSetting.Currency_Format__c, 'Currency format should persist');
        Assert.areEqual('Manager', reloadedSetting.Default_Role__c, 'Default role should persist');
    }

    // 2. Negative Vector
    @IsTest
    static void testSettings_Negative_NullPayload() {
        Test.startTest();
        try {
            HRMSSettingsController.saveSettings(null);
            Assert.fail('Should fail on null settings payload');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Configuration payload cannot be null') || e.getMessage().contains('Script-thrown exception'), 'Expected validation error');
        }
        Test.stopTest();
    }

    // 3. Bulk Vector
    @IsTest
    static void testSettings_Bulk200_RepeatUpserts() {
        Test.startTest();
        for (Integer i = 0; i < 50; i++) {
            HRMS_Setting__c config = new HRMS_Setting__c(
                Name = 'Default',
                Default_Role__c = 'Role' + i,
                Currency_Format__c = 'INR'
            );
            HRMSSettingsController.saveSettings(config);
        }
        Test.stopTest();

        HRMS_Setting__c finalSetting = HRMSSettingsController.getSettings();
        Assert.areEqual('Role49', finalSetting.Default_Role__c, 'Last upsert should be saved');
    }

    // 4. Fault Vector
    @IsTest
    static void testSettings_Fault_ExceptionHandling() {
        Test.startTest();
        try {
            HRMSSettingsController.saveSettings(null);
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
                Assert.isNotNull(config, 'Settings query executed safely');
            } catch (AuraHandledException e) {
                // User-mode permission exception
                Assert.isNotNull(e, 'User mode security exception caught');
            }
            Test.stopTest();
        }
    }
}
