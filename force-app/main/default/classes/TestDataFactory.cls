/**
 * @description Standardized test data factory for HRMS unit tests.
 *              Generates test records for Employee__c, Attendance__c, Leave_Request__c, and Payslip__c.
 */
@IsTest
public class TestDataFactory {

    public static Employee__c createEmployee(String firstName, String lastName, String designation, String status, Date joiningDate, Boolean doInsert) {
        Employee__c emp = new Employee__c(
            First_Name__c = firstName,
            Last_Name__c = lastName,
            Name = (String.isNotBlank(firstName) && String.isNotBlank(lastName)) ? (firstName + ' ' + lastName) : 'Test Employee',
            Employee_Code__c = 'EMP-' + String.valueOf(Crypto.getRandomInteger()).substring(1, 6),
            Personal_Email__c = (String.isNotBlank(firstName) ? firstName.toLowerCase() : 'user') + '@hrmstest.com',
            Mobile__c = '9876543210',
            Designation__c = String.isNotBlank(designation) ? designation : 'Salesforce Developer',
            Status__c = String.isNotBlank(status) ? status : 'Active',
            Joining_Date__c = joiningDate != null ? joiningDate : Date.today().addMonths(-6),
            Salary__c = 75000
        );

        if (doInsert) {
            insert emp;
        }
        return emp;
    }

    public static List<Employee__c> createEmployees(Integer count, Boolean doInsert) {
        List<Employee__c> employees = new List<Employee__c>();
        for (Integer i = 0; i < count; i++) {
            employees.add(new Employee__c(
                First_Name__c = 'FirstName' + i,
                Last_Name__c = 'LastName' + i,
                Name = 'FirstName' + i + ' LastName' + i,
                Employee_Code__c = 'EMP' + String.valueOf(1000 + i),
                Personal_Email__c = 'employee' + i + '@hrmstest.com',
                Mobile__c = '987654321' + Math.mod(i, 10),
                Designation__c = Math.mod(i, 2) == 0 ? 'Salesforce Developer' : 'HR Manager',
                Status__c = Math.mod(i, 2) == 0 ? 'Active' : 'Inactive',
                Joining_Date__c = Date.today().addMonths(-Math.mod(i, 12) - 1),
                Salary__c = 60000 + (i * 5000)
            ));
        }

        if (doInsert && !employees.isEmpty()) {
            insert employees;
        }
        return employees;
    }

    public static Attendance__c createAttendance(Id employeeId, Date attendanceDate, Datetime checkIn, Datetime checkOut, String status, String workMode, String remarks, Boolean doInsert) {
        Attendance__c att = new Attendance__c(
            Employee__c = employeeId,
            Attendance_Date__c = attendanceDate != null ? attendanceDate : Date.today(),
            Check_In__c = checkIn != null ? checkIn : Datetime.now().addHours(-8),
            Check_Out__c = checkOut != null ? checkOut : Datetime.now(),
            Status__c = String.isNotBlank(status) ? status : 'Present',
            Work_Mode__c = String.isNotBlank(workMode) ? workMode : 'Office',
            Remarks__c = remarks != null ? remarks : 'Standard punch in/out'
        );

        if (doInsert) {
            insert att;
        }
        return att;
    }

    public static Leave_Request__c createLeaveRequest(Id employeeId, Date appliedDate, Id approverId, Date startDate, Date endDate, String leaveType, String reason, String status, Boolean doInsert) {
        Leave_Request__c leave = new Leave_Request__c(
            Employee__c = employeeId,
            Applied_Date__c = appliedDate != null ? appliedDate : Date.today(),
            Approved_By__c = approverId,
            Start_Date__c = startDate != null ? startDate : Date.today().addDays(3),
            End_Date__c = endDate != null ? endDate : Date.today().addDays(5),
            Leave_Type__c = String.isNotBlank(leaveType) ? leaveType : 'Sick Leave',
            Reason__c = String.isNotBlank(reason) ? reason : 'Medical checkup',
            Status__c = String.isNotBlank(status) ? status : 'Pending'
        );

        if (doInsert) {
            insert leave;
        }
        return leave;
    }

    public static Payslip__c createPayslip(Id employeeId, String payMonth, Integer payYear, Decimal basicSalary, Decimal bonus, Decimal deductions, String status, Boolean doInsert) {
        Payslip__c slip = new Payslip__c(
            Employee__c = employeeId,
            Pay_Month__c = String.isNotBlank(payMonth) ? payMonth : 'August',
            Pay_Year__c = payYear != null ? payYear : Date.today().year(),
            Basic_Salary__c = basicSalary != null ? basicSalary : 60000,
            Bonus__c = bonus != null ? bonus : 5000,
            Deductions__c = deductions != null ? deductions : 2000,
            Status__c = String.isNotBlank(status) ? status : 'Paid'
        );

        if (doInsert) {
            insert slip;
        }
        return slip;
    }
}
