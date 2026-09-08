/**
 * @description Dedicated controller for HRMS Analytics and Reporting.
 *              Executes optimized aggregate queries for workforce distribution,
 *              attendance trends, leave analytics, and payroll ledger stats.
 */
public with sharing class HRReportsController {

    private static AuraHandledException createAuraHandledException(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }

    /**
     * @description Fetches all aggregated metric datasets for HRMS dashboard charts.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getReportData() {
        Map<String, Object> result = new Map<String, Object>();
        try {
            // 1. Employees by Designation
            List<Map<String, Object>> designationData = new List<Map<String, Object>>();
            for (AggregateResult ar : [
                SELECT Designation__c designation, COUNT(Id) total
                FROM Employee__c
                WHERE Designation__c != null
                WITH USER_MODE
                GROUP BY Designation__c
                ORDER BY COUNT(Id) DESC
            ]) {
                designationData.add(new Map<String, Object>{
                    'label' => String.valueOf(ar.get('designation')),
                    'value' => Integer.valueOf(String.valueOf(ar.get('total')))
                });
            }
            result.put('designationData', designationData);

            // 2. Employees by Status
            List<Map<String, Object>> employeeStatus = new List<Map<String, Object>>();
            for (AggregateResult ar : [
                SELECT Status__c status, COUNT(Id) total
                FROM Employee__c
                WHERE Status__c != null
                WITH USER_MODE
                GROUP BY Status__c
            ]) {
                employeeStatus.add(new Map<String, Object>{
                    'label' => String.valueOf(ar.get('status')),
                    'value' => Integer.valueOf(String.valueOf(ar.get('total')))
                });
            }
            result.put('employeeStatus', employeeStatus);

            // 3. Employees Joined by Month
            List<Map<String, Object>> joiningData = new List<Map<String, Object>>();
            for (AggregateResult ar : [
                SELECT CALENDAR_MONTH(Joining_Date__c) monthNumber, COUNT(Id) total
                FROM Employee__c
                WHERE Joining_Date__c != null
                WITH USER_MODE
                GROUP BY CALENDAR_MONTH(Joining_Date__c)
                ORDER BY CALENDAR_MONTH(Joining_Date__c)
            ]) {
                joiningData.add(new Map<String, Object>{
                    'month' => Integer.valueOf(String.valueOf(ar.get('monthNumber'))),
                    'value' => Integer.valueOf(String.valueOf(ar.get('total')))
                });
            }
            result.put('joiningData', joiningData);

            // 4. Attendance Status Distribution
            List<Map<String, Object>> attendanceStatus = new List<Map<String, Object>>();
            for (AggregateResult ar : [
                SELECT Status__c status, COUNT(Id) total
                FROM Attendance__c
                WHERE Status__c != null
                WITH USER_MODE
                GROUP BY Status__c
            ]) {
                attendanceStatus.add(new Map<String, Object>{
                    'label' => String.valueOf(ar.get('status')),
                    'value' => Integer.valueOf(String.valueOf(ar.get('total')))
                });
            }
            result.put('attendanceStatus', attendanceStatus);

            // 5. Attendance Work Mode Distribution
            List<Map<String, Object>> workModeData = new List<Map<String, Object>>();
            for (AggregateResult ar : [
                SELECT Work_Mode__c workMode, COUNT(Id) total
                FROM Attendance__c
                WHERE Work_Mode__c != null
                WITH USER_MODE
                GROUP BY Work_Mode__c
            ]) {
                workModeData.add(new Map<String, Object>{
                    'label' => String.valueOf(ar.get('workMode')),
                    'value' => Integer.valueOf(String.valueOf(ar.get('total')))
                });
            }
            result.put('workModeData', workModeData);

            // 6. Leave Requests by Type
            List<Map<String, Object>> leaveTypeData = new List<Map<String, Object>>();
            for (AggregateResult ar : [
                SELECT Leave_Type__c leaveType, COUNT(Id) total
                FROM Leave_Request__c
                WHERE Leave_Type__c != null
                WITH USER_MODE
                GROUP BY Leave_Type__c
            ]) {
                leaveTypeData.add(new Map<String, Object>{
                    'label' => String.valueOf(ar.get('leaveType')),
                    'value' => Integer.valueOf(String.valueOf(ar.get('total')))
                });
            }
            result.put('leaveTypeData', leaveTypeData);

            // 7. Leave Requests by Status
            List<Map<String, Object>> leaveStatusData = new List<Map<String, Object>>();
            for (AggregateResult ar : [
                SELECT Status__c status, COUNT(Id) total
                FROM Leave_Request__c
                WHERE Status__c != null
                WITH USER_MODE
                GROUP BY Status__c
            ]) {
                leaveStatusData.add(new Map<String, Object>{
                    'label' => String.valueOf(ar.get('status')),
                    'value' => Integer.valueOf(String.valueOf(ar.get('total')))
                });
            }
            result.put('leaveStatusData', leaveStatusData);

            // 8. Payroll by Top Employees
            List<Map<String, Object>> payrollData = new List<Map<String, Object>>();
            for (AggregateResult ar : [
                SELECT Employee__r.Name employeeName, SUM(Gross_Salary__c) salary
                FROM Payslip__c
                WHERE Gross_Salary__c != null AND Employee__c != null
                WITH USER_MODE
                GROUP BY Employee__r.Name
                ORDER BY SUM(Gross_Salary__c) DESC
                LIMIT 10
            ]) {
                payrollData.add(new Map<String, Object>{
                    'label' => String.valueOf(ar.get('employeeName')),
                    'value' => Decimal.valueOf(String.valueOf(ar.get('salary')))
                });
            }
            result.put('payrollData', payrollData);

            // 9. Payslips by Status
            List<Map<String, Object>> payslipStatus = new List<Map<String, Object>>();
            for (AggregateResult ar : [
                SELECT Status__c status, COUNT(Id) total
                FROM Payslip__c
                WHERE Status__c != null
                WITH USER_MODE
                GROUP BY Status__c
            ]) {
                payslipStatus.add(new Map<String, Object>{
                    'label' => String.valueOf(ar.get('status')),
                    'value' => Integer.valueOf(String.valueOf(ar.get('total')))
                });
            }
            result.put('payslipStatus', payslipStatus);

            return result;
        } catch (Exception e) {
            throw createAuraHandledException('Error fetching report data: ' + e.getMessage());
        }
    }
}
