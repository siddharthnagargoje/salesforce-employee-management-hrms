import { LightningElement, wire, track } from "lwc";
import getAttendanceList from "@salesforce/apex/EmployeeController.getAttendanceList";
import saveAttendance from "@salesforce/apex/EmployeeController.saveAttendance";
import deleteAttendance from "@salesforce/apex/EmployeeController.deleteAttendance";
import getEmployees from "@salesforce/apex/EmployeeController.getEmployees";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";

export default class AttendanceManagement extends LightningElement {
    @track attendanceList = [];
    @track employeeOptions = [];
    @track isLoading = false;
    @track showModal = false;
    wiredAttendanceResult;
    currentPage = 1;
    pageSize = 10;
    selectedEmployee = "";
    attendanceDate = "";
    checkInTime = "";
    checkOutTime = "";
    status = "";
    workMode = "";
    remarks = "";
    editingRecordId = null;
    currentTimeLabel = "";

    /* =====================================================
       OPTIONS
       ===================================================== */

    statusOptions = [
        {
            label: "Present",
            value: "Present",
        },
        {
            label: "Absent",
            value: "Absent",
        },
    ];

    workModeOptions = [
        {
            label: "Office",
            value: "Office",
        },
        {
            label: "Remote",
            value: "Remote",
        },
        {
            label: "Hybrid",
            value: "Hybrid",
        },
    ];

    /* =====================================================
       WIRE EMPLOYEES
       ===================================================== */

    @wire(getEmployees)
    wiredEmployees({ data, error }) {
        if (data) {
            this.employeeOptions = data.map((employee) => {
                const first = employee.First_Name__c || "";

                const last = employee.Last_Name__c || "";

                const fullName = `${first} ${last}`.trim() || employee.Name;

                return {
                    label: fullName,
                    value: employee.Id,
                };
            });
        } else if (error) {
            console.error("Employee loading error:", error);
        }
    }

    /* =====================================================
       WIRE ATTENDANCE
       ===================================================== */

    @wire(getAttendanceList)
    wiredAttendance(result) {
        this.wiredAttendanceResult = result;

        if (result.data) {
            this.attendanceList = result.data.map((row) => {
                let employeeName = "Not Assigned";

                /*
                 * Employee relationship returned by Apex:
                 *
                 * Employee__r.Name
                 * Employee__r.First_Name__c
                 * Employee__r.Last_Name__c
                 */

                if (row.Employee__r) {
                    employeeName = this.buildFullName(
                        row.Employee__r.First_Name__c,
                        row.Employee__r.Last_Name__c,
                        row.Employee__r.Name
                    );
                } else if (row.Employee__c) {
                    employeeName = `ID: ${row.Employee__c}`;
                }

                const employeeInitials = this.getEmployeeInitials(employeeName);

                let statusClass = "status-badge pending";

                if (row.Status__c === "Present") {
                    statusClass = "status-badge approved";
                } else if (row.Status__c === "Absent" || row.Status__c === "Leave") {
                    statusClass = "status-badge cancelled";
                }

                return {
                    ...row,

                    employeeName,

                    employeeInitials,

                    checkInDisplay: row.Check_In__c ? this.formatDateTime(row.Check_In__c) : "-",

                    checkOutDisplay: row.Check_Out__c ? this.formatDateTime(row.Check_Out__c) : "-",

                    breakDisplay: "-",

                    statusClass,
                };
            });
        } else if (result.error) {
            console.error("Attendance loading error:", result.error);

            this.showToast("Error", result.error?.body?.message || "Unable to load attendance records.", "error");
        }
    }

    /* =====================================================
       BUILD EMPLOYEE NAME
       ===================================================== */

    buildFullName(firstName, lastName, fallbackName) {
        const first = firstName ? firstName.trim() : "";

        const last = lastName ? lastName.trim() : "";

        const fullName = `${first} ${last}`.trim();

        return fullName || fallbackName || "Unnamed Employee";
    }

    /* =====================================================
       EMPLOYEE INITIALS
       ===================================================== */

    getEmployeeInitials(employeeName) {
        if (!employeeName || employeeName === "Not Assigned") {
            return "NA";
        }

        const parts = employeeName.trim().split(/\s+/).filter(Boolean);

        if (parts.length === 1) {
            return parts[0].substring(0, 2).toUpperCase();
        }

        return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
    }

    /* =====================================================
       DISPLAY LIST
       ===================================================== */

    get attendanceListDisplay() {
        const start = (this.currentPage - 1) * this.pageSize;

        return this.attendanceList.slice(start, start + this.pageSize).map((row, index) => {
            return {
                ...row,

                sNo: start + index + 1,
            };
        });
    }

    get hasAttendanceRecords() {
        return this.attendanceListDisplay.length > 0;
    }

    /* =====================================================
       KPI
       ===================================================== */

    get totalRecords() {
        return this.attendanceList.length;
    }

    get presentCount() {
        return this.attendanceList.filter((row) => row.Status__c === "Present").length;
    }

    get totalWorkingHours() {
        const total = this.attendanceList.reduce((sum, row) => sum + (Number(row.Total_Hours__c) || 0), 0);

        return total.toFixed(2);
    }

    get totalOvertimeHours() {
        const total = this.attendanceList.reduce((sum, row) => sum + (Number(row.Overtime_Hours__c) || 0), 0);

        return total.toFixed(2);
    }

    /* =====================================================
       FILTER HANDLERS
       ===================================================== */

    handleEmployeeChange(event) {
        this.selectedEmployee = event.detail.value;

        this.currentPage = 1;
    }

    handleDateChange(event) {
        this.attendanceDate = event.detail.value;

        this.currentPage = 1;
    }

    handleStatusChange(event) {
        this.status = event.detail.value;
        this.currentPage = 1;
    }

    handleWorkModeChange(event) {
        this.workMode = event.detail.value;
        this.currentPage = 1;
    }

    handleResetFilters() {
        this.selectedEmployee = "";
        this.attendanceDate = "";
        this.status = "";
        this.workMode = "";
        this.currentPage = 1;
    }

    /* =====================================================
       MODAL
       ===================================================== */

    get modalTitle() {
        return this.editingRecordId ? "Edit Attendance" : "Add Attendance";
    }

    openAddModal() {
        this.editingRecordId = null;
        this.selectedEmployee = "";
        this.attendanceDate = new Date().toISOString().split("T")[0];
        this.checkInTime = "";
        this.checkOutTime = "";
        this.status = "Present";
        this.workMode = "Office";
        this.remarks = "";
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
    }

    /* =====================================================
       FORM HANDLERS
       ===================================================== */

    handleCheckInChange(event) {
        this.checkInTime = event.detail.value;
    }

    handleCheckOutChange(event) {
        this.checkOutTime = event.detail.value;
    }

    handleRemarksChange(event) {
        this.remarks = event.detail.value;
    }

    /* =====================================================
       SAVE
       ===================================================== */

    async handleSave() {
        if (!this.selectedEmployee) {
            this.showToast("Validation", "Please select an employee.", "warning");

            return;
        }

        if (!this.attendanceDate) {
            this.showToast("Validation", "Please select an attendance date.", "warning");

            return;
        }

        this.isLoading = true;

        try {
            await saveAttendance({
                attendanceId: this.editingRecordId ? this.editingRecordId : null,
                employeeId: this.selectedEmployee,
                attendanceDate: this.attendanceDate,
                checkIn: this.checkInTime ? this.checkInTime : null,
                checkOut: this.checkOutTime ? this.checkOutTime : null,
                status: this.status,
                workMode: this.workMode,
                remarks: this.remarks,
            });

            this.showToast("Success", "Attendance saved successfully.", "success");
            this.showModal = false;

            await refreshApex(this.wiredAttendanceResult);
        } catch (error) {
            this.showToast("Error", error?.body?.message || "Unable to save attendance.", "error");
        } finally {
            this.isLoading = false;
        }
    }

    /* =====================================================
       ROW ACTION
       ===================================================== */

    handleTableRowAction(event) {
        const action = event.currentTarget.dataset.action;
        const recordId = event.currentTarget.dataset.id;
        const record = this.attendanceList.find((row) => row.Id === recordId);

        if (!record) {
            return;
        }

        if (action === "edit") {
            this.editAttendance(record);
        } else if (action === "delete") {
            this.deleteAttendanceRecord(recordId);
        }
    }

    editAttendance(record) {
        this.editingRecordId = record.Id;
        this.selectedEmployee = record.Employee__c;
        this.attendanceDate = record.Attendance_Date__c;
        this.checkInTime = record.Check_In__c || "";
        this.checkOutTime = record.Check_Out__c || "";
        this.status = record.Status__c || "";
        this.workMode = record.Work_Mode__c || "";
        this.remarks = record.Remarks__c || "";
        this.showModal = true;
    }

    /* =====================================================
       DELETE
       ===================================================== */

    async deleteAttendanceRecord(attendanceId) {
        const confirmed = window.confirm("Are you sure you want to delete this attendance record?");

        if (!confirmed) {
            return;
        }

        this.isLoading = true;

        try {
            await deleteAttendance({
                attendanceId,
            });

            this.showToast("Success", "Attendance deleted successfully.", "success");

            await refreshApex(this.wiredAttendanceResult);
        } catch (error) {
            this.showToast("Error", error?.body?.message || "Unable to delete attendance.", "error");
        } finally {
            this.isLoading = false;
        }
    }

    /* =====================================================
       DATE / TIME
       ===================================================== */

    formatDateTime(value) {
        if (!value) {
            return "-";
        }

        try {
            return new Intl.DateTimeFormat("en-IN", {
                dateStyle: "short",
                timeStyle: "short",
            }).format(new Date(value));
        } catch (error) {
            return value;
        }
    }

    /* =====================================================
       TOAST
       ===================================================== */

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,
            })
        );
    }
}