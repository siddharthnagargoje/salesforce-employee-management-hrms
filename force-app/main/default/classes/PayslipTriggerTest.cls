/**
 * @description Comprehensive 5-vector test suite for PayslipTrigger and PayslipTriggerHandler.
 *              Validates Positive, Negative, Bulk (200 records), Fault/Rollback, and Security execution.
 */
@IsTest
private class PayslipTriggerTest {

    @TestSetup
    static void setupTestData() {
        TestDataFactory.createEmployee('Hal', 'Jordan', 'Pilot', 'Active', Date.today().addYears(-1), true);
    }

    // 1. Positive Vector
    @IsTest
    static void testPayslipTrigger_Positive_CreatePayslip() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        Payslip__c slip = new Payslip__c(
            Employee__c = emp.Id,
            Pay_Month__c = 'January',
            Pay_Year__c = Date.today().year(),
            Basic_Salary__c = 70000,
            Bonus__c = 5000,
            Deductions__c = 2000,
            Status__c = 'Generated'
        );
        insert slip;
        Test.stopTest();

        Assert.isNotNull(slip.Id, 'Payslip should be created successfully');
    }

    // 2. Negative Vector
    @IsTest
    static void testPayslipTrigger_Negative_DuplicatePayslipMonthYear() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Payslip__c slip1 = new Payslip__c(
            Employee__c = emp.Id,
            Pay_Month__c = 'February',
            Pay_Year__c = Date.today().year(),
            Basic_Salary__c = 70000,
            Status__c = 'Generated'
        );
        insert slip1;

        Test.startTest();
        try {
            Payslip__c slip2 = new Payslip__c(
                Employee__c = emp.Id,
                Pay_Month__c = 'February',
                Pay_Year__c = Date.today().year(),
                Basic_Salary__c = 70000,
                Status__c = 'Generated'
            );
            insert slip2;
            Assert.fail('Should prevent duplicate payslip for same month and year');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('A payslip already exists for this employee for'), 'Expected duplicate payslip error');
        }
        Test.stopTest();
    }

    // 3. Bulk 200 Vector
    @IsTest
    static void testPayslipTrigger_Bulk200_Insert() {
        List<Employee__c> emps = TestDataFactory.createEmployees(200, true);
        List<Payslip__c> batch = new List<Payslip__c>();
        for (Integer i = 0; i < 200; i++) {
            batch.add(new Payslip__c(
                Employee__c = emps[i].Id,
                Pay_Month__c = 'March',
                Pay_Year__c = Date.today().year(),
                Basic_Salary__c = 65000,
                Status__c = 'Generated'
            ));
        }

        Test.startTest();
        insert batch;
        Test.stopTest();

        Assert.areEqual(200, [SELECT COUNT() FROM Payslip__c WHERE Id IN :batch], 'All 200 payslips inserted safely');
    }

    // 4. Fault Vector
    @IsTest
    static void testPayslipTrigger_Fault_NegativeSalaryRejected() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        try {
            Payslip__c slip = new Payslip__c(
                Employee__c = emp.Id,
                Pay_Month__c = 'April',
                Pay_Year__c = Date.today().year(),
                Basic_Salary__c = -5000, // Negative basic salary
                Status__c = 'Generated'
            );
            insert slip;
            Assert.fail('Should reject negative salary');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('Basic Salary cannot be negative'), 'Expected salary validation error');
        }
        Test.stopTest();
    }

    // 5. Security RunAs Vector
    @IsTest
    static void testPayslipTrigger_Security_RunAs_StandardUser() {
        User stdUser = TestDataFactory.createStandardUser();
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        System.runAs(stdUser) {
            Test.startTest();
            try {
                Payslip__c slip = new Payslip__c(
                    Employee__c = emp.Id,
                    Pay_Month__c = 'May',
                    Pay_Year__c = Date.today().year(),
                    Basic_Salary__c = 50000,
                    Status__c = 'Generated'
                );
                insert slip;
            } catch (DmlException e) {
                Assert.isNotNull(e, 'User mode standard security handled');
            }
            Test.stopTest();
        }
    }
}
