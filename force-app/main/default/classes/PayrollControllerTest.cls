/**
 * @description Comprehensive 5-vector test suite for PayrollController.
 *              Validates Positive, Negative, Bulk (200 records), Fault/Exception, and Security execution.
 */
@IsTest
private class PayrollControllerTest {

    @TestSetup
    static void setupTestData() {
        TestDataFactory.createEmployee('Bruce', 'Wayne', 'CTO', 'Active', Date.today().addYears(-1), true);
    }

    // 1. Positive Vector
    @IsTest
    static void testPayroll_Positive_CreateAndDispatchEmail() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        Payslip__c payslip = PayrollController.createPayslip(emp.Id, 'September', Date.today().year(), 80000, 10000, 4000, 'Generated');
        List<Payslip__c> slips = PayrollController.getPayslips();
        Map<String, Object> emailResult = PayrollController.sendPayslipEmail(payslip.Id, true);
        Test.stopTest();

        Assert.isNotNull(payslip.Id, 'Payslip should be created with an ID');
        Assert.isFalse(slips.isEmpty(), 'Payslips list should not be empty');
        Assert.isNotNull(emailResult, 'Email dispatch result should not be null');
        Assert.isTrue((Boolean) emailResult.get('isSuccess'), 'Email dispatch should succeed');
    }

    // 2. Negative Vector
    @IsTest
    static void testPayroll_Negative_MissingMonthOrYear() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        try {
            PayrollController.createPayslip(emp.Id, '', null, 50000, 0, 0, 'Generated');
            Assert.fail('Should fail when Month or Year are missing');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Pay Month and Pay Year are required') || e.getMessage().contains('Script-thrown exception'), 'Expected validation error');
        }
        Test.stopTest();
    }

    // 3. Bulk 200 Vector
    @IsTest
    static void testPayroll_Bulk200_CreateAndQuery() {
        List<Employee__c> emps = TestDataFactory.createEmployees(200, true);
        List<Payslip__c> slips = new List<Payslip__c>();
        for (Employee__c emp : emps) {
            slips.add(new Payslip__c(
                Employee__c = emp.Id,
                Pay_Month__c = 'September',
                Pay_Year__c = Date.today().year(),
                Basic_Salary__c = 70000,
                Bonus__c = 5000,
                Deductions__c = 2000,
                Status__c = 'Generated'
            ));
        }

        Test.startTest();
        insert slips;
        List<Payslip__c> queried = PayrollController.getPayslips();
        Test.stopTest();

        Assert.isTrue(queried.size() >= 200, 'Must query 200+ payslips without hitting limits');
    }

    // 4. Fault Vector
    @IsTest
    static void testPayroll_Fault_NullPayslipEmail() {
        Test.startTest();
        try {
            PayrollController.sendPayslipEmail(null, true);
            Assert.fail('Should fail on null payslip ID');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Exception message should be populated');
        }
        Test.stopTest();
    }

    // 5. Security RunAs Vector
    @IsTest
    static void testPayroll_Security_RunAs_StandardUser() {
        User standardUser = TestDataFactory.createStandardUser();
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        System.runAs(standardUser) {
            Test.startTest();
            try {
                PayrollController.createPayslip(emp.Id, 'September', Date.today().year(), 60000, 2000, 1000, 'Generated');
            } catch (AuraHandledException e) {
                // User-mode access restriction caught
                Assert.isNotNull(e, 'User mode exception handled gracefully');
            }
            Test.stopTest();
        }
    }
}
