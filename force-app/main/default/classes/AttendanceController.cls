/**
 * @description Dedicated controller for HRMS Attendance management.
 *              Handles employee check-in/out logs, roster queries, and attendance audits.
 */
public with sharing class AttendanceController {

    private static AuraHandledException createAuraHandledException(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }

    /**
     * @description Logs a quick daily attendance record for an employee.
     */
    @AuraEnabled
    public static Attendance__c logAttendance(Id employeeId, String status) {
        try {
            if (employeeId == null) {
                throw new IllegalArgumentException('Cannot record attendance without an active Employee ID.');
            }
            Attendance__c record = new Attendance__c(
                Employee__c = employeeId,
                Status__c = String.isNotBlank(status) ? status : 'Present',
                Check_In__c = Datetime.now(),
                Attendance_Date__c = Date.today()
            );

            insert as user record;
            return record;
        } catch (Exception e) {
            throw createAuraHandledException('Error logging attendance record: ' + e.getMessage());
        }
    }

    /**
     * @description Fetches all attendance records ordered chronologically.
     */
    @AuraEnabled(cacheable=true)
    public static List<Attendance__c> getAttendanceList() {
        try {
            return [
                SELECT Id,
                       Employee__c,
                       Employee__r.Name,
                       Employee__r.First_Name__c,
                       Employee__r.Last_Name__c,
                       Attendance_Date__c,
                       Check_In__c,
                       Check_Out__c,
                       Status__c,
                       Work_Mode__c,
                       Total_Hours__c,
                       Overtime_Hours__c,
                       Remarks__c
                FROM Attendance__c
                WITH USER_MODE
                ORDER BY Attendance_Date__c DESC, CreatedDate DESC
                LIMIT 2000
            ];
        } catch (Exception e) {
            throw createAuraHandledException('Error fetching attendance records: ' + e.getMessage());
        }
    }

    /**
     * @description Upserts an attendance record with full parameters.
     */
    @AuraEnabled
    public static Attendance__c saveAttendance(
        Id attendanceId,
        Id employeeId,
        Date attendanceDate,
        Datetime checkIn,
        Datetime checkOut,
        String status,
        String workMode,
        String remarks
    ) {
        try {
            if (employeeId == null) {
                throw new IllegalArgumentException('Employee ID is required for saving attendance.');
            }
            if (checkIn != null && checkOut != null && checkOut < checkIn) {
                throw new IllegalArgumentException('Check-Out time cannot be earlier than Check-In time.');
            }

            Attendance__c record = new Attendance__c();
            if (attendanceId != null) {
                record.Id = attendanceId;
            }
            record.Employee__c = employeeId;
            record.Attendance_Date__c = attendanceDate != null ? attendanceDate : Date.today();
            record.Check_In__c = checkIn;
            record.Check_Out__c = checkOut;
            record.Status__c = status;
            record.Work_Mode__c = workMode;
            record.Remarks__c = remarks;

            upsert as user record;
            return record;
        } catch (Exception e) {
            throw createAuraHandledException('Error saving attendance: ' + e.getMessage());
        }
    }

    /**
     * @description Deletes an attendance record by ID.
     */
    @AuraEnabled
    public static void deleteAttendance(Id attendanceId) {
        try {
            if (attendanceId == null) {
                throw new IllegalArgumentException('Attendance Id is required for delete.');
            }
            Attendance__c record = [
                SELECT Id 
                FROM Attendance__c 
                WHERE Id = :attendanceId 
                WITH USER_MODE 
                LIMIT 1
            ];
            delete as user record;
        } catch (Exception e) {
            throw createAuraHandledException('Error deleting attendance record: ' + e.getMessage());
        }
    }
}
