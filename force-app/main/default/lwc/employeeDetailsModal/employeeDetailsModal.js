import { LightningElement } from 'lwc';
import saveEmployee from '@salesforce/apex/EmployeeController.saveEmployee';

export default class EmployeeDetailsModal extends LightningElement {
    firstName;
    lastName;
    email;
    mobile;
    designation;
    salary;

    handleFirstName(e) { this.firstName = e.target.value; }
    handleLastName(e) { this.lastName = e.target.value; }
    handleEmail(e) { this.email = e.target.value; }
    handleMobile(e) { this.mobile = e.target.value; }
    handleDesignation(e) { this.designation = e.target.value; }
    handleSalary(e) { this.salary = e.target.value; }

    async saveEmployee() {
        try {
            const emp = {
                First_Name__c: this.firstName,
                Last_Name__c: this.lastName,
                Personal_Email__c: this.email,
                Mobile__c: this.mobile,
                Designation__c: this.designation,
                Salary__c: this.salary
            };
            await saveEmployee({ emp });
            this.dispatchEvent(new CustomEvent('close'));
        } catch (error) {
            console.error('Error saving employee', error);
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}