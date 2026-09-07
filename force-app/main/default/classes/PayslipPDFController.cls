public with sharing class PayslipPDFController {

    public Payslip__c payslip { get; private set; }
    public String employeeName { get; private set; }
    public String employeeCode { get; private set; }
    public String designation { get; private set; }
    public String employeeEmail { get; private set; }
    public String workLocation { get; private set; }
    public Decimal basicSalary { get; private set; }
    public Decimal bonus { get; private set; }
    public Decimal deductions { get; private set; }
    public Decimal grossSalary { get; private set; }
    public Decimal netSalary { get; private set; }
    public String payslipNumber { get; private set; }
    public String payMonth { get; private set; }
    public String payYear { get; private set; }
    public String payPeriod { get; private set; }
    public String paymentStatus { get; private set; }
    public String generatedDate { get; private set; }

    public PayslipPDFController(ApexPages.StandardController controller) {
        initializeDefaults();

        Id payslipId = (controller != null) ? controller.getId() : null;
        if (payslipId == null) {
            return;
        }

        List<Payslip__c> slips = [
            SELECT
                Id,
                Name,
                Employee__c,
                Employee__r.Name,
                Employee__r.Employee_Code__c,
                Employee__r.Designation__c,
                Employee__r.Official_Email__c,
                Employee__r.Personal_Email__c,
                Employee__r.Work_Location__c,
                Pay_Month__c,
                Pay_Year__c,
                Basic_Salary__c,
                Bonus__c,
                Deductions__c,
                Gross_Salary__c,
                Status__c,
                CreatedDate
            FROM Payslip__c
            WHERE Id = :payslipId
            WITH USER_MODE
            LIMIT 1
        ];

        if (slips.isEmpty()) {
            return;
        }
        payslip = slips[0];

        if (payslip.Employee__r != null) {
            employeeName = String.isNotBlank(payslip.Employee__r.Name) ? payslip.Employee__r.Name : 'N/A';
            employeeCode = String.isNotBlank(payslip.Employee__r.Employee_Code__c) ? payslip.Employee__r.Employee_Code__c : 'N/A';
            designation = String.isNotBlank(payslip.Employee__r.Designation__c) ? payslip.Employee__r.Designation__c : 'Associate';
            
            if (String.isNotBlank(payslip.Employee__r.Official_Email__c)) {
                employeeEmail = payslip.Employee__r.Official_Email__c;
            } else if (String.isNotBlank(payslip.Employee__r.Personal_Email__c)) {
                employeeEmail = payslip.Employee__r.Personal_Email__c;
            } else {
                employeeEmail = 'N/A';
            }

            workLocation = String.isNotBlank(payslip.Employee__r.Work_Location__c) ? payslip.Employee__r.Work_Location__c : 'Headquarters';
        }

        basicSalary = payslip.Basic_Salary__c != null ? payslip.Basic_Salary__c : 0;
        bonus = payslip.Bonus__c != null ? payslip.Bonus__c : 0;
        deductions = payslip.Deductions__c != null ? payslip.Deductions__c : 0;
        grossSalary = basicSalary + bonus;
        netSalary = grossSalary - deductions;
        payslipNumber = String.isNotBlank(payslip.Name) ? payslip.Name : 'N/A';
        payMonth = payslip.Pay_Month__c != null ? String.valueOf(payslip.Pay_Month__c) : 'N/A';
        payYear = payslip.Pay_Year__c != null ? String.valueOf(payslip.Pay_Year__c) : 'N/A';
        payPeriod = (payMonth != 'N/A' || payYear != 'N/A') ? (payMonth + ' ' + payYear) : 'N/A';
        paymentStatus = String.isNotBlank(payslip.Status__c) ? payslip.Status__c : 'Pending';
        generatedDate = payslip.CreatedDate != null ? payslip.CreatedDate.format('dd MMM yyyy') : Datetime.now().format('dd MMM yyyy');
    }

    private void initializeDefaults() {
        payslip = null;
        employeeName = 'N/A';
        employeeCode = 'N/A';
        designation = 'N/A';
        employeeEmail = 'N/A';
        workLocation = 'Headquarters';
        basicSalary = 0;
        bonus = 0;
        deductions = 0;
        grossSalary = 0;
        netSalary = 0;
        payslipNumber = 'N/A';
        payMonth = 'N/A';
        payYear = 'N/A';
        payPeriod = 'N/A';
        paymentStatus = 'Pending';
        generatedDate = Datetime.now().format('dd MMM yyyy');
    }

    public String formatCurrency(Decimal amount) {
        if (amount == null) {
            amount = 0;
        }
        return '₹' + amount.setScale(2).format();
    }

    public String getBasicSalaryFormatted() {
        return formatCurrency(basicSalary);
    }

    public String getBonusFormatted() {
        return formatCurrency(bonus);
    }

    public String getDeductionsFormatted() {
        return formatCurrency(deductions);
    }

    public String getGrossSalaryFormatted() {
        return formatCurrency(grossSalary);
    }

    public String getNetSalaryFormatted() {
        return formatCurrency(netSalary);
    }

    public String getStatusClass() {
        if (paymentStatus == 'Paid') {
            return 'status-paid';
        }
        if (paymentStatus == 'Approved' || paymentStatus == 'Generated') {
            return 'status-approved';
        }
        if (paymentStatus == 'Draft' || paymentStatus == 'Pending') {
            return 'status-pending';
        }
        return 'status-default';
    }
}