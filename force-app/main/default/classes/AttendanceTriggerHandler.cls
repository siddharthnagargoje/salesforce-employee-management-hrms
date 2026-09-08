/**
 * @description Dedicated trigger handler for Attendance__c operations.
 *              Prevents duplicate daily attendance punches and validates check-in/out timestamps.
 */
public with sharing class AttendanceTriggerHandler {

    public void beforeInsert(List<Attendance__c> newRecords) {
        validateTimes(newRecords);
        preventDuplicateDailyAttendance(newRecords, null);
    }

    public void beforeUpdate(Map<Id, Attendance__c> oldMap, Map<Id, Attendance__c> newMap) {
        validateTimes(newMap.values());
        preventDuplicateDailyAttendance(newMap.values(), oldMap.keySet());
    }

    public void afterInsert(List<Attendance__c> newRecords) {
        // Reserved
    }

    public void afterUpdate(Map<Id, Attendance__c> oldMap, Map<Id, Attendance__c> newMap) {
        // Reserved
    }

    public void beforeDelete(Map<Id, Attendance__c> oldMap) {
        // Reserved
    }

    public void afterDelete(Map<Id, Attendance__c> oldMap) {
        // Reserved
    }

    public void afterUndelete(List<Attendance__c> restoredRecords) {
        // Reserved
    }

    private void validateTimes(List<Attendance__c> records) {
        for (Attendance__c att : records) {
            if (att.Check_In__c != null && att.Check_Out__c != null && att.Check_Out__c < att.Check_In__c) {
                att.Check_Out__c.addError('Check-Out time cannot be earlier than Check-In time.');
            }
        }
    }

    private void preventDuplicateDailyAttendance(List<Attendance__c> records, Set<Id> existingIds) {
        Set<Id> empIds = new Set<Id>();
        Set<Date> dates = new Set<Date>();

        for (Attendance__c att : records) {
            if (att.Employee__c != null && att.Attendance_Date__c != null) {
                empIds.add(att.Employee__c);
                dates.add(att.Attendance_Date__c);
            }
        }

        if (empIds.isEmpty()) {
            return;
        }

        List<Attendance__c> existingRecords = [
            SELECT Id, Employee__c, Attendance_Date__c
            FROM Attendance__c
            WHERE Employee__c IN :empIds
            AND Attendance_Date__c IN :dates
        ];

        Set<String> existingKeys = new Set<String>();
        for (Attendance__c att : existingRecords) {
            if (existingIds != null && existingIds.contains(att.Id)) {
                continue;
            }
            existingKeys.add(att.Employee__c + '_' + String.valueOf(att.Attendance_Date__c));
        }

        Set<String> incomingKeysInBatch = new Set<String>();
        for (Attendance__c incoming : records) {
            if (incoming.Employee__c == null || incoming.Attendance_Date__c == null) {
                continue;
            }

            String key = incoming.Employee__c + '_' + String.valueOf(incoming.Attendance_Date__c);
            if (existingKeys.contains(key) || incomingKeysInBatch.contains(key)) {
                incoming.addError('An attendance record already exists for this employee on ' + incoming.Attendance_Date__c.format() + '.');
            } else {
                incomingKeysInBatch.add(key);
            }
        }
    }
}
