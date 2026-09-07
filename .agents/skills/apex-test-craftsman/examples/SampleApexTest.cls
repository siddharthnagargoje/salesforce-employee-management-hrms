/**
 * @description Reference implementation of an enterprise-grade Apex test class.
 * Demonstrates: @TestSetup, bulkification, positive/negative paths, exception handling,
 * and modern Assert class methods.
 */
@IsTest(IsParallel=true)
private class SampleApexTest {

    @TestSetup
    static void makeData() {
        // 1. Create shared test data in isolated test database
        List<Employee__c> employees = new List<Employee__c>();
        for (Integer i = 0; i < 5; i++) {
            employees.add(new Employee__c(
                First_Name__c = 'Test',
                Last_Name__c = 'Emp' + i,
                Employee_Code__c = 'EMP-00' + i,
                Official_Email__c = 'test' + i + '@hrms360.com',
                Status__c = 'Active',
                Salary__c = 50000.00
            ));
        }
        insert employees;
    }

    /**
     * @description Validates positive retrieval of employee record with expected field values.
     */
    @IsTest
    static void testGetEmployeeById_ValidId_ReturnsCompleteEmployeeRecord() {
        // Arrange
        Employee__c expectedEmp = [SELECT Id, First_Name__c, Employee_Code__c FROM Employee__c WHERE Employee_Code__c = 'EMP-000' LIMIT 1];

        // Act
        Test.startTest();
        Employee__c actualEmp = EmployeeService.getEmployeeDetails(expectedEmp.Id);
        Test.stopTest();

        // Assert
        Assert.isNotNull(actualEmp, 'Employee record should be retrieved successfully');
        Assert.areEqual(expectedEmp.Id, actualEmp.Id, 'Record ID must match queried ID');
        Assert.areEqual('Test', actualEmp.First_Name__c, 'First name should match seeded value');
    }

    /**
     * @description Validates negative handling when invalid or null record ID is supplied.
     */
    @IsTest
    static void testGetEmployeeById_InvalidId_ThrowsDescriptiveException() {
        // Arrange
        Id fakeEmployeeId = 'a00000000000001AAA';

        // Act & Assert
        Test.startTest();
        try {
            EmployeeService.getEmployeeDetails(fakeEmployeeId);
            Assert.fail('Expected EntityNotFoundException was not thrown for fake ID');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().contains('not found'), 'Exception message should indicate record not found');
        } catch (Exception ex) {
            Assert.fail('Unexpected exception type: ' + ex.getTypeName());
        }
        Test.stopTest();
    }

    /**
     * @description Bulk test processing 200 records in a single transaction without governor limit exhaustion.
     */
    @IsTest
    static void testCalculateAnnualBonus_BulkTwoHundredRecords_OperatesWithinGovernorLimits() {
        // Arrange
        List<Employee__c> bulkEmployees = new List<Employee__c>();
        for (Integer i = 0; i < 200; i++) {
            bulkEmployees.add(new Employee__c(
                First_Name__c = 'Bulk',
                Last_Name__c = 'Worker' + i,
                Employee_Code__c = 'BLK-' + i,
                Status__c = 'Active',
                Salary__c = 60000.00
            ));
        }
        insert bulkEmployees;

        Set<Id> employeeIds = new Map<Id, Employee__c>(bulkEmployees).keySet();

        // Act
        Test.startTest();
        Map<Id, Decimal> bonusMap = PayrollService.calculateAnnualBonus(employeeIds);
        Test.stopTest();

        // Assert
        Assert.areEqual(200, bonusMap.size(), 'Bonus should be calculated for all 200 employees');
        Assert.areEqual(6000.00, bonusMap.values()[0], 'Bonus should equal 10% of base salary');
    }
}
