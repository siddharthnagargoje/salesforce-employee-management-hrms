import { LightningElement, api } from 'lwc';

export default class Sidebar extends LightningElement {
    _activePage = 'dashboard';
    _isCollapsed = false;

    @api
    get activePage() {
        return this._activePage;
    }
    set activePage(val) {
        if (val) {
            this._activePage = val;
        }
    }

    @api
    get isCollapsed() {
        return this._isCollapsed;
    }
    set isCollapsed(val) {
        this._isCollapsed = Boolean(val);
    }

    get sidebarContainerClass() {
        return this._isCollapsed ? 'sidebar collapsed' : 'sidebar';
    }

    get collapseIconName() {
        return this._isCollapsed ? 'utility:chevronright' : 'utility:chevronleft';
    }

    get collapseButtonTitle() {
        return this._isCollapsed ? 'Expand navigation' : 'Collapse navigation';
    }

    handleToggleCollapse() {
        this._isCollapsed = !this._isCollapsed;
        this.dispatchEvent(
            new CustomEvent('togglesidebar', {
                detail: { isCollapsed: this._isCollapsed },
                bubbles: true,
                composed: true
            })
        );
    }

    handleNav(event) {
        const page = event.currentTarget.dataset.page;
        if (!page || this._activePage === page) return;

        this._activePage = page;

        this.dispatchEvent(
            new CustomEvent('navigate', {
                detail: page,
                bubbles: true,
                composed: true
            })
        );
    }

    handleKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleNav(event);
        }
    }

    get isDashboard() { return this._activePage === 'dashboard'; }
    get isEmployees() { return this._activePage === 'employees'; }
    get isAttendance() { return this._activePage === 'attendance'; }
    get isLeave() { return this._activePage === 'leave'; }
    get isPayslip() { return this._activePage === 'payslip'; }
    get isReports() { return this._activePage === 'reports'; }
    get isSettings() { return this._activePage === 'settings'; }

    get dashboardClass() { return this.getNavigationClass(this.isDashboard); }
    get employeesClass() { return this.getNavigationClass(this.isEmployees); }
    get attendanceClass() { return this.getNavigationClass(this.isAttendance); }
    get leaveClass() { return this.getNavigationClass(this.isLeave); }
    get payslipClass() { return this.getNavigationClass(this.isPayslip); }
    get reportsClass() { return this.getNavigationClass(this.isReports); }
    get settingsClass() { return this.getNavigationClass(this.isSettings); }

    get ariaCurrentDashboard() { return this.isDashboard ? 'page' : null; }
    get ariaCurrentEmployees() { return this.isEmployees ? 'page' : null; }
    get ariaCurrentAttendance() { return this.isAttendance ? 'page' : null; }
    get ariaCurrentLeave() { return this.isLeave ? 'page' : null; }
    get ariaCurrentPayslip() { return this.isPayslip ? 'page' : null; }
    get ariaCurrentReports() { return this.isReports ? 'page' : null; }
    get ariaCurrentSettings() { return this.isSettings ? 'page' : null; }

    getNavigationClass(isActive) {
        return isActive ? 'navigation-item active' : 'navigation-item';
    }
}