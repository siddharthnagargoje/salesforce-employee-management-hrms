import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class EmployeeModal extends LightningElement {

    handleSubmit(event) {
        event.preventDefault();       
        const fields = event.detail.fields;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess(event) {
        const evt = new ShowToastEvent({
            title: 'Success!',
            message: 'Employee record saved successfully.',
            variant: 'success',
        });
        this.dispatchEvent(evt);
        // Notice the 'true' parameter passing out to the parent component
        this.dispatchEvent(new CustomEvent('closemodal', { detail: true }));
    }

    handleError(event) {
        const evt = new ShowToastEvent({
            title: 'Error Saving Record',
            message: event.detail.detail || 'Please check field validation properties.',
            variant: 'error',
        });
        this.dispatchEvent(evt);
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('closemodal', { detail: false }));
    }
}