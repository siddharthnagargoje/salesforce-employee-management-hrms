import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getPayslips from '@salesforce/apex/PayrollController.getPayslips';
import sendPayslipEmail from '@salesforce/apex/PayrollController.sendPayslipEmail';
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

    // Table columns including PDF and Email dispatch row actions
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
            initialWidth: 150,
            typeAttributes: {
                label: 'PDF',
                name: 'download_pdf',
                title: 'Download Statement PDF',
                variant: 'border-filled',
                iconName: 'utility:download',
                iconPosition: 'left'
            }
        },
        {
            label: 'Dispatch',
            type: 'button',
            initialWidth: 150,
            typeAttributes: {
                label: 'Email PDF',
                name: 'email_pdf',
                title: 'Send Payslip PDF directly to Employee Email',
                variant: 'neutral',
                iconName: 'utility:email',
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
            this.showToast('Error', 'Error loading payslip data: ' + (error.body?.message || error.message), 'error');
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
            this.showToast('Error', 'Error loading employee list: ' + (error.body?.message || error.message), 'error');
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
        } else if (actionName === 'email_pdf') {
            this.handleEmailPayslip(rowId);
        }
    }

    downloadPayslipPDF(payslipId) {
        this.showToast('Download Started', 'Preparing payslip PDF statement...', 'info');
        window.open(`/apex/PayslipPDFPage?id=${payslipId}`, '_blank');
    }

    async handleEmailPayslip(payslipId) {
        this.isLoading = true;
        this.showToast('Dispatching', 'Sending payslip PDF to employee...', 'info');
        try {
            const result = await sendPayslipEmail({ payslipId: payslipId, forceResend: true });
            if (result.isSuccess) {
                this.showToast('Success', `Payslip emailed successfully to ${result.recipientEmail}`, 'success');
            } else {
                this.showToast('Notice', result.message, 'warning');
            }
            await refreshApex(this.wiredPayslipsResult);
        } catch (error) {
            this.showToast('Error', 'Failed to email payslip: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isLoading = false;
        }
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