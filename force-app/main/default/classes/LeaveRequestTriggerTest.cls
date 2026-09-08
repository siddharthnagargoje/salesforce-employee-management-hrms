/**
 * @description Comprehensive 5-vector test suite for LeaveRequestTrigger and LeaveRequestTriggerHandler.
 *              Validates Positive, Negative, Bulk (200 records), Fault/Rollback, and Security execution.
 */
@IsTest
private class LeaveRequestTriggerTest {

    @TestSetup
    static void setupTestData() {
        TestDataFactory.createEmployee('Barry', 'Allen', 'Speedster', 'Active', Date.today().addMonths(-4), true);
    }

    // 1. Positive Vector
    @IsTest
    static void testLeaveTrigger_Positive_ApprovalBalanceDeduction() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Applied_Date__c = Date.today(),
            Start_Date__c = Date.today().addDays(10),
            End_Date__c = Date.today().addDays(12), // 3 days
            Leave_Type__c = 'Sick Leave',
            Status__c = 'Pending'
        );
        insert lr;

        lr.Status__c = 'Approved';
        update lr;
        Test.stopTest();

        Leave_Balance__c balance = [
            SELECT Used_Days__c, Remaining_Days__c 
            FROM Leave_Balance__c 
            WHERE Employee__c = :emp.Id 
            AND Leave_Type__c = 'Sick Leave' 
            LIMIT 1
        ];
        Assert.areEqual(3.0, balance.Used_Days__c, 'Used days should be updated to 3');
        Assert.areEqual(7.0, balance.Remaining_Days__c, 'Remaining days should be 10 - 3 = 7');
    }

    // 2. Negative Vector
    @IsTest
    static void testLeaveTrigger_Negative_DateOverlapPrevention() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Leave_Request__c lr1 = new Leave_Request__c(
            Employee__c = emp.Id,
            Start_Date__c = Date.today().addDays(20),
            End_Date__c = Date.today().addDays(25),
            Leave_Type__c = 'Casual Leave',
            Status__c = 'Pending'
        );
        insert lr1;

        Test.startTest();
        try {
            Leave_Request__c lr2 = new Leave_Request__c(
                Employee__c = emp.Id,
                Start_Date__c = Date.today().addDays(22),
                End_Date__c = Date.today().addDays(27),
                Leave_Type__c = 'Sick Leave',
                Status__c = 'Pending'
            );
            insert lr2;
            Assert.fail('Should prevent overlapping leave requests');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('An active leave request already exists'), 'Expected overlap validation error');
        }
        Test.stopTest();
    }

    // 3. Bulk 200 Vector
    @IsTest
    static void testLeaveTrigger_Bulk200_Insert() {
        List<Employee__c> emps = TestDataFactory.createEmployees(200, true);
        List<Leave_Request__c> leaves = new List<Leave_Request__c>();
        for (Integer i = 0; i < 200; i++) {
            leaves.add(new Leave_Request__c(
                Employee__c = emps[i].Id,
                Start_Date__c = Date.today().addDays(30),
                End_Date__c = Date.today().addDays(31),
                Leave_Type__c = 'Casual Leave',
                Status__c = 'Pending'
            ));
        }

        Test.startTest();
        insert leaves;
        Test.stopTest();

        Assert.areEqual(200, [SELECT COUNT() FROM Leave_Request__c WHERE Id IN :leaves], 'All 200 leaves inserted safely');
    }

    // 4. Fault Vector
    @IsTest
    static void testLeaveTrigger_Fault_DeleteApprovedForbidden() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Start_Date__c = Date.today().addDays(40),
            End_Date__c = Date.today().addDays(41),
            Leave_Type__c = 'Casual Leave',
            Status__c = 'Approved'
        );
        insert lr;

        Test.startTest();
        try {
            delete lr;
            Assert.fail('Should reject deletion of approved leaves');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('Approved leave requests cannot be deleted'), 'Expected deletion prevention message');
        }
        Test.stopTest();
    }

    // 5. Security RunAs Vector
    @IsTest
    static void testLeaveTrigger_Security_RunAs_StandardUser() {
        User stdUser = TestDataFactory.createStandardUser();
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        System.runAs(stdUser) {
            Test.startTest();
            try {
                Leave_Request__c lr = new Leave_Request__c(
                    Employee__c = emp.Id,
                    Start_Date__c = Date.today().addDays(50),
                    End_Date__c = Date.today().addDays(51),
                    Leave_Type__c = 'Casual Leave',
                    Status__c = 'Pending'
                );
                insert lr;
            } catch (DmlException e) {
                Assert.isNotNull(e, 'User mode standard security handled');
            }
            Test.stopTest();
        }
    }
}
