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


	@AuraEnabled
	public static void logAttendance(Id employeeId, String status) {
		try {
			if(employeeId == null) {
				throw new IllegalArgumentException('Cannot map attendance without an active Employee ID.');
			}
			Attendance__c newAttendanceLog = new Attendance__c();
			newAttendanceLog.Employee__c = employeeId;
			newAttendanceLog.Status__c = status;
			newAttendanceLog.Check_In__c = Datetime.now();
			newAttendanceLog.Attendance_Date__c = System.today();
			insert as user newAttendanceLog;
		} catch (Exception e) {
			throw createAuraHandledException('Error logging attendance record: ' + e.getMessage());
		}
	}

	@AuraEnabled(cacheable = true)
	public static List < Attendance__c > getAttendanceList() {
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

	@AuraEnabled
	public static void saveAttendance(Id attendanceId, Id employeeId, Date attendanceDate, Datetime checkIn, Datetime checkOut, String status, String workMode, String remarks) {
		try {
			Attendance__c attendance = new Attendance__c();
			if (attendanceId != null) {
				attendance.Id = attendanceId;
			}
			attendance.Employee__c = employeeId;
			attendance.Attendance_Date__c = attendanceDate;
			attendance.Check_In__c = checkIn;
			attendance.Check_Out__c = checkOut;
			attendance.Status__c = status;
			attendance.Work_Mode__c = workMode;
			attendance.Remarks__c = remarks;
			upsert as user attendance;
		} catch (Exception e) {
			throw createAuraHandledException('Error saving attendance: ' + e.getMessage());
		}
	}

	@AuraEnabled
	public static void deleteAttendance(Id attendanceId) {
		try {
			if(attendanceId == null) {
				throw createAuraHandledException('Attendance Id is required for delete.');
			}
			Attendance__c att = [SELECT Id FROM Attendance__c WHERE Id = : attendanceId WITH USER_MODE LIMIT 1];
			delete as user att;
		} catch (Exception e) {
			throw createAuraHandledException('Error deleting attendance record: ' + e.getMessage());
		}
	}

	@AuraEnabled
	public static Leave_Request__c createLeaveRequest(Id employeeId, Date appliedDate, Id approvedById, Date startDate, Date endDate, String leaveType, String reason, String status) {
		try {
			Leave_Request__c leave = new Leave_Request__c();
			leave.Employee__c = employeeId;
			leave.Applied_Date__c = appliedDate;
			leave.Approved_By__c = approvedById;
			leave.Start_Date__c = startDate;
			leave.End_Date__c = endDate;
			leave.Leave_Type__c = leaveType;
			leave.Reason__c = reason;
			leave.Status__c = status;
			insert as user leave;
			return leave;
		} catch (Exception e) {
			throw createAuraHandledException('Error creating leave request: ' + e.getMessage());
		}
	}

	@AuraEnabled(cacheable = true)
	public static List < User > getUsers() {
		try {
			return [
				SELECT Id, Name
				FROM User
				WHERE IsActive = true
				WITH USER_MODE
				ORDER BY Name
				LIMIT 500
			];
		} catch (Exception e) {
			throw createAuraHandledException('Error fetching approvers: ' + e.getMessage());
		}
	}

	@AuraEnabled(cacheable = true)
	public static List < Leave_Request__c > getLeaveRequests() {
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
				Status__c
				FROM Leave_Request__c
				WITH USER_MODE
				ORDER BY Applied_Date__c DESC, CreatedDate DESC
				LIMIT 2000
			];
		} catch (Exception e) {
			throw createAuraHandledException('Error fetching leave requests: ' + e.getMessage());
		}
	}

	@AuraEnabled(cacheable = true)
	public static List < Payslip__c > getPayslips() {
		try {
			return [
				SELECT Id,
				Name,
				Employee__c,
				Employee__r.Name,
				Pay_Month__c,
				Pay_Year__c,
				Basic_Salary__c,
				Bonus__c,
				Deductions__c,
				Gross_Salary__c,
				Status__c,
				PDF_Generated__c,
				CreatedDate,
				Downloaded_File__c
				FROM Payslip__c
				WITH USER_MODE
				ORDER BY CreatedDate DESC
				LIMIT 2000
			];
		} catch (Exception e) {
			throw createAuraHandledException('Error fetching payslips: ' + e.getMessage());
		}
	}

	@AuraEnabled
	public static Payslip__c createPayslip(Id employeeId, String payMonth, Integer payYear, Decimal basicSalary, Decimal bonus, Decimal deductions, String status) {
		try {
			Payslip__c payslip = new Payslip__c();
			payslip.Employee__c = employeeId;
			payslip.Pay_Month__c = payMonth;
			payslip.Pay_Year__c = payYear;
			payslip.Basic_Salary__c = basicSalary;
			payslip.Bonus__c = bonus;
			payslip.Deductions__c = deductions;
			payslip.Status__c = status;
			insert as user payslip;
			return payslip;
		} catch (Exception e) {
			throw createAuraHandledException('Error creating payslip: ' + e.getMessage());
		}
	}

	@AuraEnabled
	public static void deletePayslip(Id payslipId) {
		try {
			if(payslipId == null) {
				throw createAuraHandledException('Payslip Id is required for delete.');
			}
			Payslip__c slip = [SELECT Id FROM Payslip__c WHERE Id = : payslipId WITH USER_MODE LIMIT 1];
			delete as user slip;
		} catch (Exception e) {
			throw createAuraHandledException('Error deleting payslip: ' + e.getMessage());
		}
	}

	// ==========================================
	// REPORTS MANAGEMENT
	// ==========================================
	@AuraEnabled(cacheable = true)
	public static Map < String, Object > getReportData() {
		Map < String, Object > result = new Map < String, Object > ();
		try {
			// ==========================================
			// 1. EMPLOYEES BY DESIGNATION
			// ==========================================
			List < Map < String, Object >> designationData = new List < Map < String, Object >> ();
			for(AggregateResult ar: [
					SELECT Designation__c designation,
					COUNT(Id) total
					FROM Employee__c
					WHERE Designation__c != null
					WITH USER_MODE
					GROUP BY Designation__c
					ORDER BY COUNT(Id) DESC
				]) {
				designationData.add(new Map < String, Object > {
					'label' => String.valueOf(ar.get('designation')),
					'value' => Integer.valueOf(String.valueOf(ar.get('total')))
				});
			}
			result.put('designationData', designationData);
			// ==========================================
			// 2. EMPLOYEE STATUS
			// ==========================================
			List < Map < String, Object >> employeeStatus = new List < Map < String, Object >> ();
			for(AggregateResult ar: [
					SELECT Status__c status,
					COUNT(Id) total
					FROM Employee__c
					WHERE Status__c != null
					WITH USER_MODE
					GROUP BY Status__c
				]) {
				employeeStatus.add(new Map < String, Object > {
					'label' => String.valueOf(ar.get('status')),
					'value' => Integer.valueOf(String.valueOf(ar.get('total')))
				});
			}
			result.put('employeeStatus', employeeStatus);
			// ==========================================
			// 3. EMPLOYEES JOINED BY MONTH
			// ==========================================
			List < Map < String, Object >> joiningData = new List < Map < String, Object >> ();
			for(AggregateResult ar: [
					SELECT CALENDAR_MONTH(Joining_Date__c) monthNumber,
					COUNT(Id) total
					FROM Employee__c
					WHERE Joining_Date__c != null
					WITH USER_MODE
					GROUP BY CALENDAR_MONTH(Joining_Date__c)
					ORDER BY CALENDAR_MONTH(Joining_Date__c)
				]) {
				joiningData.add(new Map < String, Object > {
					'month' => Integer.valueOf(String.valueOf(ar.get('monthNumber'))),
					'value' => Integer.valueOf(String.valueOf(ar.get('total')))
				});
			}
			result.put('joiningData', joiningData);
			// ==========================================
			// 4. ATTENDANCE STATUS
			// ==========================================
			List < Map < String, Object >> attendanceStatus = new List < Map < String, Object >> ();
			for(AggregateResult ar: [
					SELECT Status__c status,
					COUNT(Id) total
					FROM Attendance__c
					WHERE Status__c != null
					WITH USER_MODE
					GROUP BY Status__c
				]) {
				attendanceStatus.add(new Map < String, Object > {
					'label' => String.valueOf(ar.get('status')),
					'value' => Integer.valueOf(String.valueOf(ar.get('total')))
				});
			}
			result.put('attendanceStatus', attendanceStatus);
			// ==========================================
			// 5. ATTENDANCE WORK MODE
			// ==========================================
			List < Map < String, Object >> workModeData = new List < Map < String, Object >> ();
			for(AggregateResult ar: [
					SELECT Work_Mode__c workMode,
					COUNT(Id) total
					FROM Attendance__c
					WHERE Work_Mode__c != null
					WITH USER_MODE
					GROUP BY Work_Mode__c
				]) {
				workModeData.add(new Map < String, Object > {
					'label' => String.valueOf(ar.get('workMode')),
					'value' => Integer.valueOf(String.valueOf(ar.get('total')))
				});
			}
			result.put('workModeData', workModeData);
			// ==========================================
			// 6. LEAVE TYPE
			// ==========================================
			List < Map < String, Object >> leaveTypeData = new List < Map < String, Object >> ();
			for(AggregateResult ar: [
					SELECT Leave_Type__c leaveType,
					COUNT(Id) total
					FROM Leave_Request__c
					WHERE Leave_Type__c != null
					WITH USER_MODE
					GROUP BY Leave_Type__c
				]) {
				leaveTypeData.add(new Map < String, Object > {
					'label' => String.valueOf(ar.get('leaveType')),
					'value' => Integer.valueOf(String.valueOf(ar.get('total')))
				});
			}
			result.put('leaveTypeData', leaveTypeData);
			// ==========================================
			// 7. LEAVE STATUS
			// ==========================================
			List < Map < String, Object >> leaveStatusData = new List < Map < String, Object >> ();
			for(AggregateResult ar: [
					SELECT Status__c status,
					COUNT(Id) total
					FROM Leave_Request__c
					WHERE Status__c != null
					WITH USER_MODE
					GROUP BY Status__c
				]) {
				leaveStatusData.add(new Map < String, Object > {
					'label' => String.valueOf(ar.get('status')),
					'value' => Integer.valueOf(String.valueOf(ar.get('total')))
				});
			}
			result.put('leaveStatusData', leaveStatusData);
			// ==========================================
			// 8. PAYROLL BY EMPLOYEE
			// ==========================================
			List < Map < String, Object >> payrollData = new List < Map < String, Object >> ();
			for(AggregateResult ar: [
					SELECT Employee__r.Name employeeName,
					SUM(Gross_Salary__c) salary
					FROM Payslip__c
					WHERE Gross_Salary__c != null
					AND Employee__c != null
					WITH USER_MODE
					GROUP BY Employee__r.Name
					ORDER BY SUM(Gross_Salary__c) DESC
					LIMIT 10
				]) {
				payrollData.add(new Map < String, Object > {
					'label' => String.valueOf(ar.get('employeeName')),
					'value' => Decimal.valueOf(String.valueOf(ar.get('salary')))
				});
			}
			result.put('payrollData', payrollData);
			// ==========================================
			// 9. PAYSLIP STATUS
			// ==========================================
			List < Map < String, Object >> payslipStatus = new List < Map < String, Object >> ();
			for(AggregateResult ar: [
					SELECT Status__c status,
					COUNT(Id) total
					FROM Payslip__c
					WHERE Status__c != null
					WITH USER_MODE
					GROUP BY Status__c
				]) {
				payslipStatus.add(new Map < String, Object > {
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