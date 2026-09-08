public with sharing class EmployeeController {

	private static AuraHandledException createAuraHandledException(String message) {
		AuraHandledException ex = new AuraHandledException(message);
		ex.setMessage(message);
		return ex;
	}

	@AuraEnabled(cacheable = true)
	public static List < Employee__c > getEmployees() {
		try {
			return [
				SELECT Id,
				Name,
				First_Name__c,
				Last_Name__c,
				Employee_Code__c,
				Personal_Email__c,
				Mobile__c,
				Designation__c,
				Salary__c,
				Profile_Photo__c,
				Status__c,
				Joining_Date__c,
				CreatedDate
				FROM Employee__c
				WITH USER_MODE
				ORDER BY Name ASC, CreatedDate DESC
				LIMIT 2000
			];
		} catch (Exception e) {
			throw createAuraHandledException('Error fetching employee directory roster: ' + e.getMessage());
		}
	}

	@AuraEnabled
	public static Employee__c saveEmployee(Employee__c emp) {
		try {
			if(emp != null) {
				String fName = String.isNotBlank(emp.First_Name__c) ? emp.First_Name__c.trim() : '';
				String lName = String.isNotBlank(emp.Last_Name__c) ? emp.Last_Name__c.trim() : '';
				String fullConstructedName = (fName + ' ' + lName).trim();
				if(String.isBlank(emp.Name) || emp.Name.startsWith('a00') || emp.Name.length() >= 15) {
					if(String.isNotBlank(fullConstructedName)) {
						emp.Name = fullConstructedName;
					} else {
						emp.Name = 'New Employee Record';
					}
				}
			}
			SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPSERTABLE, new List < Employee__c > {
				emp
			});
			Employee__c securedEmp = (Employee__c) decision.getRecords()[0];
			upsert securedEmp;
			return securedEmp;
		} catch (Exception e) {
			throw createAuraHandledException('Error saving employee: ' + e.getMessage());
		}
	}

	@AuraEnabled
	public static void deleteEmployee(Id employeeId) {
		try {
			Employee__c emp = [SELECT Id FROM Employee__c WHERE Id = : employeeId WITH USER_MODE LIMIT 1];
			delete as user emp;
		} catch (Exception e) {
			throw createAuraHandledException('Error deleting employee record: ' + e.getMessage());
		}
	}

	@AuraEnabled(cacheable = true)
	public static Employee__c getEmployeeById(Id employeeId) {
		try {
			return [
				SELECT Id,
				Name,
				First_Name__c,
				Last_Name__c,
				Employee_Code__c,
				Personal_Email__c,
				Mobile__c,
				Designation__c,
				Salary__c,
				Profile_Photo__c,
				Status__c,
				Joining_Date__c
				FROM Employee__c
				WHERE Id = : employeeId
				WITH USER_MODE
				LIMIT 1
			];
		} catch (Exception e) {
			throw createAuraHandledException('Error fetching employee details: ' + e.getMessage());
		}
	}

	@AuraEnabled
	public static String updateEmployeeProfilePhoto(Id employeeId, Id contentDocumentId) {
		try {
			if (employeeId == null || contentDocumentId == null) {
				throw new IllegalArgumentException('Employee ID and Content Document ID are required.');
			}

			ContentVersion cv = [
				SELECT Id, Title, ContentDocumentId
				FROM ContentVersion
				WHERE ContentDocumentId = :contentDocumentId
				AND IsLatest = true
				WITH USER_MODE
				LIMIT 1
			];

			List<ContentDocumentLink> existingLinks = [
				SELECT Id
				FROM ContentDocumentLink
				WHERE LinkedEntityId = :employeeId
				AND ContentDocumentId = :contentDocumentId
				WITH USER_MODE
				LIMIT 1
			];

			if (existingLinks.isEmpty()) {
				ContentDocumentLink cdl = new ContentDocumentLink();
				cdl.LinkedEntityId = employeeId;
				cdl.ContentDocumentId = contentDocumentId;
				cdl.ShareType = 'V';
				cdl.Visibility = 'AllUsers';
				insert as user cdl;
			}

			String photoUrl = '/sfc/servlet.shepherd/version/download/' + cv.Id;
			Employee__c emp = new Employee__c(
				Id = employeeId,
				Profile_Photo__c = photoUrl
			);
			update as user emp;
			return photoUrl;
		} catch (Exception e) {
			throw createAuraHandledException('Error updating employee profile photo: ' + e.getMessage());
		}
	}

	@AuraEnabled
	public static void removeEmployeeProfilePhoto(Id employeeId) {
		try {
			if (employeeId == null) {
				throw new IllegalArgumentException('Employee ID is required.');
			}
			Employee__c emp = new Employee__c(
				Id = employeeId,
				Profile_Photo__c = null
			);
			update as user emp;
		} catch (Exception e) {
			throw createAuraHandledException('Error removing employee profile photo: ' + e.getMessage());
		}
	}


	// ==========================================
	// ATTENDANCE MANAGEMENT (Delegated to AttendanceController)
	// ==========================================
	@AuraEnabled
	public static void logAttendance(Id employeeId, String status) {
		AttendanceController.logAttendance(employeeId, status);
	}

	@AuraEnabled(cacheable = true)
	public static List < Attendance__c > getAttendanceList() {
		return AttendanceController.getAttendanceList();
	}

	@AuraEnabled
	public static void saveAttendance(Id attendanceId, Id employeeId, Date attendanceDate, Datetime checkIn, Datetime checkOut, String status, String workMode, String remarks) {
		AttendanceController.saveAttendance(attendanceId, employeeId, attendanceDate, checkIn, checkOut, status, workMode, remarks);
	}

	@AuraEnabled
	public static void deleteAttendance(Id attendanceId) {
		AttendanceController.deleteAttendance(attendanceId);
	}

	// ==========================================
	// LEAVE MANAGEMENT (Delegated to LeaveController)
	// ==========================================
	@AuraEnabled
	public static Leave_Request__c createLeaveRequest(Id employeeId, Date appliedDate, Id approvedById, Date startDate, Date endDate, String leaveType, String reason, String status) {
		return LeaveController.createLeaveRequest(employeeId, appliedDate, approvedById, startDate, endDate, leaveType, reason, status);
	}

	@AuraEnabled(cacheable = true)
	public static List < User > getUsers() {
		return LeaveController.getUsers();
	}

	@AuraEnabled(cacheable = true)
	public static List < Leave_Request__c > getLeaveRequests() {
		return LeaveController.getLeaveRequests();
	}

	// ==========================================
	// PAYROLL MANAGEMENT (Delegated to PayrollController)
	// ==========================================
	@AuraEnabled(cacheable = true)
	public static List < Payslip__c > getPayslips() {
		return PayrollController.getPayslips();
	}

	@AuraEnabled
	public static Payslip__c createPayslip(Id employeeId, String payMonth, Integer payYear, Decimal basicSalary, Decimal bonus, Decimal deductions, String status) {
		return PayrollController.createPayslip(employeeId, payMonth, payYear, basicSalary, bonus, deductions, status);
	}

	@AuraEnabled
	public static void deletePayslip(Id payslipId) {
		PayrollController.deletePayslip(payslipId);
	}

	// ==========================================
	// REPORTS MANAGEMENT (Delegated to HRReportsController)
	// ==========================================
	@AuraEnabled(cacheable = true)
	public static Map < String, Object > getReportData() {
		return HRReportsController.getReportData();
	}
}