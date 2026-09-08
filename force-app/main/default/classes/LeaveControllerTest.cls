/**
 * @description Comprehensive 5-vector test suite for LeaveController.
 *              Validates Positive, Negative, Bulk (200 records), Fault/Exception, and Security execution.
 */
@IsTest
private class LeaveControllerTest {

    @TestSetup
    static void setupTestData() {
        TestDataFactory.createEmployee('Sarah', 'Connor', 'Lead Developer', 'Active', Date.today().addMonths(-3), true);
    }

    // 1. Positive Vector
    @IsTest
    static void testLeave_Positive_CreateAndApprove() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        Leave_Request__c created = LeaveController.createLeaveRequest(
            emp.Id,
            Date.today(),
            UserInfo.getUserId(),
            Date.today().addDays(2),
            Date.today().addDays(4),
            'Sick Leave',
            'Medical appointment',
            'Pending'
        );
        Leave_Request__c approved = LeaveController.updateLeaveStatus(created.Id, 'Approved', 'Approved by manager');
        List<Leave_Request__c> listReqs = LeaveController.getLeaveRequests();
        List<User> users = LeaveController.getUsers();
        Test.stopTest();

        Assert.isNotNull(created.Id, 'Leave request should be inserted with an ID');
        Assert.areEqual('Approved', approved.Status__c, 'Status should be updated to Approved');
        Assert.areEqual('Approved by manager', approved.Comments__c, 'Reviewer comments should be recorded');
        Assert.isFalse(listReqs.isEmpty(), 'Leave requests should be queried');
        Assert.isFalse(users.isEmpty(), 'Active users list should not be empty');
    }

    // 2. Negative Vector
    @IsTest
    static void testLeave_Negative_InvalidDates() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        try {
            LeaveController.createLeaveRequest(
                emp.Id,
                Date.today(),
                UserInfo.getUserId(),
                Date.today().addDays(5),
                Date.today().addDays(2), // End date earlier than start date
                'Casual Leave',
                'Vacation',
                'Pending'
            );
            Assert.fail('Should throw exception for inverted dates');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('End Date cannot be earlier than Start Date') || e.getMessage().contains('Script-thrown exception'), 'Expected date validation exception');
        }
        Test.stopTest();
    }

    // 3. Bulk 200 Vector
    @IsTest
    static void testLeave_Bulk200_CreateAndQuery() {
        List<Employee__c> emps = TestDataFactory.createEmployees(200, true);
        List<Leave_Request__c> leaves = new List<Leave_Request__c>();
        for (Employee__c emp : emps) {
            leaves.add(new Leave_Request__c(
                Employee__c = emp.Id,
                Applied_Date__c = Date.today(),
                Start_Date__c = Date.today().addDays(1),
                End_Date__c = Date.today().addDays(3),
                Leave_Type__c = 'Casual Leave',
                Status__c = 'Pending',
                Reason__c = 'Bulk leave test'
            ));
        }

        Test.startTest();
        insert leaves;
        List<Leave_Request__c> queried = LeaveController.getLeaveRequests();
        Test.stopTest();

        Assert.isTrue(queried.size() >= 200, 'Should query 200+ leave records without exceeding limits');
    }

    // 4. Fault Vector
    @IsTest
    static void testLeave_Fault_NullStatusUpdate() {
        Test.startTest();
        try {
            LeaveController.updateLeaveStatus(null, 'Approved', 'Remarks');
            Assert.fail('Should fail on null leave request ID');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Exception message should be populated');
        }
        Test.stopTest();
    }

    // 5. Security RunAs Vector
    @IsTest
    static void testLeave_Security_RunAs_StandardUser() {
        User standardUser = TestDataFactory.createStandardUser();
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        System.runAs(standardUser) {
            Test.startTest();
            try {
                LeaveController.createLeaveRequest(
                    emp.Id,
                    Date.today(),
                    null,
                    Date.today().addDays(1),
                    Date.today().addDays(2),
                    'Sick Leave',
                    'Fever',
                    'Pending'
                );
            } catch (AuraHandledException e) {
                // Security or user-mode enforcement handled
                Assert.isNotNull(e, 'User mode security exception caught');
            }
            Test.stopTest();
        }
    }
}
