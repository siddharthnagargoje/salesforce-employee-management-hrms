/**
 * @description Dedicated controller for HRMS Leave Management.
 *              Handles leave submissions, approvals, rejections, and quota workflows.
 */
public with sharing class LeaveController {

    private static AuraHandledException createAuraHandledException(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }

    /**
     * @description Fetches all leave requests ordered by submission date.
     */
    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getLeaveRequests() {
        try {
            return [
                SELECT Id,
                       Employee__c,
                       Employee__r.Name,
                       Applied_Date__c,
                       Start_Date__c,
                       End_Date__c,
                       Leave_Type__c,
                       Reason__c,
                       Status__c,
                       Comments__c,
                       Approved_By__c,
                       Approved_By__r.Name
                FROM Leave_Request__c
                WITH USER_MODE
                ORDER BY Applied_Date__c DESC, CreatedDate DESC
                LIMIT 2000
            ];
        } catch (Exception e) {
            throw createAuraHandledException('Error fetching leave requests: ' + e.getMessage());
        }
    }

    /**
     * @description Creates a new leave request record with validation.
     */
    @AuraEnabled
    public static Leave_Request__c createLeaveRequest(
        Id employeeId,
        Date appliedDate,
        Id approvedById,
        Date startDate,
        Date endDate,
        String leaveType,
        String reason,
        String status
    ) {
        try {
            if (employeeId == null) {
                throw new IllegalArgumentException('Employee ID is required to file a leave request.');
            }
            if (startDate != null && endDate != null && endDate < startDate) {
                throw new IllegalArgumentException('End Date cannot be earlier than Start Date.');
            }

            Leave_Request__c leave = new Leave_Request__c(
                Employee__c = employeeId,
                Applied_Date__c = appliedDate != null ? appliedDate : Date.today(),
                Approved_By__c = approvedById,
                Start_Date__c = startDate,
                End_Date__c = endDate,
                Leave_Type__c = leaveType,
                Reason__c = reason,
                Status__c = String.isNotBlank(status) ? status : 'Pending'
            );

            insert as user leave;
            return leave;
        } catch (Exception e) {
            throw createAuraHandledException('Error creating leave request: ' + e.getMessage());
        }
    }

    /**
     * @description Approves or rejects a leave request with reviewer comments.
     */
    @AuraEnabled
    public static Leave_Request__c updateLeaveStatus(Id leaveId, String status, String comments) {
        try {
            if (leaveId == null) {
                throw new IllegalArgumentException('Leave Request ID is required.');
            }
            if (String.isBlank(status)) {
                throw new IllegalArgumentException('Status is required for status transition.');
            }

            Leave_Request__c leave = [
                SELECT Id, Status__c, Comments__c, Approved_By__c
                FROM Leave_Request__c
                WHERE Id = :leaveId
                WITH USER_MODE
                LIMIT 1
            ];

            leave.Status__c = status;
            if (String.isNotBlank(comments)) {
                leave.Comments__c = comments;
            }
            if (status == 'Approved' || status == 'Rejected') {
                leave.Approved_By__c = UserInfo.getUserId();
            }

            update as user leave;
            return leave;
        } catch (Exception e) {
            throw createAuraHandledException('Error updating leave request status: ' + e.getMessage());
        }
    }

    /**
     * @description Returns active users available for assignment as leave approvers.
     */
    @AuraEnabled(cacheable=true)
    public static List<User> getUsers() {
        try {
            return [
                SELECT Id, Name
                FROM User
                WHERE IsActive = true
                WITH USER_MODE
                ORDER BY Name ASC
                LIMIT 500
            ];
        } catch (Exception e) {
            throw createAuraHandledException('Error fetching approvers: ' + e.getMessage());
        }
    }
}
