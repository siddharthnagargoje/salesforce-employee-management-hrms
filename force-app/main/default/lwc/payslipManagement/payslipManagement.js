import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getPayslips from '@salesforce/apex/EmployeeController.getPayslips';
import getEmployees from '@salesforce/apex/EmployeeController.getEmployees';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class PayslipManagement extends NavigationMixin(LightningElement) {
    @track payslipData = [];
    @track employeeOptions = [];
    @track selectedEmployeeId;

    @track isPayslipModalOpen = false;
    @track isLoading = true;

    wiredPayslipsResult;

    // Table columns including row actions row item mapping
    columns = [
        { label: 'Payslip Name', fieldName: 'Name', type: 'text', initialWidth: 150 },
        { label: 'Employee', fieldName: 'EmployeeName', type: 'text', cellAttributes: { class: 'font-weight-bold' } },
        { label: 'Pay Month', fieldName: 'Pay_Month__c', type: 'text' },
        { label: 'Pay Year', fieldName: 'Pay_Year__c', type: 'number' },
        { label: 'Basic Salary', fieldName: 'Basic_Salary__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
        { label: 'Bonus', fieldName: 'Bonus__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
        { label: 'Deductions', fieldName: 'Deductions__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
        { label: 'Net Salary', fieldName: 'Gross_Salary__c', type: 'currency', typeAttributes: { currencyCode: 'INR' }, cellAttributes: { class: 'text-success-accent font-weight-bold' } },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        {
            label: 'Statement',
            type: 'button',
            initialWidth: 160,
            typeAttributes: {
                label: 'Download PDF',
                name: 'download_pdf',
                title: 'Download Statement PDF',
                variant: 'border-filled',
                iconName: 'utility:download',
                iconPosition: 'left'
            }
        }
    ];

    @wire(getPayslips)
    wiredPayslips(result) {
        this.wiredPayslipsResult = result;
        const { error, data } = result;
        if (data) {
            this.payslipData = data.map(record => ({
                ...record,
                EmployeeName: record.Employee__r ? record.Employee__r.Name : 'Unassigned'
            }));
            this.error = undefined;
        } else if (error) {
            this.showToast('Error', 'Error loading payslip data: ' + error.body.message, 'error');
            this.payslipData = [];
        }
        this.isLoading = false;
    }

    @wire(getEmployees)
    wiredEmployees({ error, data }) {
        if (data) {
            this.employeeOptions = data.map(emp => ({
                label: emp.Name,
                value: emp.Id
            }));
        } else if (error) {
            this.showToast('Error', 'Error loading employee list: ' + error.body.message, 'error');
        }
    }

    // ---------- Summary stat getters ----------
    get totalPayslips() {
        return this.payslipData.length;
    }

    get paidCount() {
        return this.payslipData.filter(p => p.Status__c === 'Paid').length;
    }

    get pendingCount() {
        return this.payslipData.filter(p => p.Status__c !== 'Paid').length;
    }

    get formattedTotalDisbursed() {
        const total = this.payslipData
            .filter(p => p.Status__c === 'Paid')
            .reduce((sum, p) => sum + (p.Gross_Salary__c || 0), 0);
        return new Intl.NumberFormat('en-IN', {
            style: 'currency',
            currency: 'INR',
            maximumFractionDigits: 0
        }).format(total);
    }

    handleEmployeeChange(event) {
        this.selectedEmployeeId = event.detail.value;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const rowId = event.detail.row.Id;

        if (actionName === 'download_pdf') {
            this.downloadPayslipPDF(rowId);
        }
    }

    downloadPayslipPDF(payslipId) {
        this.showToast('Download Started', 'Preparing payslip PDF...', 'info');

        // Routes to the custom Visualforce PDF page we created
        window.open(`/apex/PayslipPDFPage?id=${payslipId}`, '_blank');
    }

    openPayslipModal() {
        if (!this.selectedEmployeeId) {
            this.showToast('Employee Required', 'Please select an employee before generating a payslip.', 'error');
            return;
        }
        this.isPayslipModalOpen = true;
    }

    closePayslipModal() {
        this.isPayslipModalOpen = false;
    }

    handlePayslipSubmit(event) {
        event.preventDefault();
        this.isLoading = true;
        const fields = event.detail.fields;

        const month = fields.Pay_Month__c ? fields.Pay_Month__c.trim() : 'NA';
        const year = fields.Pay_Year__c ? fields.Pay_Year__c : '2026';
        fields.Name = `PAY-${month.toUpperCase()}-${year}`;

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handlePayslipSuccess() {
        this.showToast('Success', 'Payslip saved successfully.', 'success');
        this.isPayslipModalOpen = false;

        refreshApex(this.wiredPayslipsResult)
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleFormError(event) {
        this.isLoading = false;
        this.showToast('Error', event.detail.detail || 'Unable to save payslip.', 'error');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}