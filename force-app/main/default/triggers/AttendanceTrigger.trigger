/**
 * @description Master trigger for Attendance__c. Delegated to AttendanceTriggerHandler.
 */
trigger AttendanceTrigger on Attendance__c (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    AttendanceTriggerHandler handler = new AttendanceTriggerHandler();

    if (Trigger.isBefore && Trigger.isInsert) {
        handler.beforeInsert(Trigger.new);
    } else if (Trigger.isAfter && Trigger.isInsert) {
        handler.afterInsert(Trigger.new);
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        handler.beforeUpdate(Trigger.oldMap, Trigger.newMap);
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        handler.afterUpdate(Trigger.oldMap, Trigger.newMap);
    } else if (Trigger.isBefore && Trigger.isDelete) {
        handler.beforeDelete(Trigger.oldMap);
    } else if (Trigger.isAfter && Trigger.isDelete) {
        handler.afterDelete(Trigger.oldMap);
    } else if (Trigger.isAfter && Trigger.isUndelete) {
        handler.afterUndelete(Trigger.new);
    }
}
