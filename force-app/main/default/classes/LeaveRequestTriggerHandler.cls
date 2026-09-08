/**
 * @description Dedicated trigger handler for Leave_Request__c.
 *              Enforces business validation, prevents date overlaps,
 *              and deducts quotas from Leave_Balance__c upon approval.
 */
public with sharing class LeaveRequestTriggerHandler {

    public void beforeInsert(List<Leave_Request__c> newRecords) {
        validateLeaveDates(newRecords);
        preventOverlappingLeaves(newRecords, null);
    }

    public void beforeUpdate(Map<Id, Leave_Request__c> oldMap, Map<Id, Leave_Request__c> newMap) {
        validateLeaveDates(newMap.values());
        preventOverlappingLeaves(newMap.values(), oldMap.keySet());
    }

    public void afterInsert(List<Leave_Request__c> newRecords) {
        // Reserved for post-insert notification dispatches
    }

    public void afterUpdate(Map<Id, Leave_Request__c> oldMap, Map<Id, Leave_Request__c> newMap) {
        handleLeaveApprovals(oldMap, newMap);
    }

    public void beforeDelete(Map<Id, Leave_Request__c> oldMap) {
        for (Leave_Request__c lr : oldMap.values()) {
            if (lr.Status__c == 'Approved') {
                lr.addError('Approved leave requests cannot be deleted.');
            }
        }
    }

    public void afterDelete(Map<Id, Leave_Request__c> oldMap) {
        // Reserved
    }

    public void afterUndelete(List<Leave_Request__c> restoredRecords) {
        // Reserved
    }

    private void validateLeaveDates(List<Leave_Request__c> records) {
        for (Leave_Request__c lr : records) {
            if (lr.Start_Date__c != null && lr.End_Date__c != null && lr.End_Date__c < lr.Start_Date__c) {
                lr.End_Date__c.addError('End Date cannot be earlier than Start Date.');
            }
        }
    }

    private void preventOverlappingLeaves(List<Leave_Request__c> records, Set<Id> existingIds) {
        Set<Id> empIds = new Set<Id>();
        for (Leave_Request__c lr : records) {
            if (lr.Employee__c != null && lr.Start_Date__c != null && lr.End_Date__c != null) {
                empIds.add(lr.Employee__c);
            }
        }

        if (empIds.isEmpty()) {
            return;
        }

        // Query active leaves for these employees
        List<Leave_Request__c> activeLeaves = [
            SELECT Id, Employee__c, Start_Date__c, End_Date__c, Status__c
            FROM Leave_Request__c
            WHERE Employee__c IN :empIds
            AND Status__c IN ('Pending', 'Approved')
        ];

        for (Leave_Request__c incoming : records) {
            if (incoming.Employee__c == null || incoming.Start_Date__c == null || incoming.End_Date__c == null) {
                continue;
            }

            for (Leave_Request__c existing : activeLeaves) {
                if (existingIds != null && existingIds.contains(existing.Id)) {
                    continue;
                }
                if (existing.Id == incoming.Id) {
                    continue;
                }
                if (existing.Employee__c == incoming.Employee__c) {
                    // Check overlap condition: (StartA <= EndB) and (EndA >= StartB)
                    Boolean overlaps = (incoming.Start_Date__c <= existing.End_Date__c) && 
                                       (incoming.End_Date__c >= existing.Start_Date__c);
                    if (overlaps) {
                        incoming.addError('An active leave request already exists covering the selected dates (' + 
                            existing.Start_Date__c.format() + ' to ' + existing.End_Date__c.format() + ').');
                        break;
                    }
                }
            }
        }
    }

    private void handleLeaveApprovals(Map<Id, Leave_Request__c> oldMap, Map<Id, Leave_Request__c> newMap) {
        Set<Id> employeeIds = new Set<Id>();
        List<Leave_Request__c> newlyApproved = new List<Leave_Request__c>();

        for (Id lrId : newMap.keySet()) {
            Leave_Request__c oldRec = oldMap.get(lrId);
            Leave_Request__c newRec = newMap.get(lrId);

            if (oldRec.Status__c != 'Approved' && newRec.Status__c == 'Approved') {
                newlyApproved.add(newRec);
                employeeIds.add(newRec.Employee__c);
            }
        }

        if (newlyApproved.isEmpty()) {
            return;
        }

        // Query relevant leave balances
        List<Leave_Balance__c> balances = [
            SELECT Id, Employee__c, Leave_Type__c, Total_Allocated__c, Used_Days__c, Year__c
            FROM Leave_Balance__c
            WHERE Employee__c IN :employeeIds
        ];

        Map<String, Leave_Balance__c> balanceKeyMap = new Map<String, Leave_Balance__c>();
        for (Leave_Balance__c lb : balances) {
            String key = lb.Employee__c + '_' + lb.Leave_Type__c + '_' + lb.Year__c;
            balanceKeyMap.put(key, lb);
        }

        List<Leave_Balance__c> balancesToUpdate = new List<Leave_Balance__c>();

        for (Leave_Request__c lr : newlyApproved) {
            if (lr.Start_Date__c == null || lr.End_Date__c == null) {
                continue;
            }
            Integer year = lr.Start_Date__c.year();
            String key = lr.Employee__c + '_' + lr.Leave_Type__c + '_' + year;

            Leave_Balance__c lb = balanceKeyMap.get(key);
            if (lb != null) {
                Decimal days = lr.Start_Date__c.daysBetween(lr.End_Date__c) + 1;
                lb.Used_Days__c = (lb.Used_Days__c != null ? lb.Used_Days__c : 0) + days;
                balancesToUpdate.add(lb);
            }
        }

        if (!balancesToUpdate.isEmpty()) {
            update balancesToUpdate;
        }
    }
}
