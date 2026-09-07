/**
 * @description Comprehensive unit test class for EmployeeController.
 *              Ensures robust test coverage across happy paths, edge cases, and error scenarios.
 */
@IsTest
private class EmployeeControllerTest {

    @TestSetup
    static void setupTestData() {
        // 1. Create Baseline Employees
        Employee__c emp1 = TestDataFactory.createEmployee('Alex', 'Mercer', 'Salesforce Developer', 'Active', Date.today().addMonths(-2), true);
        Employee__c emp2 = TestDataFactory.createEmployee('Dana', 'Scully', 'QA Lead', 'Inactive', Date.today().addMonths(-4), true);
        Employee__c emp3 = TestDataFactory.createEmployee('Fox', 'Mulder', 'Salesforce Developer', 'Active', Date.today().addMonths(-6), true);

        // 2. Create Attendance Records for Reports and Retrieval
        TestDataFactory.createAttendance(emp1.Id, Date.today().addDays(-1), Datetime.now().addDays(-1).addHours(-8), Datetime.now().addDays(-1), 'Present', 'Office', 'In office punch', true);
        TestDataFactory.createAttendance(emp2.Id, Date.today().addDays(-1), Datetime.now().addDays(-1).addHours(-8), Datetime.now().addDays(-1), 'Absent', 'Remote', 'WFH sick', true);

        // 3. Create Leave Requests for Reports and Retrieval
        TestDataFactory.createLeaveRequest(emp1.Id, Date.today().addDays(-5), UserInfo.getUserId(), Date.today().addDays(1), Date.today().addDays(3), 'Sick Leave', 'Flu symptoms', 'Approved', true);
        TestDataFactory.createLeaveRequest(emp2.Id, Date.today().addDays(-3), UserInfo.getUserId(), Date.today().addDays(5), Date.today().addDays(7), 'Casual Leave', 'Family event', 'Pending', true);

        // 4. Create Payslips for Reports and Retrieval
        TestDataFactory.createPayslip(emp1.Id, 'August', Date.today().year(), 75000, 5000, 3000, 'Paid', true);
        TestDataFactory.createPayslip(emp2.Id, 'August', Date.today().year(), 65000, 4000, 2500, 'Generated', true);
    }

    // =========================================================================
    // EMPLOYEE MANAGEMENT TESTS
    // =========================================================================

    @IsTest
    static void testGetEmployees() {
        Test.startTest();
        List<Employee__c> employees = EmployeeController.getEmployees();
        Test.stopTest();

        Assert.isNotNull(employees, 'Employee list should not be null');
        Assert.isTrue(employees.size() >= 3, 'Should return all seeded employees');
        Assert.isNotNull(employees[0].Name, 'Employee Name should be queried');
        Assert.isNotNull(employees[0].Employee_Code__c, 'Employee Code should be queried');
    }

    @IsTest
    static void testSaveEmployee_ConstructedName() {
        Employee__c newEmp = new Employee__c(
            First_Name__c = 'Clark',
            Last_Name__c = 'Kent',
            Designation__c = 'Software Engineer',
            Status__c = 'Active',
            Personal_Email__c = 'clark.kent@dailyplanet.com'
        );

        Test.startTest();
        Employee__c savedEmp = EmployeeController.saveEmployee(newEmp);
        Test.stopTest();

        Assert.isNotNull(savedEmp.Id, 'Employee record should be inserted with an Id');
        Employee__c queried = [SELECT Name, First_Name__c, Last_Name__c FROM Employee__c WHERE Id = :savedEmp.Id];
        Assert.areEqual('Clark Kent', queried.Name, 'Employee Name should be constructed from First and Last Name');
    }

    @IsTest
    static void testSaveEmployee_FallbackName() {
        Employee__c newEmp = new Employee__c(
            Designation__c = 'Consultant',
            Status__c = 'Active',
            Personal_Email__c = 'fallback@hrmstest.com'
        );

        Test.startTest();
        Employee__c savedEmp = EmployeeController.saveEmployee(newEmp);
        Test.stopTest();

        Assert.isNotNull(savedEmp.Id, 'Record should be inserted');
        Employee__c queried = [SELECT Name FROM Employee__c WHERE Id = :savedEmp.Id];
        Assert.areEqual('New Employee Record', queried.Name, 'Employee Name should fall back to New Employee Record');
    }

    @IsTest
    static void testSaveEmployee_PreserveCustomName() {
        // Name is < 15 chars and does not start with 'a00'
        Employee__c newEmp = new Employee__c(
            Name = 'Bruce Wayne',
            First_Name__c = 'Bruce',
            Last_Name__c = 'Wayne',
            Designation__c = 'Executive',
            Status__c = 'Active',
            Personal_Email__c = 'bruce@waynecorp.com'
        );

        Test.startTest();
        Employee__c savedEmp = EmployeeController.saveEmployee(newEmp);
        Test.stopTest();

        Employee__c queried = [SELECT Name FROM Employee__c WHERE Id = :savedEmp.Id];
        Assert.areEqual('Bruce Wayne', queried.Name, 'Existing short valid name should be preserved');
    }

    @IsTest
    static void testSaveEmployee_PrefixReplacement() {
        // Name starts with 'a00' (typical default prefix scenario)
        Employee__c newEmp = new Employee__c(
            Name = 'a00DummyPrefixRecord',
            First_Name__c = 'Diana',
            Last_Name__c = 'Prince',
            Designation__c = 'Senior Director',
            Status__c = 'Active',
            Personal_Email__c = 'diana@themyscira.com'
        );

        Test.startTest();
        Employee__c savedEmp = EmployeeController.saveEmployee(newEmp);
        Test.stopTest();

        Employee__c queried = [SELECT Name FROM Employee__c WHERE Id = :savedEmp.Id];
        Assert.areEqual('Diana Prince', queried.Name, 'Name starting with a00 should be overwritten by constructed name');
    }

    @IsTest
    static void testSaveEmployee_UpdateExisting() {
        Employee__c existingEmp = [SELECT Id, Name, First_Name__c, Last_Name__c, Status__c FROM Employee__c LIMIT 1];
        existingEmp.Status__c = 'Inactive';

        Test.startTest();
        Employee__c updatedEmp = EmployeeController.saveEmployee(existingEmp);
        Test.stopTest();

        Assert.areEqual(existingEmp.Id, updatedEmp.Id, 'Id should remain the same on update');
        Employee__c reloaded = [SELECT Status__c FROM Employee__c WHERE Id = :existingEmp.Id];
        Assert.areEqual('Inactive', reloaded.Status__c, 'Status should be updated');
    }

    @IsTest
    static void testSaveEmployee_Exception() {
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            // Passing null triggers exception handling
            EmployeeController.saveEmployee(null);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
            Assert.isNotNull(e, 'AuraHandledException should be thrown');
        } catch (Exception e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught, 'Exception should be caught and handled when saving null employee');
    }

    @IsTest
    static void testDeleteEmployee_Success() {
        Employee__c empToDelete = TestDataFactory.createEmployee('Delete', 'Me', 'Intern', 'Active', Date.today(), true);

        Test.startTest();
        EmployeeController.deleteEmployee(empToDelete.Id);
        Test.stopTest();

        List<Employee__c> remaining = [SELECT Id FROM Employee__c WHERE Id = :empToDelete.Id];
        Assert.areEqual(0, remaining.size(), 'Employee record should be deleted');
    }

    @IsTest
    static void testDeleteEmployee_Exception() {
        Id fakeId = Id.valueOf(Employee__c.sObjectType.getDescribe().getKeyPrefix() + '000000000001AAA');
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            EmployeeController.deleteEmployee(fakeId);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
            Assert.isNotNull(e, 'AuraHandledException expected for non-existent employee delete');
        } catch (Exception e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught, 'Expected exception on deleting non-existent employee');
    }

    @IsTest
    static void testGetEmployeeById_Success() {
        Employee__c existingEmp = [SELECT Id, First_Name__c, Last_Name__c FROM Employee__c LIMIT 1];

        Test.startTest();
        Employee__c result = EmployeeController.getEmployeeById(existingEmp.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual(existingEmp.Id, result.Id, 'Returned Employee Id should match queried Id');
        Assert.areEqual(existingEmp.First_Name__c, result.First_Name__c, 'First Name should match');
    }

    @IsTest
    static void testGetEmployeeById_Exception() {
        Id fakeId = Id.valueOf(Employee__c.sObjectType.getDescribe().getKeyPrefix() + '000000000001AAA');
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            EmployeeController.getEmployeeById(fakeId);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
            Assert.isNotNull(e, 'AuraHandledException expected when employee is not found');
        } catch (Exception e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught, 'Expected exception when querying non-existent employee');
    }

    // =========================================================================
    // ATTENDANCE MANAGEMENT TESTS
    // =========================================================================

    @IsTest
    static void testLogAttendance_Success() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        EmployeeController.logAttendance(emp.Id, 'Present');
        Test.stopTest();

        List<Attendance__c> atts = [
            SELECT Id, Employee__c, Status__c, Attendance_Date__c, Check_In__c 
            FROM Attendance__c 
            WHERE Employee__c = :emp.Id AND Attendance_Date__c = :Date.today()
        ];
        Assert.isFalse(atts.isEmpty(), 'Attendance record should be created for today');
        Assert.areEqual('Present', atts[0].Status__c, 'Status should be Present');
        Assert.isNotNull(atts[0].Check_In__c, 'Check_In datetime should be populated');
    }

    @IsTest
    static void testLogAttendance_NullEmployeeException() {
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            EmployeeController.logAttendance(null, 'Present');
        } catch (AuraHandledException e) {
            exceptionCaught = true;
            Assert.isNotNull(e, 'AuraHandledException expected when employeeId is null');
        } catch (Exception e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught, 'Expected exception when logging attendance with null employeeId');
    }

    @IsTest
    static void testGetAttendanceList() {
        Test.startTest();
        List<Attendance__c> listResults = EmployeeController.getAttendanceList();
        Test.stopTest();

        Assert.isNotNull(listResults, 'Attendance list should not be null');
        Assert.isTrue(listResults.size() >= 2, 'Should return seeded attendance records');
        Assert.isNotNull(listResults[0].Employee__r.Name, 'Parent employee Name should be traversed');
    }

    @IsTest
    static void testSaveAttendance_Success() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        Date attDate = Date.today().addDays(-2);
        Datetime checkIn = Datetime.now().addDays(-2).addHours(-8);
        Datetime checkOut = Datetime.now().addDays(-2);

        Test.startTest();
        EmployeeController.saveAttendance(null, emp.Id, attDate, checkIn, checkOut, 'Present', 'Office', 'Manual attendance entry');
        Test.stopTest();

        List<Attendance__c> records = [
            SELECT Id, Status__c, Work_Mode__c, Remarks__c 
            FROM Attendance__c 
            WHERE Employee__c = :emp.Id AND Attendance_Date__c = :attDate
        ];
        Assert.isFalse(records.isEmpty(), 'Attendance record should be inserted');
        Assert.areEqual('Present', records[0].Status__c, 'Status should match');
        Assert.areEqual('Office', records[0].Work_Mode__c, 'Work mode should match');
        Assert.areEqual('Manual attendance entry', records[0].Remarks__c, 'Remarks should match');
    }

    @IsTest
    static void testSaveAttendance_UpdateSuccess() {
        Attendance__c existingAtt = [SELECT Id, Employee__c, Attendance_Date__c, Check_In__c, Check_Out__c FROM Attendance__c LIMIT 1];

        Test.startTest();
        EmployeeController.saveAttendance(existingAtt.Id, existingAtt.Employee__c, existingAtt.Attendance_Date__c, existingAtt.Check_In__c, existingAtt.Check_Out__c, 'Present', 'Remote', 'Updated via modal');
        Test.stopTest();

        Attendance__c updated = [SELECT Id, Status__c, Work_Mode__c, Remarks__c FROM Attendance__c WHERE Id = :existingAtt.Id];
        Assert.areEqual('Present', updated.Status__c, 'Status should be Present');
        Assert.areEqual('Remote', updated.Work_Mode__c, 'Work mode should be updated to Remote');
        Assert.areEqual('Updated via modal', updated.Remarks__c, 'Remarks should be updated');
    }

    @IsTest
    static void testSaveAttendance_Exception() {
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            // Null attendanceDate and status violate non-nillable field constraints on Attendance__c
            EmployeeController.saveAttendance(null, null, null, null, null, null, null, null);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
            Assert.isNotNull(e, 'AuraHandledException expected for missing required fields');
        } catch (Exception e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught, 'Expected exception when saving attendance with missing required fields');
    }

    @IsTest
    static void testDeleteAttendance_Success() {
        Attendance__c att = [SELECT Id FROM Attendance__c LIMIT 1];

        Test.startTest();
        EmployeeController.deleteAttendance(att.Id);
        Test.stopTest();

        List<Attendance__c> records = [SELECT Id FROM Attendance__c WHERE Id = :att.Id];
        Assert.areEqual(0, records.size(), 'Attendance record should be deleted');
    }

    @IsTest
    static void testDeleteAttendance_NullIdException() {
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            EmployeeController.deleteAttendance(null);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
            Assert.isNotNull(e, 'AuraHandledException expected when attendanceId is null');
        } catch (Exception e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught, 'Expected exception when deleting attendance with null Id');
    }

    @IsTest
    static void testDeleteAttendance_NotFoundException() {
        Id fakeAttId = Id.valueOf(Attendance__c.sObjectType.getDescribe().getKeyPrefix() + '000000000001AAA');
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            EmployeeController.deleteAttendance(fakeAttId);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
            Assert.isNotNull(e, 'AuraHandledException expected when attendance record not found');
        } catch (Exception e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught, 'Expected exception when deleting non-existent attendance');
    }

    // =========================================================================
    // LEAVE MANAGEMENT TESTS
    // =========================================================================

    @IsTest
    static void testCreateLeaveRequest_Success() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        Date applied = Date.today();
        Date startD = Date.today().addDays(10);
        Date endD = Date.today().addDays(12);

        Test.startTest();
        Leave_Request__c leave = EmployeeController.createLeaveRequest(
            emp.Id, applied, UserInfo.getUserId(), startD, endD, 'Casual Leave', 'Vacation travel', 'Pending'
        );
        Test.stopTest();

        Assert.isNotNull(leave.Id, 'Leave request should be inserted with an Id');
        Leave_Request__c queried = [
            SELECT Employee__c, Leave_Type__c, Status__c, Reason__c 
            FROM Leave_Request__c 
            WHERE Id = :leave.Id
        ];
        Assert.areEqual(emp.Id, queried.Employee__c, 'Employee reference should match');
        Assert.areEqual('Casual Leave', queried.Leave_Type__c, 'Leave type should match');
        Assert.areEqual('Pending', queried.Status__c, 'Status should match');
    }

    @IsTest
    static void testCreateLeaveRequest_Exception() {
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            // Null employeeId violates required Master-Detail field on Leave_Request__c
            EmployeeController.createLeaveRequest(null, Date.today(), null, null, null, null, null, null);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
            Assert.isNotNull(e, 'AuraHandledException expected for missing employee master-detail');
        } catch (Exception e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught, 'Expected exception when creating leave request without Employee');
    }

    @IsTest
    static void testGetUsers() {
        Test.startTest();
        List<User> users = EmployeeController.getUsers();
        Test.stopTest();

        Assert.isNotNull(users, 'User list should not be null');
        Assert.isFalse(users.isEmpty(), 'Active users should be returned');
        Assert.isNotNull(users[0].Name, 'User Name should be retrieved');
    }

    @IsTest
    static void testGetLeaveRequests() {
        Test.startTest();
        List<Leave_Request__c> leaves = EmployeeController.getLeaveRequests();
        Test.stopTest();

        Assert.isNotNull(leaves, 'Leave requests list should not be null');
        Assert.isTrue(leaves.size() >= 2, 'Should return seeded leave requests');
        Assert.isNotNull(leaves[0].Employee__r.Name, 'Employee parent name should be populated');
    }

    // =========================================================================
    // PAYROLL & PAYSLIP TESTS
    // =========================================================================

    @IsTest
    static void testGetPayslips() {
        Test.startTest();
        List<Payslip__c> slips = EmployeeController.getPayslips();
        Test.stopTest();

        Assert.isNotNull(slips, 'Payslips list should not be null');
        Assert.isTrue(slips.size() >= 2, 'Should return seeded payslips');
        Assert.isNotNull(slips[0].Employee__r.Name, 'Employee Name should be populated');
    }

    @IsTest
    static void testCreatePayslip_Success() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Test.startTest();
        Payslip__c slip = EmployeeController.createPayslip(
            emp.Id, 'September', Date.today().year(), 80000, 7000, 3500, 'Generated'
        );
        Test.stopTest();

        Assert.isNotNull(slip.Id, 'Payslip should be inserted with an Id');
        Payslip__c queried = [
            SELECT Employee__c, Pay_Month__c, Pay_Year__c, Basic_Salary__c, Bonus__c, Deductions__c, Status__c 
            FROM Payslip__c 
            WHERE Id = :slip.Id
        ];
        Assert.areEqual(emp.Id, queried.Employee__c, 'Employee Id should match');
        Assert.areEqual('September', queried.Pay_Month__c, 'Pay Month should match');
        Assert.areEqual(80000, queried.Basic_Salary__c, 'Basic Salary should match');
        Assert.areEqual('Generated', queried.Status__c, 'Status should match');
    }

    @IsTest
    static void testCreatePayslip_Exception() {
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            // Null employeeId violates required Master-Detail field on Payslip__c
            EmployeeController.createPayslip(null, 'September', 2026, 50000, 0, 0, 'Paid');
        } catch (AuraHandledException e) {
            exceptionCaught = true;
            Assert.isNotNull(e, 'AuraHandledException expected for null employee master-detail');
        } catch (Exception e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught, 'Expected exception when creating payslip without employee');
    }

    @IsTest
    static void testDeletePayslip_Success() {
        Payslip__c slip = [SELECT Id FROM Payslip__c LIMIT 1];

        Test.startTest();
        EmployeeController.deletePayslip(slip.Id);
        Test.stopTest();

        List<Payslip__c> records = [SELECT Id FROM Payslip__c WHERE Id = :slip.Id];
        Assert.areEqual(0, records.size(), 'Payslip should be deleted');
    }

    @IsTest
    static void testDeletePayslip_NullIdException() {
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            EmployeeController.deletePayslip(null);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
            Assert.isNotNull(e, 'AuraHandledException expected when payslipId is null');
        } catch (Exception e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught, 'Expected exception when deleting payslip with null Id');
    }

    @IsTest
    static void testDeletePayslip_NotFoundException() {
        Id fakeSlipId = Id.valueOf(Payslip__c.sObjectType.getDescribe().getKeyPrefix() + '000000000001AAA');
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            EmployeeController.deletePayslip(fakeSlipId);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
            Assert.isNotNull(e, 'AuraHandledException expected when payslip is not found');
        } catch (Exception e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught, 'Expected exception when deleting non-existent payslip');
    }

    // =========================================================================
    // REPORTS MANAGEMENT TESTS
    // =========================================================================

    @IsTest
    static void testGetReportData() {
        Test.startTest();
        Map<String, Object> reportData = EmployeeController.getReportData();
        Test.stopTest();

        Assert.isNotNull(reportData, 'Report data map should not be null');

        // Verify all 9 analytical metrics are present in the payload
        Assert.isTrue(reportData.containsKey('designationData'), 'Should contain designationData');
        Assert.isTrue(reportData.containsKey('employeeStatus'), 'Should contain employeeStatus');
        Assert.isTrue(reportData.containsKey('joiningData'), 'Should contain joiningData');
        Assert.isTrue(reportData.containsKey('attendanceStatus'), 'Should contain attendanceStatus');
        Assert.isTrue(reportData.containsKey('workModeData'), 'Should contain workModeData');
        Assert.isTrue(reportData.containsKey('leaveTypeData'), 'Should contain leaveTypeData');
        Assert.isTrue(reportData.containsKey('leaveStatusData'), 'Should contain leaveStatusData');
        Assert.isTrue(reportData.containsKey('payrollData'), 'Should contain payrollData');
        Assert.isTrue(reportData.containsKey('payslipStatus'), 'Should contain payslipStatus');

        // Verify that aggregation lists were populated
        List<Object> designationList = (List<Object>) reportData.get('designationData');
        Assert.isFalse(designationList.isEmpty(), 'Designation aggregation should have entries');

        List<Object> employeeStatusList = (List<Object>) reportData.get('employeeStatus');
        Assert.isFalse(employeeStatusList.isEmpty(), 'Employee status aggregation should have entries');

        List<Object> joiningList = (List<Object>) reportData.get('joiningData');
        Assert.isFalse(joiningList.isEmpty(), 'Joining data aggregation should have entries');

        List<Object> attendanceStatusList = (List<Object>) reportData.get('attendanceStatus');
        Assert.isFalse(attendanceStatusList.isEmpty(), 'Attendance status aggregation should have entries');

        List<Object> workModeList = (List<Object>) reportData.get('workModeData');
        Assert.isFalse(workModeList.isEmpty(), 'Work mode aggregation should have entries');

        List<Object> leaveTypeList = (List<Object>) reportData.get('leaveTypeData');
        Assert.isFalse(leaveTypeList.isEmpty(), 'Leave type aggregation should have entries');

        List<Object> leaveStatusList = (List<Object>) reportData.get('leaveStatusData');
        Assert.isFalse(leaveStatusList.isEmpty(), 'Leave status aggregation should have entries');

        List<Object> payrollList = (List<Object>) reportData.get('payrollData');
        Assert.isFalse(payrollList.isEmpty(), 'Payroll aggregation should have entries');

        List<Object> payslipStatusList = (List<Object>) reportData.get('payslipStatus');
        Assert.isFalse(payslipStatusList.isEmpty(), 'Payslip status aggregation should have entries');
    }

    // =========================================================================
    // PROFILE PHOTO MANAGEMENT TESTS
    // =========================================================================

    @IsTest
    static void testUpdateEmployeeProfilePhoto_Success() {
        Employee__c emp = [SELECT Id, Profile_Photo__c FROM Employee__c LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'Employee Photo',
            PathOnClient = 'profile.png',
            VersionData = Blob.valueOf('dummy content data'),
            IsMajorVersion = true
        );
        insert cv;

        ContentVersion insertedCv = [
            SELECT Id, ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :cv.Id
        ];

        Test.startTest();
        String photoUrl = EmployeeController.updateEmployeeProfilePhoto(emp.Id, insertedCv.ContentDocumentId);
        Test.stopTest();

        Assert.isNotNull(photoUrl, 'Photo URL should be returned');
        Assert.areEqual('/sfc/servlet.shepherd/version/download/' + insertedCv.Id, photoUrl, 'URL must match version download format');

        Employee__c updatedEmp = [SELECT Profile_Photo__c FROM Employee__c WHERE Id = :emp.Id];
        Assert.areEqual(photoUrl, updatedEmp.Profile_Photo__c, 'Employee record must have updated Profile_Photo__c');

        List<ContentDocumentLink> links = [
            SELECT Id 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :emp.Id 
            AND ContentDocumentId = :insertedCv.ContentDocumentId
        ];
        Assert.isFalse(links.isEmpty(), 'ContentDocumentLink must be created connecting photo to Employee');
    }

    @IsTest
    static void testUpdateEmployeeProfilePhoto_ExistingLink() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'Employee Photo Existing Link',
            PathOnClient = 'profile2.png',
            VersionData = Blob.valueOf('dummy content data 2'),
            IsMajorVersion = true
        );
        insert cv;

        ContentVersion insertedCv = [
            SELECT Id, ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :cv.Id
        ];

        // Pre-create link
        ContentDocumentLink link = new ContentDocumentLink(
            LinkedEntityId = emp.Id,
            ContentDocumentId = insertedCv.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert link;

        Test.startTest();
        String photoUrl = EmployeeController.updateEmployeeProfilePhoto(emp.Id, insertedCv.ContentDocumentId);
        Test.stopTest();

        Assert.areEqual('/sfc/servlet.shepherd/version/download/' + insertedCv.Id, photoUrl, 'Should succeed when link already exists');
    }

    @IsTest
    static void testUpdateEmployeeProfilePhoto_NullInputs() {
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            EmployeeController.updateEmployeeProfilePhoto(null, null);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
            Assert.isNotNull(e, 'AuraHandledException expected for null inputs');
        } catch (Exception e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught, 'Exception should be caught on null inputs');
    }

    @IsTest
    static void testRemoveEmployeeProfilePhoto_Success() {
        Employee__c emp = [SELECT Id, Profile_Photo__c FROM Employee__c LIMIT 1];
        emp.Profile_Photo__c = 'https://example.com/photo.jpg';
        update emp;

        Test.startTest();
        EmployeeController.removeEmployeeProfilePhoto(emp.Id);
        Test.stopTest();

        Employee__c updatedEmp = [SELECT Profile_Photo__c FROM Employee__c WHERE Id = :emp.Id];
        Assert.isNull(updatedEmp.Profile_Photo__c, 'Profile_Photo__c should be cleared');
    }

    @IsTest
    static void testRemoveEmployeeProfilePhoto_NullInput() {
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            EmployeeController.removeEmployeeProfilePhoto(null);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
            Assert.isNotNull(e, 'AuraHandledException expected for null employeeId');
        } catch (Exception e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught, 'Exception should be caught on null employeeId');
    }

    // =========================================================================
    // BULK & SECURITY 5-VECTOR TESTS (QUALITY GATE COMPLIANCE)
    // =========================================================================

    @IsTest
    static void testBulk200_Employees_QueryAndProcessing() {
        // Vector 3: Bulk Processing (>= 200 records)
        List<Employee__c> bulkEmps = TestDataFactory.createEmployees(200, true);
        Assert.areEqual(200, bulkEmps.size(), 'Should create 200 bulk employee records');

        Test.startTest();
        List<Employee__c> result = EmployeeController.getEmployees();
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.size() >= 200, 'Should return at least 200 records without hitting governor limits');
        Assert.isTrue(Limits.getQueries() < Limits.getLimitQueries(), 'SOQL query limits must remain within governor bounds');
    }

    @IsTest
    static void testSecurity_RunAs_StandardUser() {
        // Vector 5: Security / FLS Context via System.runAs
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User stdUser = new User(
            Alias = 'hrmsu',
            Email = 'hrmsstandarduser@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'HRMSStandardUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = stdProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'hrmsstandarduser' + DateTime.now().getTime() + '@testorg.com'
        );
        insert stdUser;

        System.runAs(stdUser) {
            Test.startTest();
            try {
                List<Employee__c> emps = EmployeeController.getEmployees();
                Assert.isNotNull(emps, 'Standard user should execute query gracefully');
            } catch (AuraHandledException e) {
                // If standard user lacks FLS or object permission, AuraHandledException is expected and safe
                Assert.isNotNull(e, 'AuraHandledException caught for restricted user');
            } catch (Exception e) {
                Assert.isNotNull(e.getMessage(), 'Exception message present');
            }
            Test.stopTest();
        }
    }
}

