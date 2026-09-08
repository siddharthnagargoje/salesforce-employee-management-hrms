/**
 * @description Dedicated controller for HRMS Payroll & Compensation operations.
 *              Handles payslip lifecycle, salary calculations, and email statement dispatch.
 */
public with sharing class PayrollController {

    private static AuraHandledException createAuraHandledException(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }

    /**
     * @description Fetches all payslip records with employee relations.
     */
    @AuraEnabled(cacheable=true)
    public static List<Payslip__c> getPayslips() {
        try {
            return [
                SELECT Id,
                       Name,
                       Employee__c,
                       Employee__r.Name,
                       Employee__r.Personal_Email__c,
                       Employee__r.Official_Email__c,
                       Pay_Month__c,
                       Pay_Year__c,
                       Basic_Salary__c,
                       Bonus__c,
                       Deductions__c,
                       Gross_Salary__c,
                       Status__c,
                       PDF_Generated__c,
                       Email_Sent__c,
                       Email_Sent_Date__c,
                       Email_Error_Message__c,
                       CreatedDate,
                       Downloaded_File__c
                FROM Payslip__c
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 2000
            ];
        } catch (Exception e) {
            throw createAuraHandledException('Error fetching payslips: ' + e.getMessage());
        }
    }

    /**
     * @description Generates a new payslip record.
     */
    @AuraEnabled
    public static Payslip__c createPayslip(
        Id employeeId,
        String payMonth,
        Integer payYear,
        Decimal basicSalary,
        Decimal bonus,
        Decimal deductions,
        String status
    ) {
        try {
            if (employeeId == null) {
                throw new IllegalArgumentException('Employee ID is required to generate a payslip.');
            }
            if (String.isBlank(payMonth) || payYear == null) {
                throw new IllegalArgumentException('Pay Month and Pay Year are required.');
            }

            Payslip__c payslip = new Payslip__c(
                Employee__c = employeeId,
                Pay_Month__c = payMonth,
                Pay_Year__c = payYear,
                Basic_Salary__c = basicSalary != null ? basicSalary : 0,
                Bonus__c = bonus != null ? bonus : 0,
                Deductions__c = deductions != null ? deductions : 0,
                Status__c = String.isNotBlank(status) ? status : 'Generated'
            );

            insert as user payslip;
            return payslip;
        } catch (Exception e) {
            throw createAuraHandledException('Error creating payslip: ' + e.getMessage());
        }
    }

    /**
     * @description Deletes a payslip record by ID.
     */
    @AuraEnabled
    public static void deletePayslip(Id payslipId) {
        try {
            if (payslipId == null) {
                throw new IllegalArgumentException('Payslip ID is required for delete.');
            }
            Payslip__c record = [
                SELECT Id 
                FROM Payslip__c 
                WHERE Id = :payslipId 
                WITH USER_MODE 
                LIMIT 1
            ];
            delete as user record;
        } catch (Exception e) {
            throw createAuraHandledException('Error deleting payslip: ' + e.getMessage());
        }
    }

    /**
     * @description Dispatches payslip PDF email for a specific record.
     */
    @AuraEnabled
    public static Map<String, Object> sendPayslipEmail(Id payslipId, Boolean forceResend) {
        try {
            if (payslipId == null) {
                throw new IllegalArgumentException('Payslip ID is required to dispatch email.');
            }

            SendPayslipEmailInvocable.PayslipEmailRequest req = new SendPayslipEmailInvocable.PayslipEmailRequest();
            req.payslipId = payslipId;
            req.forceResend = forceResend == true;

            List<SendPayslipEmailInvocable.PayslipEmailResult> results = 
                SendPayslipEmailInvocable.sendPayslipEmails(new List<SendPayslipEmailInvocable.PayslipEmailRequest>{ req });

            if (results.isEmpty()) {
                throw new AuraHandledException('No result returned from email dispatch service.');
            }

            SendPayslipEmailInvocable.PayslipEmailResult res = results[0];
            return new Map<String, Object>{
                'isSuccess' => res.isSuccess,
                'message' => res.message,
                'recipientEmail' => res.recipientEmail,
                'payslipId' => res.payslipId
            };
        } catch (Exception e) {
            throw createAuraHandledException('Error dispatching payslip email: ' + e.getMessage());
        }
    }
}
