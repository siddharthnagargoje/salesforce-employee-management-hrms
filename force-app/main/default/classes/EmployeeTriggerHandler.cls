/**
 * @description Dedicated trigger handler for Employee__c operations.
 *              Enforces business validations, auto-generates employee codes,
 *              and provisions baseline annual leave balances.
 */
public with sharing class EmployeeTriggerHandler {

    public void beforeInsert(List<Employee__c> newRecords) {
        populateEmployeeCodes(newRecords);
    }

    public void afterInsert(List<Employee__c> newRecords) {
        provisionDefaultLeaveBalances(newRecords);
    }

    public void beforeUpdate(Map<Id, Employee__c> oldMap, Map<Id, Employee__c> newMap) {
        // Reserved for status transition audits
    }

    public void afterUpdate(Map<Id, Employee__c> oldMap, Map<Id, Employee__c> newMap) {
        // Reserved for post-update notifications
    }

    public void beforeDelete(Map<Id, Employee__c> oldMap) {
        // Prevent deletion of active employees if needed
    }

    public void afterDelete(Map<Id, Employee__c> oldMap) {
        // Cleanup related records
    }

    public void afterUndelete(List<Employee__c> restoredRecords) {
        // Reactivation handling
    }

    private void populateEmployeeCodes(List<Employee__c> records) {
        Integer currentYear = Date.today().year();
        for (Employee__c emp : records) {
            if (String.isBlank(emp.Employee_Code__c)) {
                Integer randomNum = Math.abs(Crypto.getRandomInteger());
                String codeSuffix = String.valueOf(randomNum).left(4).leftPad(4, '0');
                emp.Employee_Code__c = 'EMP-' + currentYear + '-' + codeSuffix;
            }
        }
    }

    private void provisionDefaultLeaveBalances(List<Employee__c> records) {
        Integer currentYear = Date.today().year();
        List<Leave_Balance__c> balancesToInsert = new List<Leave_Balance__c>();

        List<String> defaultTypes = new List<String>{ 'Casual Leave', 'Sick Leave', 'Paid Leave', 'Work From Home' };
        Map<String, Decimal> defaultQuotas = new Map<String, Decimal>{
            'Casual Leave' => 12.0,
            'Sick Leave' => 10.0,
            'Paid Leave' => 15.0,
            'Work From Home' => 20.0
        };

        for (Employee__c emp : records) {
            for (String lType : defaultTypes) {
                balancesToInsert.add(new Leave_Balance__c(
                    Employee__c = emp.Id,
                    Leave_Type__c = lType,
                    Total_Allocated__c = defaultQuotas.get(lType),
                    Used_Days__c = 0.0,
                    Year__c = currentYear
                ));
            }
        }

        if (!balancesToInsert.isEmpty()) {
            insert balancesToInsert;
        }
    }
}
