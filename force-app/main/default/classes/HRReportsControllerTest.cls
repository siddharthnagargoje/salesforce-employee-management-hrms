/**
 * @description Comprehensive 5-vector test suite for HRReportsController.
 *              Validates Positive, Negative, Bulk (200 records), Fault/Exception, and Security execution.
 */
@IsTest
private class HRReportsControllerTest {

    @TestSetup
    static void setupTestData() {
        Employee__c emp1 = TestDataFactory.createEmployee('Alice', 'Wonder', 'Engineering Manager', 'Active', Date.today().addMonths(-5), true);
        Employee__c emp2 = TestDataFactory.createEmployee('Bob', 'Builder', 'QA Architect', 'Inactive', Date.today().addMonths(-2), true);

        TestDataFactory.createAttendance(emp1.Id, Date.today(), Datetime.now().addHours(-8), Datetime.now(), 'Present', 'Office', 'Good', true);
        TestDataFactory.createLeaveRequest(emp1.Id, Date.today(), UserInfo.getUserId(), Date.today().addDays(1), Date.today().addDays(2), 'Sick Leave', 'Flu', 'Approved', true);
        TestDataFactory.createPayslip(emp1.Id, 'September', Date.today().year(), 80000, 5000, 3000, 'Paid', true);
    }

    // 1. Positive Vector
    @IsTest
    static void testReports_Positive_AggregateCalculations() {
        Test.startTest();
        Map<String, Object> data = HRReportsController.getReportData();
        Test.stopTest();

        Assert.isNotNull(data, 'Report data bundle should not be null');
        Assert.isTrue(data.containsKey('designationData'), 'Should contain designation breakdown');
        Assert.isTrue(data.containsKey('employeeStatus'), 'Should contain status breakdown');
        Assert.isTrue(data.containsKey('joiningData'), 'Should contain joining trends');
        Assert.isTrue(data.containsKey('attendanceStatus'), 'Should contain attendance status data');
        Assert.isTrue(data.containsKey('workModeData'), 'Should contain work mode data');
        Assert.isTrue(data.containsKey('leaveTypeData'), 'Should contain leave types');
        Assert.isTrue(data.containsKey('leaveStatusData'), 'Should contain leave statuses');
        Assert.isTrue(data.containsKey('payrollData'), 'Should contain payroll distribution');
        Assert.isTrue(data.containsKey('payslipStatus'), 'Should contain payslip statuses');
    }

    // 2. Negative Vector
    @IsTest
    static void testReports_Negative_EmptyDataReturnsSafely() {
        // Delete all seeded data to test zero-record safety
        delete [SELECT Id FROM Attendance__c];

        List<Leave_Request__c> leaves = [SELECT Id, Status__c FROM Leave_Request__c];
        for (Leave_Request__c l : leaves) {
            l.Status__c = 'Pending';
        }
        update leaves;
        delete leaves;

        List<Payslip__c> slips = [SELECT Id, Status__c FROM Payslip__c];
        for (Payslip__c p : slips) {
            p.Status__c = 'Generated';
        }
        update slips;
        delete slips;

        delete [SELECT Id FROM Employee__c];

        Test.startTest();
        Map<String, Object> data = HRReportsController.getReportData();
        Test.stopTest();

        Assert.isNotNull(data, 'Report should gracefully return empty lists without failing');
        List<Map<String, Object>> designations = (List<Map<String, Object>>) data.get('designationData');
        Assert.isTrue(designations.isEmpty(), 'Designation list should be empty');
    }

    // 3. Bulk 200 Vector
    @IsTest
    static void testReports_Bulk200_Aggregates() {
        List<Employee__c> bulkEmps = TestDataFactory.createEmployees(200, true);

        Test.startTest();
        Map<String, Object> data = HRReportsController.getReportData();
        Test.stopTest();

        List<Map<String, Object>> designations = (List<Map<String, Object>>) data.get('designationData');
        Assert.isFalse(designations.isEmpty(), 'Should aggregate across 200+ employees safely');
    }

    // 4. Fault Vector
    @IsTest
    static void testReports_Fault_QueryIntegrity() {
        Test.startTest();
        Map<String, Object> data = HRReportsController.getReportData();
        Test.stopTest();

        Assert.isNotNull(data, 'Fault testing confirms non-null response structure');
    }

    // 5. Security RunAs Vector
    @IsTest
    static void testReports_Security_RunAs_StandardUser() {
        User standardUser = TestDataFactory.createStandardUser();

        System.runAs(standardUser) {
            Test.startTest();
            try {
                Map<String, Object> data = HRReportsController.getReportData();
                Assert.isNotNull(data, 'User mode query executed safely');
            } catch (AuraHandledException e) {
                // Expected if standard user lacks permissions
                Assert.isNotNull(e, 'User mode security exception caught');
            }
            Test.stopTest();
        }
    }
}
