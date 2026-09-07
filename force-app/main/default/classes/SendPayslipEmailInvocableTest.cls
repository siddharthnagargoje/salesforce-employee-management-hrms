/**
 * @description Comprehensive unit tests for SendPayslipEmailInvocable and Send_Payslip_PDF_Email Flow.
 *              Validates bulkification, duplicate email prevention, error handling,
 *              missing email scenarios, and force resend capability.
 */
@IsTest
private class SendPayslipEmailInvocableTest {

    @TestSetup
    static void setupTestData() {
        // Employee with Personal Email
        Employee__c emp1 = TestDataFactory.createEmployee('Bruce', 'Wayne', 'CEO', 'Active', Date.today().addYears(-2), true);
        emp1.Personal_Email__c = 'bruce.wayne@hrmsexample.com';
        update emp1;

        // Employee with Official Email
        Employee__c emp2 = TestDataFactory.createEmployee('Clark', 'Kent', 'Investigative Reporter', 'Active', Date.today().addYears(-1), true);
        emp2.Official_Email__c = 'clark.kent@dailyplanet.com';
        emp2.Personal_Email__c = 'clark.personal@hrmsexample.com';
        update emp2;

        // Employee with NO Email
        Employee__c emp3 = TestDataFactory.createEmployee('Arthur', 'Curry', 'Marine Specialist', 'Active', Date.today().addYears(-1), true);
        emp3.Personal_Email__c = null;
        emp3.Official_Email__c = null;
        update emp3;

        // Create Payslips in Draft status so the Record-Triggered Flow does not prematurely fire in TestSetup
        TestDataFactory.createPayslip(emp1.Id, 'September', Date.today().year(), 120000, 20000, 15000, 'Draft', true);
        TestDataFactory.createPayslip(emp2.Id, 'September', Date.today().year(), 95000, 10000, 8000, 'Draft', true);
        TestDataFactory.createPayslip(emp3.Id, 'September', Date.today().year(), 70000, 5000, 4000, 'Draft', true);
    }

    @IsTest
    static void testSendPayslipEmailSuccess() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Personal_Email__c = 'bruce.wayne@hrmsexample.com' LIMIT 1];
        Payslip__c slip = [
            SELECT Id, Employee__c, Email_Sent__c
            FROM Payslip__c
            WHERE Employee__c = :emp.Id
            LIMIT 1
        ];

        SendPayslipEmailInvocable.PayslipEmailRequest req = new SendPayslipEmailInvocable.PayslipEmailRequest();
        req.payslipId = slip.Id;
        req.forceResend = false;

        Test.startTest();
        List<SendPayslipEmailInvocable.PayslipEmailResult> results =
            SendPayslipEmailInvocable.sendPayslipEmails(new List<SendPayslipEmailInvocable.PayslipEmailRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return 1 result');
        Assert.isTrue(results[0].isSuccess, 'Email sending should succeed');
        Assert.areEqual('bruce.wayne@hrmsexample.com', results[0].recipientEmail, 'Recipient email should match personal email');

        Payslip__c updatedSlip = [
            SELECT Id, Email_Sent__c, Email_Sent_Date__c, Email_Error_Message__c
            FROM Payslip__c
            WHERE Id = :slip.Id
        ];
        Assert.isTrue(updatedSlip.Email_Sent__c, 'Email_Sent__c should be true');
        Assert.isNotNull(updatedSlip.Email_Sent_Date__c, 'Email_Sent_Date__c should be populated');
        Assert.isNull(updatedSlip.Email_Error_Message__c, 'No error message should be logged');
    }

    @IsTest
    static void testOfficialEmailPrioritized() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Official_Email__c = 'clark.kent@dailyplanet.com' LIMIT 1];
        Payslip__c slip = [
            SELECT Id, Employee__c
            FROM Payslip__c
            WHERE Employee__c = :emp.Id
            LIMIT 1
        ];

        SendPayslipEmailInvocable.PayslipEmailRequest req = new SendPayslipEmailInvocable.PayslipEmailRequest();
        req.payslipId = slip.Id;

        Test.startTest();
        List<SendPayslipEmailInvocable.PayslipEmailResult> results =
            SendPayslipEmailInvocable.sendPayslipEmails(new List<SendPayslipEmailInvocable.PayslipEmailRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return 1 result');
        Assert.isTrue(results[0].isSuccess, 'Email sending should succeed');
        Assert.areEqual('clark.kent@dailyplanet.com', results[0].recipientEmail, 'Official email must take precedence over personal email');
    }

    @IsTest
    static void testDuplicatePrevention() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Personal_Email__c = 'bruce.wayne@hrmsexample.com' LIMIT 1];
        Payslip__c slip = [
            SELECT Id, Employee__c, Email_Sent__c
            FROM Payslip__c
            WHERE Employee__c = :emp.Id
            LIMIT 1
        ];

        // Mark as already sent
        update new Payslip__c(
            Id = slip.Id,
            Email_Sent__c = true,
            Email_Sent_Date__c = System.now().addDays(-1)
        );

        SendPayslipEmailInvocable.PayslipEmailRequest req = new SendPayslipEmailInvocable.PayslipEmailRequest();
        req.payslipId = slip.Id;
        req.forceResend = false;

        Test.startTest();
        List<SendPayslipEmailInvocable.PayslipEmailResult> results =
            SendPayslipEmailInvocable.sendPayslipEmails(new List<SendPayslipEmailInvocable.PayslipEmailRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return 1 result');
        Assert.isTrue(results[0].isSuccess, 'Result should be true');
        Assert.isTrue(results[0].message.contains('Skipped to prevent duplicate'), 'Should indicate skipped duplicate dispatch');
    }

    @IsTest
    static void testForceResend() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Personal_Email__c = 'bruce.wayne@hrmsexample.com' LIMIT 1];
        Payslip__c slip = [
            SELECT Id, Employee__c
            FROM Payslip__c
            WHERE Employee__c = :emp.Id
            LIMIT 1
        ];

        update new Payslip__c(
            Id = slip.Id,
            Email_Sent__c = true,
            Email_Sent_Date__c = System.now().addDays(-2)
        );

        SendPayslipEmailInvocable.PayslipEmailRequest req = new SendPayslipEmailInvocable.PayslipEmailRequest();
        req.payslipId = slip.Id;
        req.forceResend = true;

        Test.startTest();
        List<SendPayslipEmailInvocable.PayslipEmailResult> results =
            SendPayslipEmailInvocable.sendPayslipEmails(new List<SendPayslipEmailInvocable.PayslipEmailRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return 1 result');
        Assert.isTrue(results[0].isSuccess, 'Force resend should succeed');
    }

    @IsTest
    static void testMissingEmailErrorHandling() {
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Personal_Email__c = null AND Official_Email__c = null LIMIT 1];
        Payslip__c slip = [
            SELECT Id, Employee__c
            FROM Payslip__c
            WHERE Employee__c = :emp.Id
            LIMIT 1
        ];

        SendPayslipEmailInvocable.PayslipEmailRequest req = new SendPayslipEmailInvocable.PayslipEmailRequest();
        req.payslipId = slip.Id;

        Test.startTest();
        List<SendPayslipEmailInvocable.PayslipEmailResult> results =
            SendPayslipEmailInvocable.sendPayslipEmails(new List<SendPayslipEmailInvocable.PayslipEmailRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return 1 result');
        Assert.isFalse(results[0].isSuccess, 'Should fail gracefully when email is absent');
        Assert.isTrue(results[0].message.contains('Missing email address'), 'Error message should mention missing email');

        Payslip__c updatedSlip = [
            SELECT Id, Email_Sent__c, Email_Error_Message__c
            FROM Payslip__c
            WHERE Id = :slip.Id
        ];
        Assert.isFalse(updatedSlip.Email_Sent__c, 'Email_Sent__c should remain false');
        Assert.isNotNull(updatedSlip.Email_Error_Message__c, 'Email_Error_Message__c should be recorded');
    }

    @IsTest
    static void testRecordTriggeredFlowIntegration() {
        // Test end-to-end integration: Updating status to 'Approved' triggers the Record-Triggered Flow
        Employee__c emp = [SELECT Id FROM Employee__c WHERE Personal_Email__c = 'bruce.wayne@hrmsexample.com' LIMIT 1];
        Payslip__c slip = [
            SELECT Id, Status__c, Email_Sent__c
            FROM Payslip__c
            WHERE Employee__c = :emp.Id
            LIMIT 1
        ];
        Assert.isFalse(slip.Email_Sent__c, 'Initially email should not be sent');

        Test.startTest();
        update new Payslip__c(
            Id = slip.Id,
            Status__c = 'Approved'
        );
        Test.stopTest();

        Payslip__c updatedSlip = [
            SELECT Id, Status__c, Email_Sent__c, Email_Sent_Date__c
            FROM Payslip__c
            WHERE Id = :slip.Id
        ];
        Assert.areEqual('Approved', updatedSlip.Status__c, 'Status should be Approved');
        Assert.isTrue(updatedSlip.Email_Sent__c, 'Flow should trigger and set Email_Sent__c to true');
        Assert.isNotNull(updatedSlip.Email_Sent_Date__c, 'Email_Sent_Date__c should be populated by Flow action');
    }

    @IsTest
    static void testEmptyAndInvalidRequests() {
        Test.startTest();
        List<SendPayslipEmailInvocable.PayslipEmailResult> emptyResults =
            SendPayslipEmailInvocable.sendPayslipEmails(new List<SendPayslipEmailInvocable.PayslipEmailRequest>());
        List<SendPayslipEmailInvocable.PayslipEmailResult> nullResults =
            SendPayslipEmailInvocable.sendPayslipEmails(null);

        SendPayslipEmailInvocable.PayslipEmailRequest fakeReq = new SendPayslipEmailInvocable.PayslipEmailRequest();
        fakeReq.payslipId = 'a04000000000000AAA';
        List<SendPayslipEmailInvocable.PayslipEmailResult> fakeResults =
            SendPayslipEmailInvocable.sendPayslipEmails(new List<SendPayslipEmailInvocable.PayslipEmailRequest>{ fakeReq });
        Test.stopTest();

        Assert.isTrue(emptyResults.isEmpty(), 'Empty requests should return empty');
        Assert.isTrue(nullResults.isEmpty(), 'Null requests should return empty');
        Assert.areEqual(1, fakeResults.size(), 'Should return result for missing record');
        Assert.isFalse(fakeResults[0].isSuccess, 'Missing record should report failure');
    }

    @IsTest
    static void testBulkSend() {
        List<Employee__c> emps = TestDataFactory.createEmployees(10, true);
        List<Payslip__c> slips = new List<Payslip__c>();

        for (Integer i = 0; i < emps.size(); i++) {
            slips.add(new Payslip__c(
                Employee__c = emps[i].Id,
                Pay_Month__c = 'August',
                Pay_Year__c = Date.today().year(),
                Basic_Salary__c = 50000 + (i * 1000),
                Bonus__c = 5000,
                Deductions__c = 2000,
                Status__c = 'Draft'
            ));
        }
        insert slips;

        List<SendPayslipEmailInvocable.PayslipEmailRequest> requests = new List<SendPayslipEmailInvocable.PayslipEmailRequest>();
        for (Payslip__c s : slips) {
            SendPayslipEmailInvocable.PayslipEmailRequest r = new SendPayslipEmailInvocable.PayslipEmailRequest();
            r.payslipId = s.Id;
            requests.add(r);
        }

        Test.startTest();
        List<SendPayslipEmailInvocable.PayslipEmailResult> results =
            SendPayslipEmailInvocable.sendPayslipEmails(requests);
        Test.stopTest();

        Assert.areEqual(10, results.size(), 'Should process all 10 records in bulk');
        for (SendPayslipEmailInvocable.PayslipEmailResult res : results) {
            Boolean outcomeOk = res.isSuccess || (res.message != null && (res.message.contains('Email limit exceeded') || res.message.contains('SINGLE_EMAIL_LIMIT_EXCEEDED')));
            Assert.isTrue(outcomeOk, 'Bulk result should either succeed or reflect dev org email limit: ' + res.message);
        }
    }
}
