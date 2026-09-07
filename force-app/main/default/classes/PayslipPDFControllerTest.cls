/**
 * @description Unit tests for PayslipPDFController Visualforce controller.
 */
@IsTest
private class PayslipPDFControllerTest {

    @TestSetup
    static void setupTestData() {
        Employee__c emp = TestDataFactory.createEmployee('Diana', 'Prince', 'VP of HR', 'Active', Date.today().addYears(-1), true);
        TestDataFactory.createPayslip(emp.Id, 'August', Date.today().year(), 85000, 10000, 5000, 'Paid', true);
        TestDataFactory.createPayslip(emp.Id, 'July', Date.today().year(), 85000, 0, 5000, 'Generated', true);
    }

    @IsTest
    static void testControllerWithValidPaidPayslip() {
        Payslip__c slip = [SELECT Id, Name FROM Payslip__c WHERE Status__c = 'Paid' LIMIT 1];

        Test.startTest();
        PageReference pageRef = Page.PayslipPDFPage;
        pageRef.getParameters().put('id', slip.Id);
        Test.setCurrentPage(pageRef);

        ApexPages.StandardController stdController = new ApexPages.StandardController(slip);
        PayslipPDFController controller = new PayslipPDFController(stdController);
        Test.stopTest();

        Assert.areEqual('Diana Prince', controller.employeeName, 'Employee Name should match');
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

    @IsTest
    static void testControllerWithGeneratedStatus() {
        Payslip__c slip = [SELECT Id FROM Payslip__c WHERE Status__c = 'Generated' LIMIT 1];

        Test.startTest();
        ApexPages.StandardController stdController = new ApexPages.StandardController(slip);
        PayslipPDFController controller = new PayslipPDFController(stdController);
        Test.stopTest();

        Assert.areEqual('status-approved', controller.getStatusClass(), 'Status class for Generated should be status-approved');
        Assert.isNotNull(controller.employeeEmail, 'Employee email should be populated');
        Assert.isNotNull(controller.workLocation, 'Work location should be populated');
    }

    @IsTest
    static void testControllerWithNullId() {
        Test.startTest();
        Payslip__c emptySlip = new Payslip__c();
        ApexPages.StandardController stdController = new ApexPages.StandardController(emptySlip);
        PayslipPDFController controller = new PayslipPDFController(stdController);
        Test.stopTest();

        Assert.isNull(controller.payslip, 'Payslip should be null when controller has no Id');
    }
}
