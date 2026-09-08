/**
 * @description Dedicated trigger handler for Payslip__c operations.
 *              Guards against duplicate payroll records and enforces non-negative compensation.
 */
public with sharing class PayslipTriggerHandler {

    public void beforeInsert(List<Payslip__c> newRecords) {
        validateSalaryComponents(newRecords);
        preventDuplicatePayslips(newRecords, null);
    }

    public void beforeUpdate(Map<Id, Payslip__c> oldMap, Map<Id, Payslip__c> newMap) {
        validateSalaryComponents(newMap.values());
        preventDuplicatePayslips(newMap.values(), oldMap.keySet());
    }

    public void afterInsert(List<Payslip__c> newRecords) {
        // Reserved for auto-generation of PDF statements or webhooks
    }

    public void afterUpdate(Map<Id, Payslip__c> oldMap, Map<Id, Payslip__c> newMap) {
        // Reserved
    }

    public void beforeDelete(Map<Id, Payslip__c> oldMap) {
        for (Payslip__c slip : oldMap.values()) {
            if (slip.Status__c == 'Paid') {
                slip.addError('Paid payslips cannot be deleted.');
            }
        }
    }

    public void afterDelete(Map<Id, Payslip__c> oldMap) {
        // Reserved
    }

    public void afterUndelete(List<Payslip__c> restoredRecords) {
        // Reserved
    }

    private void validateSalaryComponents(List<Payslip__c> records) {
        for (Payslip__c slip : records) {
            if (slip.Basic_Salary__c != null && slip.Basic_Salary__c < 0) {
                slip.Basic_Salary__c.addError('Basic Salary cannot be negative.');
            }
            if (slip.Bonus__c != null && slip.Bonus__c < 0) {
                slip.Bonus__c.addError('Bonus cannot be negative.');
            }
            if (slip.Deductions__c != null && slip.Deductions__c < 0) {
                slip.Deductions__c.addError('Deductions cannot be negative.');
            }
        }
    }

    private void preventDuplicatePayslips(List<Payslip__c> records, Set<Id> existingIds) {
        Set<Id> empIds = new Set<Id>();
        Set<Integer> years = new Set<Integer>();

        for (Payslip__c slip : records) {
            if (slip.Employee__c != null && slip.Pay_Year__c != null) {
                empIds.add(slip.Employee__c);
                years.add(Integer.valueOf(slip.Pay_Year__c));
            }
        }

        if (empIds.isEmpty()) {
            return;
        }

        List<Payslip__c> existingSlips = [
            SELECT Id, Employee__c, Pay_Month__c, Pay_Year__c
            FROM Payslip__c
            WHERE Employee__c IN :empIds
            AND Pay_Year__c IN :years
        ];

        Set<String> existingKeys = new Set<String>();
        for (Payslip__c slip : existingSlips) {
            if (existingIds != null && existingIds.contains(slip.Id)) {
                continue;
            }
            String key = slip.Employee__c + '_' + String.valueOf(slip.Pay_Month__c).toLowerCase() + '_' + String.valueOf(slip.Pay_Year__c);
            existingKeys.add(key);
        }

        Set<String> batchKeys = new Set<String>();
        for (Payslip__c incoming : records) {
            if (incoming.Employee__c == null || String.isBlank(incoming.Pay_Month__c) || incoming.Pay_Year__c == null) {
                continue;
            }

            String key = incoming.Employee__c + '_' + incoming.Pay_Month__c.toLowerCase().trim() + '_' + String.valueOf(incoming.Pay_Year__c);
            if (existingKeys.contains(key) || batchKeys.contains(key)) {
                incoming.addError('A payslip already exists for this employee for ' + incoming.Pay_Month__c + ' ' + incoming.Pay_Year__c + '.');
            } else {
                batchKeys.add(key);
            }
        }
    }
}
