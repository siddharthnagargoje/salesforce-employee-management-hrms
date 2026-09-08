import { LightningElement, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import ChartJS from '@salesforce/resourceUrl/ChartJS';
import getReportData from '@salesforce/apex/HRReportsController.getReportData';

// Theme Color Palettes
const PALETTE_PRIMARY = ['#2563eb', '#3b82f6', '#60a5fa', '#0ea5e9', '#06b6d4', '#14b8a6', '#10b981', '#f59e0b', '#8b5cf6', '#ec4899'];
const PALETTE_LEAVE = ['#0284c7', '#059669', '#f59e0b', '#dc2626', '#8b5cf6', '#d97706'];
const PALETTE_STATUS = ['#10b981', '#f59e0b', '#3b82f6', '#ef4444', '#64748b'];

export default class ReportsManagement extends LightningElement {

    chartJsLoaded = false;
    isLoading = true;
    errorMessage = '';

    @track reportData;
    charts = {};

    selectedCategory = 'all'; // 'all' | 'workforce' | 'attendance' | 'leave' | 'payroll'
    viewMode = 'charts'; // 'charts' | 'table'
    lastSyncTime = '';

    // ==========================================
    // LIFECYCLE HOOKS
    // ==========================================

    connectedCallback() {
        this.updateSyncTime();
        this.loadReportData();
    }

    renderedCallback() {
        if (this.chartJsLoaded) {
            return;
        }

        loadScript(this, ChartJS)
            .then(() => {
                this.chartJsLoaded = true;
                if (this.reportData && this.viewMode === 'charts') {
                    // Give DOM a microtask to ensure canvases are ready
                    window.requestAnimationFrame(() => {
                        this.renderCharts();
                    });
                }
            })
            .catch(error => {
                console.error('Chart.js loading error:', error);
                this.errorMessage = 'Unable to load Chart.js charting library.';
            });
    }

    updateSyncTime() {
        const now = new Date();
        this.lastSyncTime = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    }

    // ==========================================
    // DATA LOADING
    // ==========================================

    loadReportData() {
        this.isLoading = true;
        this.errorMessage = '';

        getReportData()
            .then(result => {
                this.reportData = result || {};
                this.isLoading = false;
                this.updateSyncTime();

                if (this.chartJsLoaded && this.viewMode === 'charts') {
                    window.requestAnimationFrame(() => {
                        this.renderCharts();
                    });
                }
            })
            .catch(error => {
                console.error('Report Data Error:', error);
                this.isLoading = false;
                this.errorMessage = this.getErrorMessage(error);
            });
    }

    // ==========================================
    // EXECUTIVE KPI COMPUTATIONS
    // ==========================================

    get kpiTotalEmployees() {
        if (!this.reportData?.designationData) {
            return 0;
        }
        return this.reportData.designationData.reduce((sum, item) => sum + Number(item.value || 0), 0);
    }

    get kpiDesignationsCount() {
        return this.reportData?.designationData ? this.reportData.designationData.length : 0;
    }

    get kpiActiveCount() {
        if (!this.reportData?.employeeStatus) {
            return 0;
        }
        const activeItem = this.reportData.employeeStatus.find(
            item => String(item.label).toLowerCase() === 'active'
        );
        return activeItem ? Number(activeItem.value) : this.kpiTotalEmployees;
    }

    get kpiActiveRate() {
        const total = this.kpiTotalEmployees;
        if (total === 0) {
            return '100%';
        }
        const pct = Math.round((this.kpiActiveCount / total) * 100);
        return `${pct}%`;
    }

    get kpiPresentCount() {
        if (!this.reportData?.attendanceStatus) {
            return 0;
        }
        const presentItem = this.reportData.attendanceStatus.find(
            item => String(item.label).toLowerCase() === 'present'
        );
        return presentItem ? Number(presentItem.value) : 0;
    }

    get kpiAttendanceRate() {
        if (!this.reportData?.attendanceStatus) {
            return '95%';
        }
        const total = this.reportData.attendanceStatus.reduce((sum, item) => sum + Number(item.value || 0), 0);
        if (total === 0) {
            return '100%';
        }
        const pct = Math.round((this.kpiPresentCount / total) * 100);
        return `${pct}%`;
    }

    get kpiTotalPayroll() {
        if (!this.reportData?.payrollData) {
            return 0;
        }
        return this.reportData.payrollData.reduce((sum, item) => sum + Number(item.value || 0), 0);
    }

    get kpiTotalPayrollFormatted() {
        const val = this.kpiTotalPayroll;
        if (val === 0) {
            return '₹0';
        }
        return '₹' + Number(val).toLocaleString('en-IN', { maximumFractionDigits: 0 });
    }

    // ==========================================
    // CATEGORY FILTER & VIEW SWITCHER GETTERS
    // ==========================================

    get isTabAllSelected() { return this.selectedCategory === 'all'; }
    get isTabWorkforceSelected() { return this.selectedCategory === 'workforce'; }
    get isTabAttendanceSelected() { return this.selectedCategory === 'attendance'; }
    get isTabLeaveSelected() { return this.selectedCategory === 'leave'; }
    get isTabPayrollSelected() { return this.selectedCategory === 'payroll'; }

    get tabAllClass() { return `tab-btn ${this.isTabAllSelected ? 'active' : ''}`; }
    get tabWorkforceClass() { return `tab-btn ${this.isTabWorkforceSelected ? 'active' : ''}`; }
    get tabAttendanceClass() { return `tab-btn ${this.isTabAttendanceSelected ? 'active' : ''}`; }
    get tabLeaveClass() { return `tab-btn ${this.isTabLeaveSelected ? 'active' : ''}`; }
    get tabPayrollClass() { return `tab-btn ${this.isTabPayrollSelected ? 'active' : ''}`; }

    get isChartsView() { return this.viewMode === 'charts'; }
    get chartViewBtnClass() { return `view-btn ${this.isChartsView ? 'active' : ''}`; }
    get tableViewBtnClass() { return `view-btn ${!this.isChartsView ? 'active' : ''}`; }

    get showDesignationChart() { return ['all', 'workforce'].includes(this.selectedCategory); }
    get showJoiningChart() { return ['all', 'workforce'].includes(this.selectedCategory); }
    get showStatusChart() { return ['all', 'workforce'].includes(this.selectedCategory); }
    get showAttendanceChart() { return ['all', 'attendance'].includes(this.selectedCategory); }
    get showWorkModeChart() { return ['all', 'attendance'].includes(this.selectedCategory); }
    get showRadarChart() { return ['all', 'attendance'].includes(this.selectedCategory); }
    get showLeaveTypesChart() { return ['all', 'leave'].includes(this.selectedCategory); }
    get showLeaveStatusChart() { return ['all', 'leave'].includes(this.selectedCategory); }
    get showPayrollChart() { return ['all', 'payroll'].includes(this.selectedCategory); }

    // ==========================================
    // DATA TABLE GETTERS (TABULAR VIEW)
    // ==========================================

    get tableDesignationData() {
        const data = this.reportData?.designationData || [];
        const total = this.kpiTotalEmployees || 1;
        return data.map(item => {
            const val = Number(item.value || 0);
            const pct = Math.round((val / total) * 100);
            return {
                label: item.label,
                value: val,
                percentage: pct,
                progressStyle: `width: ${pct}%;`
            };
        });
    }

    get tableAttendanceData() {
        const att = (this.reportData?.attendanceStatus || []).map(item => {
            const lbl = String(item.label).toLowerCase();
            let pill = 'status-pill ';
            if (lbl.includes('present')) pill += 'status-pill-present';
            else if (lbl.includes('absent')) pill += 'status-pill-absent';
            else pill += 'status-pill-halfday';
            return { label: item.label, value: item.value, pillClass: pill };
        });

        const modes = (this.reportData?.workModeData || []).map(item => {
            const lbl = String(item.label).toLowerCase();
            let pill = 'status-pill ';
            if (lbl.includes('office')) pill += 'status-pill-office';
            else if (lbl.includes('remote')) pill += 'status-pill-remote';
            else pill += 'status-pill-hybrid';
            return { label: `Work Mode: ${item.label}`, value: item.value, pillClass: pill };
        });

        return [...att, ...modes];
    }

    get tablePayrollData() {
        const data = this.reportData?.payrollData || [];
        return data.map((item, idx) => ({
            rank: idx + 1,
            label: item.label,
            formattedValue: '₹' + Number(item.value || 0).toLocaleString('en-IN', { maximumFractionDigits: 0 })
        }));
    }

    // ==========================================
    // TAB & VIEW ACTIONS
    // ==========================================

    handleCategorySelect(event) {
        const category = event.currentTarget.dataset.category;
        if (this.selectedCategory === category) {
            return;
        }

        this.selectedCategory = category;

        if (this.viewMode === 'charts') {
            window.requestAnimationFrame(() => {
                this.renderCharts();
            });
        }
    }

    handleSwitchToCharts() {
        if (this.viewMode === 'charts') {
            return;
        }
        this.viewMode = 'charts';
        window.requestAnimationFrame(() => {
            this.renderCharts();
        });
    }

    handleSwitchToTable() {
        this.viewMode = 'table';
        this.destroyCharts();
    }

    handleRefresh() {
        this.destroyCharts();
        this.loadReportData();

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Analytics Refreshed',
                message: 'All HRMS report metrics have been synchronized with Salesforce.',
                variant: 'success'
            })
        );
    }

    // ==========================================
    // EXPORT TO CSV
    // ==========================================

    handleExportCSV() {
        if (!this.reportData) {
            return;
        }

        let csv = 'HRMS 360 - Analytics and Reports Summary\n';
        csv += `Export Generated: ${new Date().toLocaleString()}\n\n`;

        // Section 1: Designations
        csv += '--- WORKFORCE BY DESIGNATION ---\n';
        csv += 'Designation,Headcount\n';
        (this.reportData.designationData || []).forEach(row => {
            csv += `"${row.label}",${row.value}\n`;
        });
        csv += '\n';

        // Section 2: Attendance
        csv += '--- ATTENDANCE & STATUS ---\n';
        csv += 'Status,Count\n';
        (this.reportData.attendanceStatus || []).forEach(row => {
            csv += `"${row.label}",${row.value}\n`;
        });
        csv += '\n';

        // Section 3: Leave Types
        csv += '--- LEAVE REQUESTS BY TYPE ---\n';
        csv += 'Leave Type,Count\n';
        (this.reportData.leaveTypeData || []).forEach(row => {
            csv += `"${row.label}",${row.value}\n`;
        });
        csv += '\n';

        // Section 4: Payroll
        csv += '--- TOP EMPLOYEE COMPENSATION ---\n';
        csv += 'Employee Name,Gross Salary (INR)\n';
        (this.reportData.payrollData || []).forEach(row => {
            csv += `"${row.label}",${row.value}\n`;
        });

        const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.setAttribute('href', url);
        link.setAttribute('download', `HRMS_360_Reports_${new Date().toISOString().slice(0, 10)}.csv`);
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Export Successful',
                message: 'Reports summary downloaded as CSV.',
                variant: 'success'
            })
        );
    }

    // ==========================================
    // CHART.JS RENDERING ENGINE
    // ==========================================

    renderCharts() {
        if (!this.reportData || !this.chartJsLoaded || this.viewMode !== 'charts') {
            return;
        }

        this.destroyCharts();

        if (this.showDesignationChart) this.createBarChart();
        if (this.showJoiningChart) this.createLineChart();
        if (this.showStatusChart) this.createDoughnutChart();
        if (this.showAttendanceChart) this.createMultiLineChart();
        if (this.showWorkModeChart) this.createBubbleChart();
        if (this.showRadarChart) this.createRadarChart();
        if (this.showLeaveTypesChart) this.createPieChart();
        if (this.showLeaveStatusChart) this.createScatterChart();
        if (this.showPayrollChart) this.createComboChart();
    }

    // 1. BAR CHART: Employees by Designation
    createBarChart() {
        const canvas = this.template.querySelector('.barChart');
        if (!canvas) return;

        const data = this.reportData.designationData || [];
        const labels = data.map(item => item.label);
        const values = data.map(item => item.value);

        this.charts.bar = new Chart(canvas, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Employees',
                    data: values,
                    backgroundColor: PALETTE_PRIMARY,
                    borderRadius: 6,
                    borderWidth: 0,
                    maxBarThickness: 42
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        backgroundColor: '#0f172a',
                        padding: 10,
                        cornerRadius: 6,
                        titleFont: { size: 12, weight: 'bold' },
                        bodyFont: { size: 12 }
                    }
                },
                scales: {
                    x: {
                        grid: { display: false },
                        ticks: { font: { size: 11 }, color: '#64748b' }
                    },
                    y: {
                        beginAtZero: true,
                        grid: { color: '#f1f5f9' },
                        ticks: { precision: 0, font: { size: 11 }, color: '#64748b' }
                    }
                }
            }
        });
    }

    // 2. LINE CHART: Employee Joining Trend
    createLineChart() {
        const canvas = this.template.querySelector('.lineChart');
        if (!canvas) return;

        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        const values = Array(12).fill(0);
        const data = this.reportData.joiningData || [];

        data.forEach(item => {
            const m = Number(item.month);
            if (m >= 1 && m <= 12) {
                values[m - 1] = Number(item.value);
            }
        });

        this.charts.line = new Chart(canvas, {
            type: 'line',
            data: {
                labels: months,
                datasets: [{
                    label: 'New Joinees',
                    data: values,
                    borderColor: '#2563eb',
                    backgroundColor: 'rgba(37, 99, 235, 0.08)',
                    borderWidth: 3,
                    fill: true,
                    tension: 0.38,
                    pointBackgroundColor: '#ffffff',
                    pointBorderColor: '#2563eb',
                    pointBorderWidth: 2,
                    pointRadius: 4,
                    pointHoverRadius: 6
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        backgroundColor: '#0f172a',
                        padding: 10,
                        cornerRadius: 6
                    }
                },
                scales: {
                    x: {
                        grid: { display: false },
                        ticks: { font: { size: 11 }, color: '#64748b' }
                    },
                    y: {
                        beginAtZero: true,
                        grid: { color: '#f1f5f9' },
                        ticks: { precision: 0, font: { size: 11 }, color: '#64748b' }
                    }
                }
            }
        });
    }

    // 3. DOUGHNUT CHART: Employee Status
    createDoughnutChart() {
        const canvas = this.template.querySelector('.doughnutChart');
        if (!canvas) return;

        const data = this.reportData.employeeStatus || [];
        const labels = data.map(item => item.label);
        const values = data.map(item => Number(item.value));

        this.charts.doughnut = new Chart(canvas, {
            type: 'doughnut',
            data: {
                labels: labels,
                datasets: [{
                    data: values,
                    backgroundColor: PALETTE_STATUS,
                    borderColor: '#ffffff',
                    borderWidth: 3
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '68%',
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            boxWidth: 12,
                            padding: 14,
                            font: { size: 11, weight: '600' },
                            color: '#475569'
                        }
                    },
                    tooltip: {
                        backgroundColor: '#0f172a',
                        padding: 10,
                        cornerRadius: 6
                    }
                }
            }
        });
    }

    // 4. MULTI-LINE / BAR: Attendance Status
    createMultiLineChart() {
        const canvas = this.template.querySelector('.multiLineChart');
        if (!canvas) return;

        const data = this.reportData.attendanceStatus || [];
        const labels = data.map(item => item.label);
        const values = data.map(item => Number(item.value));

        this.charts.multiLine = new Chart(canvas, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Attendance Records',
                    data: values,
                    backgroundColor: ['#10b981', '#ef4444', '#f59e0b', '#3b82f6'],
                    borderRadius: 6,
                    maxBarThickness: 46
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        backgroundColor: '#0f172a',
                        padding: 10,
                        cornerRadius: 6
                    }
                },
                scales: {
                    x: {
                        grid: { display: false },
                        ticks: { font: { size: 11 }, color: '#64748b' }
                    },
                    y: {
                        beginAtZero: true,
                        grid: { color: '#f1f5f9' },
                        ticks: { precision: 0, font: { size: 11 }, color: '#64748b' }
                    }
                }
            }
        });
    }

    // 5. BUBBLE CHART: Work Mode Analysis
    createBubbleChart() {
        const canvas = this.template.querySelector('.bubbleChart');
        if (!canvas) return;

        const data = this.reportData.workModeData || [];
        const colors = ['#2563eb', '#10b981', '#f59e0b', '#8b5cf6'];

        const datasets = data.map((item, index) => ({
            label: item.label,
            data: [{
                x: (index + 1) * 2,
                y: Number(item.value),
                r: Math.max(12, Math.min(28, Number(item.value) * 3))
            }],
            backgroundColor: colors[index % colors.length] + 'b3',
            borderColor: colors[index % colors.length],
            borderWidth: 2
        }));

        this.charts.bubble = new Chart(canvas, {
            type: 'bubble',
            data: { datasets: datasets },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            boxWidth: 12,
                            padding: 12,
                            font: { size: 11, weight: '600' },
                            color: '#475569'
                        }
                    },
                    tooltip: {
                        backgroundColor: '#0f172a',
                        padding: 10,
                        cornerRadius: 6,
                        callbacks: {
                            label: function(ctx) {
                                return `${ctx.dataset.label}: ${ctx.raw.y} employees`;
                            }
                        }
                    }
                },
                scales: {
                    x: {
                        display: false
                    },
                    y: {
                        beginAtZero: true,
                        grid: { color: '#f1f5f9' },
                        ticks: { precision: 0, font: { size: 11 }, color: '#64748b' }
                    }
                }
            }
        });
    }

    // 6. RADAR CHART: HR Operations Matrix
    createRadarChart() {
        const canvas = this.template.querySelector('.radarChart');
        if (!canvas) return;

        const employeeTotal = this.kpiTotalEmployees;
        const attendanceTotal = (this.reportData.attendanceStatus || []).reduce((s, i) => s + Number(i.value), 0);
        const leaveTotal = (this.reportData.leaveTypeData || []).reduce((s, i) => s + Number(i.value), 0);
        const desigCount = this.kpiDesignationsCount;
        const workModesCount = (this.reportData.workModeData || []).length;
        const payrollCount = (this.reportData.payrollData || []).length;

        this.charts.radar = new Chart(canvas, {
            type: 'radar',
            data: {
                labels: ['Workforce', 'Attendance', 'Leaves', 'Roles', 'Work Modes', 'Payroll'],
                datasets: [{
                    label: 'Operational Metrics',
                    data: [employeeTotal, attendanceTotal, leaveTotal, desigCount, workModesCount, payrollCount],
                    borderColor: '#0d9488',
                    backgroundColor: 'rgba(13, 148, 136, 0.16)',
                    borderWidth: 2.5,
                    pointBackgroundColor: '#ffffff',
                    pointBorderColor: '#0d9488',
                    pointBorderWidth: 2,
                    pointRadius: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        backgroundColor: '#0f172a',
                        padding: 10,
                        cornerRadius: 6
                    }
                },
                scales: {
                    r: {
                        beginAtZero: true,
                        angleLines: { color: '#e2e8f0' },
                        grid: { color: '#f1f5f9' },
                        pointLabels: { font: { size: 10.5, weight: '600' }, color: '#475569' }
                    }
                }
            }
        });
    }

    // 7. PIE CHART: Leave Types
    createPieChart() {
        const canvas = this.template.querySelector('.pieChart');
        if (!canvas) return;

        const data = this.reportData.leaveTypeData || [];
        const labels = data.map(item => item.label);
        const values = data.map(item => Number(item.value));

        this.charts.pie = new Chart(canvas, {
            type: 'pie',
            data: {
                labels: labels,
                datasets: [{
                    data: values,
                    backgroundColor: PALETTE_LEAVE,
                    borderColor: '#ffffff',
                    borderWidth: 2.5
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            boxWidth: 12,
                            padding: 12,
                            font: { size: 11, weight: '600' },
                            color: '#475569'
                        }
                    },
                    tooltip: {
                        backgroundColor: '#0f172a',
                        padding: 10,
                        cornerRadius: 6
                    }
                }
            }
        });
    }

    // 8. SCATTER CHART: Leave Request Volumes
    createScatterChart() {
        const canvas = this.template.querySelector('.scatterChart');
        if (!canvas) return;

        const data = this.reportData.leaveTypeData || [];
        const scatterData = data.map((item, index) => ({
            x: index + 1,
            y: Number(item.value)
        }));

        this.charts.scatter = new Chart(canvas, {
            type: 'scatter',
            data: {
                datasets: [{
                    label: 'Leave Requests',
                    data: scatterData,
                    backgroundColor: '#7c3aed',
                    borderColor: '#6d28d9',
                    pointRadius: 7,
                    pointHoverRadius: 9
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        backgroundColor: '#0f172a',
                        padding: 10,
                        cornerRadius: 6,
                        callbacks: {
                            label: function(ctx) {
                                const idx = ctx.raw.x - 1;
                                const name = data[idx] ? data[idx].label : 'Category';
                                return `${name}: ${ctx.raw.y} requests`;
                            }
                        }
                    }
                },
                scales: {
                    x: {
                        beginAtZero: true,
                        grid: { display: false },
                        ticks: {
                            stepSize: 1,
                            font: { size: 11 },
                            color: '#64748b',
                            callback: function(val) {
                                const idx = val - 1;
                                return data[idx] ? data[idx].label : '';
                            }
                        }
                    },
                    y: {
                        beginAtZero: true,
                        grid: { color: '#f1f5f9' },
                        ticks: { precision: 0, font: { size: 11 }, color: '#64748b' }
                    }
                }
            }
        });
    }

    // 9. COMBO CHART: Payroll Performance
    createComboChart() {
        const canvas = this.template.querySelector('.comboChart');
        if (!canvas) return;

        const data = this.reportData.payrollData || [];
        const labels = data.map(item => item.label);
        const values = data.map(item => Number(item.value));

        this.charts.combo = new Chart(canvas, {
            data: {
                labels: labels,
                datasets: [
                    {
                        type: 'bar',
                        label: 'Gross Salary',
                        data: values,
                        backgroundColor: 'rgba(16, 185, 129, 0.82)',
                        borderRadius: 6,
                        maxBarThickness: 40,
                        order: 2
                    },
                    {
                        type: 'line',
                        label: 'Salary Trend',
                        data: values,
                        borderColor: '#2563eb',
                        backgroundColor: 'transparent',
                        borderWidth: 2.5,
                        tension: 0.35,
                        pointBackgroundColor: '#ffffff',
                        pointBorderColor: '#2563eb',
                        pointBorderWidth: 2,
                        pointRadius: 4,
                        order: 1
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            boxWidth: 12,
                            padding: 12,
                            font: { size: 11, weight: '600' },
                            color: '#475569'
                        }
                    },
                    tooltip: {
                        backgroundColor: '#0f172a',
                        padding: 10,
                        cornerRadius: 6,
                        callbacks: {
                            label: function(ctx) {
                                return `${ctx.dataset.label}: ₹${Number(ctx.raw).toLocaleString('en-IN')}`;
                            }
                        }
                    }
                },
                scales: {
                    x: {
                        grid: { display: false },
                        ticks: { font: { size: 11 }, color: '#64748b' }
                    },
                    y: {
                        beginAtZero: true,
                        grid: { color: '#f1f5f9' },
                        ticks: {
                            font: { size: 11 },
                            color: '#64748b',
                            callback: function(value) {
                                return '₹' + Number(value).toLocaleString('en-IN');
                            }
                        }
                    }
                }
            }
        });
    }

    // ==========================================
    // CLEANUP & HELPERS
    // ==========================================

    destroyCharts() {
        Object.keys(this.charts).forEach(key => {
            if (this.charts[key]) {
                try {
                    this.charts[key].destroy();
                } catch (e) {
                    console.warn('Error destroying chart:', e);
                }
                this.charts[key] = null;
            }
        });
        this.charts = {};
    }

    getErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'Unable to load report data from Salesforce.';
    }
}