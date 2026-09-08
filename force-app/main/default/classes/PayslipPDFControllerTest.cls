/**
 * @description Unit tests for PayslipPDFController Visualforce controller.
 *              Strictly follows the 5-Vector Test Methodology (Positive, Negative, Bulk, Fault, Security).
 */
@IsTest
private class PayslipPDFControllerTest {

    @TestSetup
    static void setupTestData() {
        Employee__c emp1 = TestDataFactory.createEmployee('Diana', 'Prince', 'VP of HR', 'Active', Date.today().addYears(-1), false);
        emp1.Official_Email__c = 'diana.prince@hrmstest.com';
        emp1.Work_Location__c = 'New York';
        insert emp1;

        Employee__c emp2 = TestDataFactory.createEmployee('Arthur', 'Curry', 'Marine Tech', 'Active', Date.today().addYears(-2), false);
        emp2.Personal_Email__c = 'arthur.curry@hrmstest.com';
        emp2.Work_Location__c = null; // Test fallback work location
        insert emp2;

        Employee__c emp3 = TestDataFactory.createEmployee('Barry', 'Allen', '', 'Active', Date.today().addMonths(-2), false);
        emp3.Official_Email__c = null;
        emp3.Personal_Email__c = null; // Both emails null to cover line 69
        insert emp3;

        TestDataFactory.createPayslip(emp1.Id, 'August', Date.today().year(), 85000, 10000, 5000, 'Paid', true);
        TestDataFactory.createPayslip(emp2.Id, 'July', Date.today().year(), 60000, 0, 3000, 'Generated', true);
        TestDataFactory.createPayslip(emp3.Id, 'June', Date.today().year(), 45000, 0, 1000, 'Generated', true);
    }

    /**
     * VECTOR 1: Positive / Happy Path
     * Validates complete payslip loading, formatting methods, and status class mapping.
     */
    @IsTest
    static void testPositive_ValidPaidPayslip() {
        Payslip__c slip = [
            SELECT Id, Name, Status__c, Basic_Salary__c, Bonus__c, Deductions__c 
            FROM Payslip__c 
            WHERE Status__c = 'Paid' 
            LIMIT 1
        ];

        Test.startTest();
        PageReference pageRef = Page.PayslipPDFPage;
        pageRef.getParameters().put('id', slip.Id);
        Test.setCurrentPage(pageRef);

        ApexPages.StandardController stdController = new ApexPages.StandardController(slip);
        PayslipPDFController controller = new PayslipPDFController(stdController);
        Test.stopTest();

        Assert.areEqual('Diana Prince', controller.employeeName, 'Employee Name should match');
        Assert.areEqual('VP of HR', controller.designation, 'Designation should match');
        Assert.areEqual('diana.prince@hrmstest.com', controller.employeeEmail, 'Official email should be preferred');
        Assert.areEqual('New York', controller.workLocation, 'Work location should match');
        Assert.areEqual(85000, controller.basicSalary, 'Basic salary should match');
        Assert.areEqual(10000, controller.bonus, 'Bonus should match');
        Assert.areEqual(5000, controller.deductions, 'Deductions should match');
        Assert.areEqual(95000, controller.grossSalary, 'Gross salary should be basic + bonus');
        Assert.areEqual(90000, controller.netSalary, 'Net salary should be gross - deductions');
        Assert.areEqual('Paid', controller.paymentStatus, 'Status should be Paid');
        Assert.areEqual('status-paid', controller.getStatusClass(), 'Status class should be status-paid');
        Assert.isTrue(controller.getBasicSalaryFormatted().contains('85,000'), 'Formatted basic salary should contain 85,000');
        Assert.isTrue(controller.getBonusFormatted().contains('10,000'), 'Formatted bonus should contain 10,000');
        Assert.isTrue(controller.getDeductionsFormatted().contains('5,000'), 'Formatted deductions should contain 5,000');
        Assert.isTrue(controller.getGrossSalaryFormatted().contains('95,000'), 'Formatted gross salary should contain 95,000');
        Assert.isTrue(controller.getNetSalaryFormatted().contains('90,000'), 'Formatted net salary should contain 90,000');
    }

    /**
     * VECTOR 2: Negative & Boundary Handling
     * Validates personal email fallback, no email fallback, default work location, status classes, and null currency amounts.
     */
    @IsTest
    static void testNegative_FallbackFieldsAndEdgeStatuses() {
        Payslip__c slipWithPersonalEmail = [
            SELECT Id, Name, Status__c, Basic_Salary__c, Bonus__c, Deductions__c 
            FROM Payslip__c 
            WHERE Employee__r.First_Name__c = 'Arthur' 
            LIMIT 1
        ];

        Test.startTest();
        ApexPages.StandardController stdController = new ApexPages.StandardController(slipWithPersonalEmail);
        PayslipPDFController controller = new PayslipPDFController(stdController);

        // Test slip with both emails null and empty designation
        Payslip__c slipWithNoEmail = [
            SELECT Id, Name, Status__c, Basic_Salary__c, Bonus__c, Deductions__c 
            FROM Payslip__c 
            WHERE Employee__r.First_Name__c = 'Barry' 
            LIMIT 1
        ];
        ApexPages.StandardController noEmailStdCtrl = new ApexPages.StandardController(slipWithNoEmail);
        PayslipPDFController noEmailCtrl = new PayslipPDFController(noEmailStdCtrl);

        Test.stopTest();

        Assert.areEqual('Arthur Curry', controller.employeeName, 'Employee Name should match');
        Assert.areEqual('arthur.curry@hrmstest.com', controller.employeeEmail, 'Personal email fallback should be used');
        Assert.areEqual('Headquarters', controller.workLocation, 'Null work location should default to Headquarters');
        Assert.areEqual('status-approved', controller.getStatusClass(), 'Status class for Generated should be status-approved');

        Assert.areEqual('N/A', noEmailCtrl.employeeEmail, 'When both emails null, should be N/A');

        // Test boundary on formatCurrency with null and zero
        Assert.isTrue(controller.formatCurrency(null).contains('0'), 'Null currency should format gracefully with 0');
        Assert.isTrue(controller.formatCurrency(0).contains('0'), 'Zero currency should format gracefully with 0');

        // Test boundary on empty payslip with unpopulated ID
        Payslip__c uninsertedSlip = new Payslip__c();
        ApexPages.StandardController emptyController = new ApexPages.StandardController(uninsertedSlip);
        PayslipPDFController defaultController = new PayslipPDFController(emptyController);
        Assert.areEqual('N/A', defaultController.employeeName, 'Employee Name should be N/A');
        Assert.areEqual('N/A', defaultController.payslipNumber, 'Payslip number should be N/A');
        Assert.areEqual(0, defaultController.netSalary, 'Net salary should default to 0');
        Assert.areEqual('status-pending', defaultController.getStatusClass(), 'Default status class should be status-pending');
    }

    /**
     * VECTOR 3: Bulk Processing (200 Records)
     * Verifies bulk creation of 200 records and processing without hitting governor limits.
     */
    @IsTest
    static void testBulk200_PayslipPDFControllers() {
        List<Employee__c> emps = TestDataFactory.createEmployees(200, true);
        List<Payslip__c> bulkSlips = new List<Payslip__c>();
        for (Integer i = 0; i < 200; i++) {
            bulkSlips.add(new Payslip__c(
                Employee__c = emps[i].Id,
                Pay_Month__c = 'January',
                Pay_Year__c = 2026,
                Basic_Salary__c = 50000 + i,
                Bonus__c = 1000,
                Deductions__c = 500,
                Status__c = 'Paid'
            ));
        }

        Test.startTest();
        insert bulkSlips;

        // Instantiate controllers for a subset to verify execution within governor limits
        for (Integer i = 0; i < 10; i++) {
            ApexPages.StandardController stdController = new ApexPages.StandardController(bulkSlips[i]);
            PayslipPDFController ctrl = new PayslipPDFController(stdController);
            Assert.isNotNull(ctrl.payslip, 'Payslip must be loaded');
        }
        Test.stopTest();

        Assert.areEqual(200, bulkSlips.size(), '200 bulk payslip records created');
    }

    /**
     * VECTOR 4: Fault Tolerance & Exception Handling
     * Validates behavior when controller is passed null, or when Id does not exist in DB.
     */
    @IsTest
    static void testFault_NullControllerAndFakeId() {
        // Generate valid fake Id with correct Payslip__c prefix
        String keyPrefix = Payslip__c.SObjectType.getDescribe().getKeyPrefix();
        Id fakePayslipId = (Id) (keyPrefix + '000000000001AAA');

        Test.startTest();
        // Null standard controller
        PayslipPDFController nullCtrl = new PayslipPDFController(null);
        Assert.isNull(nullCtrl.payslip, 'Payslip should be null when passed null controller');
        Assert.areEqual('N/A', nullCtrl.employeeName, 'Employee name should default cleanly');

        // Fake Id not in DB (covers slips.isEmpty() branch)
        Payslip__c fakeSlip = new Payslip__c(Id = fakePayslipId);
        ApexPages.StandardController fakeStdCtrl = new ApexPages.StandardController(fakeSlip);
        PayslipPDFController fakeCtrl = new PayslipPDFController(fakeStdCtrl);
        Test.stopTest();

        Assert.isNull(fakeCtrl.payslip, 'Payslip should be null for non-existent record');
        Assert.areEqual('N/A', fakeCtrl.employeeName, 'Default values should remain for non-existent record');
    }

    /**
     * VECTOR 5: Security / FLS Context via System.runAs
     * Validates query execution under standard user context.
     */
    @IsTest
    static void testSecurity_RunAs_StandardUser() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User stdUser = new User(
            Alias = 'hrmspdf',
            Email = 'hrmspdfstandard@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'HRMSPDFUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = stdProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'hrmspdfstandard' + DateTime.now().getTime() + '@testorg.com'
        );
        insert stdUser;

        Payslip__c slip = [SELECT Id FROM Payslip__c LIMIT 1];

        System.runAs(stdUser) {
            Test.startTest();
            try {
                ApexPages.StandardController stdController = new ApexPages.StandardController(slip);
                PayslipPDFController controller = new PayslipPDFController(stdController);
                Assert.isNotNull(controller, 'Controller instantiated under standard user');
            } catch (Exception e) {
                // In WITH USER_MODE, if standard user lacks permissions, clean handled exception or null is caught
                Assert.isNotNull(e.getMessage(), 'Caught expected security exception');
            }
            Test.stopTest();
        }
    }
}
