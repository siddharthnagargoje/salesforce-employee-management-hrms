/**
 * @description Invocable Apex service to render Payslip PDF and email it to the employee.
 *              Bulk-safe, handles duplicate prevention, resolves employee emails,
 *              and provides structured results and error tracking for Salesforce Flow.
 */
public inherited sharing class SendPayslipEmailInvocable {

    public class PayslipEmailRequest {
        @InvocableVariable(label='Payslip Record ID' description='ID of the Payslip__c record' required=true)
        public Id payslipId;

        @InvocableVariable(label='Force Resend' description='If true, ignores previous Email_Sent__c flag' required=false)
        public Boolean forceResend;
    }

    public class PayslipEmailResult {
        @InvocableVariable(label='Is Success' description='True if email sent or already sent')
        public Boolean isSuccess;

        @InvocableVariable(label='Message' description='Status or error details')
        public String message;

        @InvocableVariable(label='Recipient Email' description='Email address used')
        public String recipientEmail;

        @InvocableVariable(label='Payslip ID' description='Target Payslip Record ID')
        public Id payslipId;
    }

    @InvocableMethod(
        label='Send Payslip PDF Email'
        description='Generates the Payslip PDF attachment and emails it to the employee.'
        category='Payroll'
    )
    public static List<PayslipEmailResult> sendPayslipEmails(List<PayslipEmailRequest> requests) {
        List<PayslipEmailResult> results = new List<PayslipEmailResult>();

        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Set<Id> payslipIds = new Set<Id>();
        Map<Id, Boolean> forceResendMap = new Map<Id, Boolean>();

        for (PayslipEmailRequest req : requests) {
            if (req != null && req.payslipId != null) {
                payslipIds.add(req.payslipId);
                forceResendMap.put(req.payslipId, req.forceResend == true);
            }
        }

        if (payslipIds.isEmpty()) {
            return results;
        }

        // Query Payslip and related Employee details
        Map<Id, Payslip__c> payslipMap = new Map<Id, Payslip__c>([
            SELECT
                Id,
                Name,
                Employee__c,
                Employee__r.Name,
                Employee__r.Employee_Code__c,
                Employee__r.Personal_Email__c,
                Employee__r.Official_Email__c,
                Pay_Month__c,
                Pay_Year__c,
                Basic_Salary__c,
                Bonus__c,
                Deductions__c,
                Gross_Salary__c,
                Status__c,
                Email_Sent__c,
                Email_Sent_Date__c,
                Email_Error_Message__c
            FROM Payslip__c
            WHERE Id IN :payslipIds
        ]);

        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
        Map<Id, PayslipEmailResult> resultMap = new Map<Id, PayslipEmailResult>();
        Map<Integer, Id> emailIndexToPayslipId = new Map<Integer, Id>();
        Map<Id, Payslip__c> slipsToUpdateMap = new Map<Id, Payslip__c>();

        for (PayslipEmailRequest req : requests) {
            Id slipId = req.payslipId;
            PayslipEmailResult res = new PayslipEmailResult();
            res.payslipId = slipId;

            if (!payslipMap.containsKey(slipId)) {
                res.isSuccess = false;
                res.message = 'Payslip record not found: ' + slipId;
                results.add(res);
                continue;
            }

            Payslip__c slip = payslipMap.get(slipId);
            Boolean forceResend = forceResendMap.get(slipId);

            // Duplicate Prevention Check
            if (slip.Email_Sent__c == true && !forceResend) {
                res.isSuccess = true;
                res.recipientEmail = resolveEmail(slip);
                res.message = 'Email already sent on ' + (slip.Email_Sent_Date__c != null ? slip.Email_Sent_Date__c.format() : 'previous run') + '. Skipped to prevent duplicate.';
                resultMap.put(slipId, res);
                continue;
            }

            // Employee & Email Resolution
            String recipientEmail = resolveEmail(slip);
            if (String.isBlank(recipientEmail)) {
                res.isSuccess = false;
                res.message = 'Missing email address for employee ' + (slip.Employee__r != null ? slip.Employee__r.Name : 'Unknown') + '.';
                resultMap.put(slipId, res);

                slipsToUpdateMap.put(slipId, new Payslip__c(
                    Id = slipId,
                    Email_Error_Message__c = res.message.left(255)
                ));
                continue;
            }

            res.recipientEmail = recipientEmail;

            try {
                // Generate PDF blob
                Blob pdfBlob;
                if (Test.isRunningTest()) {
                    pdfBlob = Blob.valueOf('HRMS_360_MOCK_PAYSLIP_PDF_CONTENT');
                } else {
                    PageReference pdfPage = Page.PayslipPDFPage;
                    pdfPage.getParameters().put('id', slip.Id);
                    pdfBlob = pdfPage.getContentAsPDF();
                }

                // Construct Email Attachment
                Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                String empCode = (slip.Employee__r != null && String.isNotBlank(slip.Employee__r.Employee_Code__c))
                    ? slip.Employee__r.Employee_Code__c
                    : 'EMP';
                String monthStr = String.isNotBlank(slip.Pay_Month__c) ? slip.Pay_Month__c : 'Month';
                String yearStr = slip.Pay_Year__c != null ? String.valueOf(slip.Pay_Year__c) : '';
                String fileName = ('Payslip_' + empCode + '_' + monthStr + '_' + yearStr + '.pdf').replaceAll('\\s+', '_');

                attachment.setFileName(fileName);
                attachment.setBody(pdfBlob);
                attachment.setContentType('application/pdf');

                // Construct Single Email Message
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{ recipientEmail });
                
                String empName = slip.Employee__r != null ? slip.Employee__r.Name : 'Valued Employee';
                String subject = 'Salary Statement for ' + monthStr + ' ' + yearStr + ' - ' + empName;
                mail.setSubject(subject);
                mail.setHtmlBody(buildHtmlBody(slip, empName, monthStr, yearStr));
                mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });

                emailIndexToPayslipId.put(emailList.size(), slip.Id);
                emailList.add(mail);
                resultMap.put(slipId, res);

            } catch (Exception ex) {
                res.isSuccess = false;
                res.message = 'Error generating payslip email: ' + ex.getMessage();
                resultMap.put(slipId, res);

                slipsToUpdateMap.put(slipId, new Payslip__c(
                    Id = slipId,
                    Email_Error_Message__c = res.message.left(255)
                ));
            }
        }

        // Send Email batch
        if (!emailList.isEmpty()) {
            Messaging.SendEmailResult[] sendResults = Messaging.sendEmail(emailList, false);

            for (Integer i = 0; i < sendResults.size(); i++) {
                Messaging.SendEmailResult sr = sendResults[i];
                Id slipId = emailIndexToPayslipId.get(i);
                PayslipEmailResult res = resultMap.get(slipId);

                if (sr.isSuccess()) {
                    res.isSuccess = true;
                    res.message = 'Payslip PDF successfully sent to ' + res.recipientEmail;
                    slipsToUpdateMap.put(slipId, new Payslip__c(
                        Id = slipId,
                        Email_Sent__c = true,
                        Email_Sent_Date__c = System.now(),
                        Email_Error_Message__c = null
                    ));
                } else {
                    res.isSuccess = false;
                    String errorCombined = '';
                    for (Messaging.SendEmailError err : sr.getErrors()) {
                        errorCombined += err.getMessage() + '; ';
                    }
                    res.message = 'Failed to send email: ' + errorCombined;
                    slipsToUpdateMap.put(slipId, new Payslip__c(
                        Id = slipId,
                        Email_Error_Message__c = res.message.left(255)
                    ));
                }
            }
        }

        // Update Payslip status tracking in bulk
        if (!slipsToUpdateMap.isEmpty()) {
            Database.update(slipsToUpdateMap.values(), false);
        }

        // Ensure order matches requests
        for (PayslipEmailRequest req : requests) {
            if (resultMap.containsKey(req.payslipId)) {
                results.add(resultMap.get(req.payslipId));
            }
        }

        return results;
    }

    /**
     * @description Resolves recipient email from official email first, fallback to personal email.
     */
    private static String resolveEmail(Payslip__c slip) {
        if (slip.Employee__r == null) {
            return null;
        }
        if (String.isNotBlank(slip.Employee__r.Official_Email__c)) {
            return slip.Employee__r.Official_Email__c.trim();
        }
        if (String.isNotBlank(slip.Employee__r.Personal_Email__c)) {
            return slip.Employee__r.Personal_Email__c.trim();
        }
        return null;
    }

    /**
     * @description Builds a responsive, professional HTML email template for the payslip dispatch.
     */
    private static String buildHtmlBody(Payslip__c slip, String empName, String month, String year) {
        Decimal basic = slip.Basic_Salary__c != null ? slip.Basic_Salary__c : 0;
        Decimal bonus = slip.Bonus__c != null ? slip.Bonus__c : 0;
        Decimal deductions = slip.Deductions__c != null ? slip.Deductions__c : 0;
        Decimal netPay = (basic + bonus) - deductions;

        String formattedNet = '₹' + netPay.setScale(2).format();
        String formattedGross = '₹' + (basic + bonus).setScale(2).format();
        String formattedDeductions = '₹' + deductions.setScale(2).format();
        String status = String.isNotBlank(slip.Status__c) ? slip.Status__c : 'Approved';

        String html = '<!DOCTYPE html>'
            + '<html>'
            + '<head>'
            + '<meta charset="UTF-8"/>'
            + '<style>'
            + 'body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; background-color: #f1f5f9; margin: 0; padding: 24px; color: #1e293b; }'
            + '.card { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 8px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); }'
            + '.header { background: #0f1f38; color: #ffffff; padding: 24px; text-align: center; border-bottom: 4px solid #d4af37; }'
            + '.badge { display: inline-block; background: #d4af37; color: #0f1f38; font-weight: 800; font-size: 11px; padding: 3px 8px; border-radius: 3px; letter-spacing: 0.5px; margin-bottom: 6px; }'
            + '.company-name { font-size: 20px; font-weight: 700; margin: 0; }'
            + '.sub-title { font-size: 13px; color: #cbd5e1; margin-top: 4px; }'
            + '.content { padding: 24px 28px; font-size: 14px; line-height: 1.6; }'
            + '.greeting { font-size: 16px; font-weight: 600; color: #0f1f38; margin-bottom: 12px; }'
            + '.summary-table { width: 100%; border-collapse: collapse; margin: 18px 0; background: #f8fafc; border-radius: 6px; overflow: hidden; border: 1px solid #e2e8f0; }'
            + '.summary-table td { padding: 10px 14px; border-bottom: 1px solid #e2e8f0; font-size: 13px; }'
            + '.summary-label { color: #64748b; font-weight: 500; width: 45%; }'
            + '.summary-value { color: #0f1f38; font-weight: 600; text-align: right; }'
            + '.net-highlight { background: #0f1f38; color: #ffffff !important; }'
            + '.net-highlight td { color: #ffffff; font-weight: 700; border-bottom: none; }'
            + '.net-amount { color: #d4af37 !important; font-size: 16px; }'
            + '.note-box { background: #eff6ff; border-left: 4px solid #3b82f6; padding: 12px 16px; margin: 18px 0; font-size: 13px; color: #1e40af; border-radius: 0 4px 4px 0; }'
            + '.footer { background: #f8fafc; border-top: 1px solid #e2e8f0; padding: 18px 24px; text-align: center; font-size: 12px; color: #64748b; }'
            + '</style>'
            + '</head>'
            + '<body>'
            + '<div class="card">'
            + '  <div class="header">'
            + '    <div class="badge">HRMS 360 PAYROLL</div>'
            + '    <div class="company-name">Siddharth Pvt. Ltd.</div>'
            + '    <div class="sub-title">Monthly Compensation &amp; Salary Statement</div>'
            + '  </div>'
            + '  <div class="content">'
            + '    <div class="greeting">Dear ' + empName + ',</div>'
            + '    <p>Your salary statement for <strong>' + month + ' ' + year + '</strong> has been approved and processed. A detailed copy of your official payslip is attached to this email as a confidential PDF.</p>'
            + '    <table class="summary-table">'
            + '      <tr><td class="summary-label">Payslip Reference</td><td class="summary-value">' + (String.isNotBlank(slip.Name) ? slip.Name : 'N/A') + '</td></tr>'
            + '      <tr><td class="summary-label">Pay Period</td><td class="summary-value">' + month + ' ' + year + '</td></tr>'
            + '      <tr><td class="summary-label">Gross Earnings</td><td class="summary-value">' + formattedGross + '</td></tr>'
            + '      <tr><td class="summary-label">Total Deductions</td><td class="summary-value">' + formattedDeductions + '</td></tr>'
            + '      <tr><td class="summary-label">Disbursement Status</td><td class="summary-value">' + status + '</td></tr>'
            + '      <tr class="net-highlight"><td class="summary-label" style="color:#ffffff;">Net Take-Home Pay</td><td class="summary-value net-amount">' + formattedNet + '</td></tr>'
            + '    </table>'
            + '    <div class="note-box">'
            + '      &#128206; <strong>Attachment:</strong> Please open the attached PDF for itemized breakdowns, earnings components, deductions, and tax withholding details.'
            + '    </div>'
            + '    <p style="margin-bottom: 0;">If you have any questions regarding your salary components, please reach out to the Payroll Helpdesk.</p>'
            + '  </div>'
            + '  <div class="footer">'
            + '    <strong>HR &amp; Payroll Operations Team</strong><br/>'
            + '    HRMS 360 &bull; Siddharth Pvt. Ltd. &bull; Strictly Confidential'
            + '  </div>'
            + '</div>'
            + '</body>'
            + '</html>';

        return html;
    }
}
