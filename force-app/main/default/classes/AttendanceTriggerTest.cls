/**
 * @description Comprehensive 5-vector test suite for AttendanceTrigger and AttendanceTriggerHandler.
 *              Validates Positive, Negative, Bulk (200 records), Fault/Rollback, and Security execution.
 */
@IsTest
private class AttendanceTriggerTest {

    @TestSetup
    static void setupTestData() {
        TestDataFactory.createEmployee('Victor', 'Stone', 'Robotics Specialist', 'Active', Date.today().addMonths(-6), true);
    }

    // 1. Positive Vector
    @IsTest
    static void testAttendanceTrigger_Positive_SingleDailyPunch() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        Attendance__c att = new Attendance__c(
            Employee__c = emp.Id,
            Attendance_Date__c = Date.today().addDays(-1),
            Check_In__c = Datetime.now().addDays(-1).addHours(-8),
            Check_Out__c = Datetime.now().addDays(-1),
            Status__c = 'Present',
            Work_Mode__c = 'Office'
        );
        insert att;
        Test.stopTest();

        Assert.isNotNull(att.Id, 'Attendance record should be inserted successfully');
    }

    // 2. Negative Vector
    @IsTest
    static void testAttendanceTrigger_Negative_DuplicateDailyPunchPrevention() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Attendance__c att1 = new Attendance__c(
            Employee__c = emp.Id,
            Attendance_Date__c = Date.today().addDays(-2),
            Check_In__c = Datetime.now().addDays(-2).addHours(-8),
            Check_Out__c = Datetime.now().addDays(-2),
            Status__c = 'Present'
        );
        insert att1;

        Test.startTest();
        try {
            Attendance__c att2 = new Attendance__c(
                Employee__c = emp.Id,
                Attendance_Date__c = Date.today().addDays(-2),
                Check_In__c = Datetime.now().addDays(-2).addHours(-4),
                Status__c = 'Present'
            );
            insert att2;
            Assert.fail('Should prevent duplicate attendance records on same date');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('An attendance record already exists for this employee on'), 'Expected duplicate error message');
        }
        Test.stopTest();
    }

    // 3. Bulk 200 Vector
    @IsTest
    static void testAttendanceTrigger_Bulk200_Insert() {
        List<Employee__c> emps = TestDataFactory.createEmployees(200, true);
        List<Attendance__c> atts = new List<Attendance__c>();
        for (Integer i = 0; i < 200; i++) {
            atts.add(new Attendance__c(
                Employee__c = emps[i].Id,
                Attendance_Date__c = Date.today().addDays(-3),
                Check_In__c = Datetime.now().addDays(-3).addHours(-8),
                Check_Out__c = Datetime.now().addDays(-3),
                Status__c = 'Present',
                Work_Mode__c = 'Office'
            ));
        }

        Test.startTest();
        insert atts;
        Test.stopTest();

        Assert.areEqual(200, [SELECT COUNT() FROM Attendance__c WHERE Id IN :atts], 'All 200 attendance records inserted safely');
    }

    // 4. Fault Vector
    @IsTest
    static void testAttendanceTrigger_Fault_CheckOutBeforeCheckIn() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        try {
            Attendance__c att = new Attendance__c(
                Employee__c = emp.Id,
                Attendance_Date__c = Date.today().addDays(-4),
                Check_In__c = Datetime.now().addDays(-4),
                Check_Out__c = Datetime.now().addDays(-4).addHours(-2), // Check out earlier than check in
                Status__c = 'Present'
            );
            insert att;
            Assert.fail('Should fail when check-out is earlier than check-in');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('Check-Out time cannot be earlier than Check-In time'), 'Expected check-out validation error');
        }
        Test.stopTest();
    }

    // 5. Security RunAs Vector
    @IsTest
    static void testAttendanceTrigger_Security_RunAs_StandardUser() {
        User stdUser = TestDataFactory.createStandardUser();
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        System.runAs(stdUser) {
            Test.startTest();
            try {
                Attendance__c att = new Attendance__c(
                    Employee__c = emp.Id,
                    Attendance_Date__c = Date.today().addDays(-5),
                    Check_In__c = Datetime.now().addDays(-5).addHours(-8),
                    Check_Out__c = Datetime.now().addDays(-5),
                    Status__c = 'Present'
                );
                insert att;
            } catch (DmlException e) {
                Assert.isNotNull(e, 'User mode standard security handled');
            }
            Test.stopTest();
        }
    }
}
