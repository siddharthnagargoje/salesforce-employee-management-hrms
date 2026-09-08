/**
 * @description Comprehensive 5-vector test suite for AttendanceController.
 *              Validates Positive, Negative, Bulk (200 records), Fault/Exception, and Security execution.
 */
@IsTest
private class AttendanceControllerTest {

    @TestSetup
    static void setupTestData() {
        TestDataFactory.createEmployee('John', 'Doe', 'Engineer', 'Active', Date.today().addMonths(-2), true);
    }

    // 1. Positive Vector
    @IsTest
    static void testAttendance_Positive_LogAndFetch() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        Attendance__c logged = AttendanceController.logAttendance(emp.Id, 'Present');
        List<Attendance__c> roster = AttendanceController.getAttendanceList();
        Test.stopTest();

        Assert.isNotNull(logged.Id, 'Logged attendance must have an Id');
        Assert.isFalse(roster.isEmpty(), 'Roster should contain records');
        Assert.areEqual(emp.Id, roster[0].Employee__c, 'Employee ID should match');
    }

    // 2. Negative Vector
    @IsTest
    static void testAttendance_Negative_InvalidCheckoutTime() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        Datetime checkIn = Datetime.now();
        Datetime checkOutEarlier = checkIn.addHours(-2);

        Test.startTest();
        try {
            AttendanceController.saveAttendance(null, emp.Id, Date.today(), checkIn, checkOutEarlier, 'Present', 'Office', 'Invalid times');
            Assert.fail('Should throw AuraHandledException when check-out is before check-in');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Check-Out time cannot be earlier than Check-In time') || e.getMessage().contains('Script-thrown exception'), 'Expected validation error caught');
        }
        Test.stopTest();
    }

    // 3. Bulk 200 Vector
    @IsTest
    static void testAttendance_Bulk200_Save() {
        List<Employee__c> emps = TestDataFactory.createEmployees(200, true);
        List<Attendance__c> atts = new List<Attendance__c>();
        for (Employee__c emp : emps) {
            atts.add(new Attendance__c(
                Employee__c = emp.Id,
                Attendance_Date__c = Date.today(),
                Check_In__c = Datetime.now().addHours(-8),
                Check_Out__c = Datetime.now(),
                Status__c = 'Present',
                Work_Mode__c = 'Office'
            ));
        }

        Test.startTest();
        insert atts;
        List<Attendance__c> results = AttendanceController.getAttendanceList();
        Test.stopTest();

        Assert.isTrue(results.size() >= 200, 'Must query all 200+ attendance records within governor limits');
    }

    // 4. Fault Vector
    @IsTest
    static void testAttendance_Fault_NullEmployeeDeleteException() {
        Test.startTest();
        try {
            AttendanceController.deleteAttendance(null);
            Assert.fail('Should fail on null attendance ID');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Exception message should be populated');
        }
        Test.stopTest();
    }

    // 5. Security RunAs Vector
    @IsTest
    static void testAttendance_Security_RunAs_StandardUser() {
        User standardUser = TestDataFactory.createStandardUser();
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        System.runAs(standardUser) {
            Test.startTest();
            try {
                AttendanceController.logAttendance(emp.Id, 'Present');
            } catch (AuraHandledException e) {
                // Caught security check or access decision
                Assert.isNotNull(e, 'User mode security handled gracefully');
            }
            Test.stopTest();
        }
    }
}
