# Apex Testing Patterns Reference Guide

This reference provides enterprise-grade code templates for testing common Salesforce architectural components.

---

## 1. Lightning Web Component (@AuraEnabled) Controller Testing

### Scenario: Positive Fetch & Imperative Action with Exception
```apex
@IsTest
private class EmployeeControllerTest {

    @TestSetup
    static void setupData() {
        Employee__c emp = TestDataFactory.createEmployee('Siddharth', 'Nagargoje', 'DEV-01');
        insert emp;
    }

    @IsTest
    static void testGetEmployees_ValidFilter_ReturnsMatchingList() {
        Test.startTest();
        List<Employee__c> results = EmployeeController.getEmployees('Siddharth', null, null);
        Test.stopTest();

        Assert.isNotNull(results, 'Result list should not be null');
        Assert.areEqual(1, results.size(), 'Should return exactly 1 employee matching filter');
        Assert.areEqual('Siddharth', results[0].First_Name__c, 'Returned employee name should match');
    }

    @IsTest
    static void testSaveEmployee_MissingRequiredField_ThrowsAuraHandledException() {
        Employee__c invalidEmp = new Employee__c(); // Missing required fields

        Test.startTest();
        try {
            EmployeeController.saveEmployee(invalidEmp);
            Assert.fail('Expected AuraHandledException was not thrown');
        } catch (AuraHandledException ex) {
            Assert.isTrue(String.isNotBlank(ex.getMessage()), 'Exception message should contain validation details');
        } catch (Exception ex) {
            Assert.fail('Unexpected exception type caught: ' + ex.getTypeName());
        }
        Test.stopTest();
    }
}
```

---

## 2. Invocable Action (@InvocableMethod) for Salesforce Flow

### Scenario: Bulk Invocable with Duplicate Skip
```apex
@IsTest
static void testInvocableAction_BulkRecords_ProcessesSuccessfully() {
    List<Payslip__c> slips = [SELECT Id FROM Payslip__c LIMIT 10];
    List<SendPayslipEmailInvocable.PayslipEmailRequest> requests = new List<SendPayslipEmailInvocable.PayslipEmailRequest>();
    
    for (Payslip__c slip : slips) {
        SendPayslipEmailInvocable.PayslipEmailRequest req = new SendPayslipEmailInvocable.PayslipEmailRequest();
        req.payslipId = slip.Id;
        req.forceResend = false;
        requests.add(req);
    }

    Test.startTest();
    List<SendPayslipEmailInvocable.PayslipEmailResult> results = SendPayslipEmailInvocable.sendPayslipEmails(requests);
    Test.stopTest();

    Assert.areEqual(slips.size(), results.size(), 'Result list count must match request list count');
    for (SendPayslipEmailInvocable.PayslipEmailResult res : results) {
        Assert.isTrue(res.isSuccess, 'Invocable action should succeed: ' + res.errorMessage);
    }
}
```

---

## 3. Asynchronous Batch Apex (`Database.Batchable`)

### Scenario: Batch Job Execution and Limit Reset
```apex
@IsTest
static void testBatchJob_BulkData_ExecutesAllChunks() {
    // 1. Arrange: Prepare bulk records (e.g., 200 records)
    List<Attendance__c> attList = new List<Attendance__c>();
    Id empId = [SELECT Id FROM Employee__c LIMIT 1].Id;
    for (Integer i = 0; i < 200; i++) {
        attList.add(new Attendance__c(
            Employee__c = empId,
            Attendance_Date__c = Date.today().addDays(-i),
            Status__c = 'Pending'
        ));
    }
    insert attList;

    // 2. Act: Execute batch inside startTest/stopTest block
    Test.startTest();
    AttendanceProcessingBatch batch = new AttendanceProcessingBatch();
    Id batchId = Database.executeBatch(batch, 200);
    Test.stopTest(); // Forces all batch chunks to execute synchronously

    // 3. Assert: Verify async state changes
    List<Attendance__c> processedList = [SELECT Id, Status__c FROM Attendance__c WHERE Status__c = 'Approved'];
    Assert.areEqual(200, processedList.size(), 'All 200 attendance records should be transitioned to Approved');
}
```

---

## 4. HTTP Callout Mocking (`HttpCalloutMock`)

### Scenario: Single or Multi-Route API Callout
```apex
public class MockHttpResponseGenerator implements HttpCalloutMock {
    private Integer statusCode;
    private String responseBody;

    public MockHttpResponseGenerator(Integer statusCode, String responseBody) {
        this.statusCode = statusCode;
        this.responseBody = responseBody;
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody(this.responseBody);
        res.setStatusCode(this.statusCode);
        return res;
    }
}

// In your test method:
@IsTest
static void testExternalApiCallout_SuccessResponse_ParsesPayload() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, '{"status":"OK","id":"12345"}'));

    Test.startTest();
    ApiResponse response = ExternalPayrollService.syncEmployeePayroll('EMP-001');
    Test.stopTest();

    Assert.areEqual('OK', response.status, 'API response status should parse as OK');
    Assert.areEqual('12345', response.id, 'External ID should match mock payload');
}
```

---

## 5. Security & Context Testing with `System.runAs()`

### Scenario: Testing Standard User without ModifyAll Permission
```apex
@IsTest
static void testEmployeeAccess_RestrictedUser_EnforcesSharingRules() {
    Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    User standardUser = TestDataFactory.createTestUser(standardProfile.Id);

    System.runAs(standardUser) {
        Test.startTest();
        List<Employee__c> accessibleEmployees = EmployeeController.getEmployees(null, null, null);
        Test.stopTest();

        // Standard user should only see employees belonging to their department/sharing rules
        Assert.isNotNull(accessibleEmployees, 'Query should execute safely under USER_MODE');
    }
}
```
