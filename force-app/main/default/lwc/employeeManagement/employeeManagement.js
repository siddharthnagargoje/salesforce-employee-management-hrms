import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { deleteRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import LightningConfirm from 'lightning/confirm';
import getEmployees from '@salesforce/apex/EmployeeController.getEmployees';
import updateEmployeeProfilePhoto from '@salesforce/apex/EmployeeController.updateEmployeeProfilePhoto';
import removeEmployeeProfilePhoto from '@salesforce/apex/EmployeeController.removeEmployeeProfilePhoto';

const PAGE_SIZE = 6;

export default class EmployeeManagement extends NavigationMixin(LightningElement) {
    @track employees = [];
    @track filteredEmployees = [];
    @track error;
    @track isLoading = true;
    @track isModalOpen = false;

    // --- Photo Modal State ---
    @track isPhotoModalOpen = false;
    photoUploadEmployeeId = '';
    photoUploadEmployeeName = '';
    photoUploadEmployeeCode = '';
    @track photoUploadCurrentUrl = '';
    photoUploadInitials = 'EE';
    isPhotoModalImgBroken = false;
    acceptedPhotoFormats = ['.png', '.jpg', '.jpeg', '.webp'];

    searchKey = '';
    searchTimeout;

    // --- Pagination state ---
    currentPage = 1;
    pageSize = PAGE_SIZE;

    @track photoUrlPreview = 'https://i.imgur.com/8Km9tLL.png';
    defaultAvatarPlaceholder = 'https://i.imgur.com/8Km9tLL.png';

    wiredEmployeesResult;

    @wire(getEmployees)
    wiredEmployees(result) {
        this.wiredEmployeesResult = result;
        const { error, data } = result;
        if (data) {
            this.employees = data;
            this.filterResults();
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.employees = [];
            this.filteredEmployees = [];
        }
        this.isLoading = false;
    }

    get totalPayroll() {
        if (!this.filteredEmployees || this.filteredEmployees.length === 0) {
            return '₹0';
        }
        const total = this.filteredEmployees.reduce((sum, emp) => {
            const salary = parseFloat(emp.Salary__c) || 0;
            return sum + salary;
        }, 0);
        return '₹' + total.toLocaleString('en-IN');
    }

    get totalEmployeesCount() {
        return this.filteredEmployees.length;
    }

    get hasRecords() {
        return this.filteredEmployees.length > 0;
    }

    handleSearchChange(event) {
        window.clearTimeout(this.searchTimeout);
        const rawValue = event.target.value;

        this.searchTimeout = setTimeout(() => {
            this.searchKey = rawValue.toLowerCase().trim();
            this.filterResults();
            this.currentPage = 1; // jump back to page 1 whenever the query changes
        }, 300);
    }

    filterResults() {
        if (!this.searchKey) {
            this.filteredEmployees = [...this.employees];
        } else {
            this.filteredEmployees = this.employees.filter(emp => {
                const name = emp.Name ? emp.Name.toLowerCase() : '';
                const code = emp.Employee_Code__c ? emp.Employee_Code__c.toLowerCase() : '';
                const title = emp.Designation__c ? emp.Designation__c.toLowerCase() : '';

                return name.includes(this.searchKey) ||
                       code.includes(this.searchKey) ||
                       title.includes(this.searchKey);
            });
        }
    }

    // ------------------------------------------------------------------
    // Pagination — 4 employees per page
    // ------------------------------------------------------------------

    get totalPages() {
        return Math.max(1, Math.ceil(this.filteredEmployees.length / this.pageSize));
    }

    get pagedEmployees() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this.filteredEmployees.slice(start, start + this.pageSize);
    }

    get showPagination() {
        return this.filteredEmployees.length > this.pageSize;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    get pageRangeStart() {
        return this.filteredEmployees.length === 0 ? 0 : (this.currentPage - 1) * this.pageSize + 1;
    }

    get pageRangeEnd() {
        return Math.min(this.currentPage * this.pageSize, this.filteredEmployees.length);
    }

    get pageNumbers() {
        const pages = [];
        for (let i = 1; i <= this.totalPages; i++) {
            pages.push({
                value: i,
                className: i === this.currentPage ? 'pagination-page pagination-page-active' : 'pagination-page'
            });
        }
        return pages;
    }

    handlePrevPage() {
        if (!this.isFirstPage) {
            this.currentPage -= 1;
        }
    }

    handleNextPage() {
        if (!this.isLastPage) {
            this.currentPage += 1;
        }
    }

    handleGoToPage(event) {
        const page = parseInt(event.currentTarget.dataset.page, 10);
        if (page && page !== this.currentPage) {
            this.currentPage = page;
        }
    }

    openEmployeeModal() {
        this.photoUrlPreview = this.defaultAvatarPlaceholder;
        this.isModalOpen = true;
    }

    closeEmployeeModal() {
        this.isModalOpen = false;
    }

    handlePhotoUrlChange(event) {
        const inputUrl = event.target.value;
        this.photoUrlPreview = inputUrl && inputUrl.trim() !== '' ? inputUrl : this.defaultAvatarPlaceholder;
    }

    handleImageError() {
        this.photoUrlPreview = this.defaultAvatarPlaceholder;
    }

    // --- FIX IMPLEMENTED HERE ---
    handleSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;

        // Combine inputs directly into standard Name field mapping
        const firstName = fields.First_Name__c ? fields.First_Name__c.trim() : '';
        const lastName = fields.Last_Name__c ? fields.Last_Name__c.trim() : '';
        fields.Name = `${firstName} ${lastName}`.trim();

        // Safe fallback parameter rule
        if (!fields.Name) {
            fields.Name = 'New Employee Record';
        }

        // Deliver payload structure to form engine
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Operation Confirmed',
                message: 'Employee record successfully added to ledger.',
                variant: 'success',
            })
        );

        this.isModalOpen = false;
        this.isLoading = true;
        this.currentPage = 1; // new record was added — show it from page 1

        refreshApex(this.wiredEmployeesResult)
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleError(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Data Exception Block',
                message: event.detail.detail || 'Field parameters failed engine constraints.',
                variant: 'error',
            })
        );
    }

    handleView(event) {
        const employeeId = event.detail;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: employeeId,
                objectApiName: 'Employee__c',
                actionName: 'view'
            }
        });
    }

    handleEdit(event) {
        const employeeId = event.detail;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: employeeId,
                objectApiName: 'Employee__c',
                actionName: 'edit'
            }
        });
    }

    async handleDelete(event) {
        const employeeId = event.detail;

        const confirmed = await LightningConfirm.open({
            message: 'Are you sure you want to permanently remove this employee profile record?',
            variant: 'headerless',
            label: 'Delete Confirmation'
        });

        if (confirmed) {
            this.isLoading = true;
            try {
                await deleteRecord(employeeId);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Deleted Successfully',
                        message: 'Employee profile was removed from Salesforce server.',
                        variant: 'success'
                    })
                );
                await refreshApex(this.wiredEmployeesResult);

                // if that was the last record on the last page, step back a page
                if (this.currentPage > this.totalPages) {
                    this.currentPage = this.totalPages;
                }
            } catch (err) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error Deleting Record',
                        message: err.body?.message || 'Verification constraints block processing.',
                        variant: 'error'
                    })
                );
            } finally {
                this.isLoading = false;
            }
        }
    }

    // ------------------------------------------------------------------
    // Profile Photo Management (Salesforce Files)
    // ------------------------------------------------------------------

    get hasPhotoUploadPreview() {
        return Boolean(this.photoUploadCurrentUrl && !this.isPhotoModalImgBroken);
    }

    handleOpenPhotoModal(event) {
        const detail = event.detail;
        this.photoUploadEmployeeId = detail.employeeId;
        this.photoUploadEmployeeName = detail.employeeName || 'Employee';
        this.photoUploadEmployeeCode = detail.employeeCode || '';
        this.photoUploadCurrentUrl = detail.profilePhoto || '';
        this.photoUploadInitials = detail.initials || 'EE';
        this.isPhotoModalImgBroken = false;
        this.isPhotoModalOpen = true;
    }

    closePhotoModal() {
        this.isPhotoModalOpen = false;
        this.photoUploadEmployeeId = '';
        this.photoUploadEmployeeName = '';
        this.photoUploadEmployeeCode = '';
        this.photoUploadCurrentUrl = '';
        this.isPhotoModalImgBroken = false;
    }

    handlePhotoModalImgError() {
        this.isPhotoModalImgBroken = true;
    }

    async handlePhotoUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (!uploadedFiles || uploadedFiles.length === 0) {
            return;
        }

        const documentId = uploadedFiles[0].documentId;
        this.isLoading = true;

        try {
            const newPhotoUrl = await updateEmployeeProfilePhoto({
                employeeId: this.photoUploadEmployeeId,
                contentDocumentId: documentId
            });

            this.photoUploadCurrentUrl = newPhotoUrl;
            this.isPhotoModalImgBroken = false;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Profile Photo Updated',
                    message: `Photo for ${this.photoUploadEmployeeName} has been saved as a Salesforce File.`,
                    variant: 'success'
                })
            );

            this.closePhotoModal();
            await refreshApex(this.wiredEmployeesResult);
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Photo Upload Error',
                    message: error.body?.message || error.message || 'Failed to update employee profile photo.',
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    async handleRemovePhoto() {
        const confirmed = await LightningConfirm.open({
            message: `Are you sure you want to remove the profile photo for ${this.photoUploadEmployeeName}? Initials will be displayed instead.`,
            variant: 'headerless',
            label: 'Remove Photo Confirmation'
        });

        if (confirmed) {
            this.isLoading = true;
            try {
                await removeEmployeeProfilePhoto({ employeeId: this.photoUploadEmployeeId });

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Photo Removed',
                        message: `Profile photo removed. Showing employee initials fallback.`,
                        variant: 'success'
                    })
                );

                this.closePhotoModal();
                await refreshApex(this.wiredEmployeesResult);
            } catch (error) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error Removing Photo',
                        message: error.body?.message || error.message || 'Failed to remove profile photo.',
                        variant: 'error'
                    })
                );
            } finally {
                this.isLoading = false;
            }
        }
    }
}