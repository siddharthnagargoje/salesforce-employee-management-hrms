import { LightningElement, api } from 'lwc';

export default class EmployeeCard extends LightningElement {
    @api employee;

    isImageBroken = false;

    get fullName() {
        const firstName = this.employee?.First_Name__c || '';
        const lastName = this.employee?.Last_Name__c || '';

        return `${firstName} ${lastName}`.trim() || 'Unnamed Employee';
    }

    get hasValidPhoto() {
        return Boolean(
            this.employee?.Profile_Photo__c &&
            !this.isImageBroken
        );
    }

    get userInitials() {
        const firstInitial = this.employee?.First_Name__c
            ? this.employee.First_Name__c.charAt(0)
            : '';

        const lastInitial = this.employee?.Last_Name__c
            ? this.employee.Last_Name__c.charAt(0)
            : '';

        return (
            `${firstInitial}${lastInitial}`.toUpperCase() || 'EE'
        );
    }

    get statusLabel() {
        return this.employee?.Status__c || 'Unknown';
    }

    get statusClass() {
        const status = this.employee?.Status__c
            ? this.employee.Status__c.toLowerCase()
            : '';

        if (status === 'active') {
            return 'status-badge status-active';
        }

        if (
            status === 'on leave' ||
            status === 'leave' ||
            status === 'pending'
        ) {
            return 'status-badge status-warning';
        }

        if (
            status === 'inactive' ||
            status === 'terminated'
        ) {
            return 'status-badge status-inactive';
        }

        return 'status-badge status-default';
    }

    get formattedSalary() {
        const salary = Number(this.employee?.Salary__c || 0);

        return `₹${salary.toLocaleString('en-IN')}`;
    }

    get formattedJoiningDate() {
        const joiningDate = this.employee?.Joining_Date__c;

        if (!joiningDate) {
            return 'Not available';
        }

        const date = new Date(joiningDate);

        if (Number.isNaN(date.getTime())) {
            return joiningDate;
        }

        return new Intl.DateTimeFormat('en-IN', {
            day: '2-digit',
            month: 'short',
            year: 'numeric'
        }).format(date);
    }

    handleImageError() {
        this.isImageBroken = true;
    }

    handleUploadPhoto() {
        this.dispatchEvent(
            new CustomEvent('uploadphoto', {
                detail: {
                    employeeId: this.employee?.Id,
                    employeeName: this.fullName,
                    employeeCode: this.employee?.Employee_Code__c,
                    profilePhoto: this.employee?.Profile_Photo__c,
                    initials: this.userInitials
                },
                bubbles: true,
                composed: true
            })
        );
    }

    handleAvatarKeyDown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleUploadPhoto();
        }
    }

    viewEmployee() {
        this.dispatchEvent(
            new CustomEvent('view', {
                detail: this.employee.Id
            })
        );
    }

    editEmployee() {
        this.dispatchEvent(
            new CustomEvent('edit', {
                detail: this.employee.Id
            })
        );
    }

    deleteEmployee() {
        this.dispatchEvent(
            new CustomEvent('delete', {
                detail: this.employee.Id
            })
        );
    }
}