# HRMS (Human Resource Management System) - Project Guidelines

## Overview
This repository contains the Salesforce DX source code for the **HRMS (Human Resource Management System)** application. It provides modules for Employee Management, Leave Requests, Attendance Tracking, Performance Reviews, and Payroll processing built on Salesforce Platform (Apex, Lightning Web Components, Custom Objects, and Automations).

---

## Critical Directives & Constraints

- **No Git Usage**: Do not run `git` commands (e.g., `git init`, `git add`, `git commit`, `git push`, `git status`) or create git repositories unless explicitly requested by the user.
- **Salesforce Target Org**: The default target org alias for this project is `HrmsOrg`. Use `sf` CLI for org operations, deployments, and retrievals.
- **Source Format**: All Salesforce metadata follows the Salesforce DX source format located in `force-app/main/default/`.

---

## Architecture & Coding Standards

### 1. Apex Guidelines
- **Sharing Model**: Explicitly declare `with sharing` or `inherited sharing` on all Apex classes unless elevated system mode is strictly required and documented (`without sharing`).
- **Bulkification**: All Apex methods, triggers, and service layer classes must be fully bulkified to handle collections of up to 200 records without hitting governor limits.
- **Trigger Pattern**: 
  - One trigger per sObject.
  - Keep triggers logic-free; delegate execution to dedicated Trigger Handler classes (e.g., `EmployeeTriggerHandler`).
  - Support execution context methods (`beforeInsert`, `afterInsert`, `beforeUpdate`, `afterUpdate`, `beforeDelete`, `afterDelete`, `afterUndelete`).
- **Security & FLS**: Always enforce Object and Field Level Security (FLS) using `WITH USER_MODE`, `Security.stripInaccessible()`, or schema describe checks before DML and SOQL operations.
- **Code Review & Auditing (Quality Gate)**:
  - Automatically activate and strictly adhere to the [`apex-code-reviewer`](.agents/skills/apex-code-reviewer/SKILL.md) skill whenever reviewing, inspecting, or auditing Apex code in this project.
  - **Hard Rule — No Code Changes During Review**: The review agent MUST conduct all analysis first and produce the full report without making any file modifications. Modifying code, writing files, or running mutating commands during the review phase is strictly prohibited.
  - **Mandatory Checklist Output**: Every Apex code review MUST explicitly render the complete 30-point checklist from `.agents/skills/apex-code-reviewer/references/checklist.md` as a Markdown table (`| # | Check Item | Status (✅ PASS / ❌ FAIL / ⚪ N/A) | Notes |`) in the final review report. A review is incomplete without this rendered table.
  - **Explicit Approval Gate**: Once the complete report and proposed diffs are presented in table format, the agent MUST stop and ask the developer: *"Would you like me to proceed with implementing these recommended changes?"* ONLY if the developer explicitly responds with "yes" or grants approval may the agent proceed to modify code.
- **Unit Testing (Quality Gate)**:
  - Automatically activate and strictly adhere to the [`apex-test-craftsman`](.agents/skills/apex-test-craftsman/SKILL.md) skill whenever writing, optimizing, or reviewing Apex tests.
  - Maintain >90% code coverage across all Apex classes with production-grade logical assertions.
  - **Mandatory 5-Vector Test Enforcement**: Every test class MUST contain dedicated test methods covering all 5 vectors:
    1. `test*_Positive_*` (Happy Path validation with expected database state)
    2. `test*_Negative_*` (Edge, boundary, and null handling)
    3. `test*_Bulk200_*` (Must process >= 200 records in a single transaction without hitting 101 SOQL or 150 DML limits)
    4. `test*_Fault_*` (Verifying caught exceptions and rollback integrity)
    5. `test*_Security_RunAs_*` (Executing under `System.runAs` with a standard/restricted user)
  - A test class is INCOMPLETE and REJECTED if any of these 5 vectors is missing, regardless of the line coverage percentage achieved.
  - Use `@TestSetup` methods and dedicated `TestDataFactory` for test data creation.
  - Assert expected outcomes using modern Spring '23+ assertions (`Assert.areEqual()`, `Assert.isTrue()`, `Assert.isFalse()`, `Assert.isNull()`, `Assert.fail()`). Never use legacy `System.assert()`.
  - Zero `SeeAllData=true`.

### 2. Lightning Web Components (LWC)
- **Design System**: Use Salesforce Lightning Design System (SLDS) utility classes and components.
- **Reactivity & State**: Leverage `@wire` adapters for standard schema and Apex calls; handle cached vs imperative calls appropriately with `refreshApex`.
- **Error Handling**: Implement user-friendly error banners/toast notifications with standard `ShowToastEvent`.
- **Accessibility & Modularity**: Ensure components are accessible (ARIA labels, keyboard navigation) and structured into reusable subcomponents.

### 3. Data Model & HRMS Modules
- **Employee Management**: `Employee__c`, `Department__c`, `Designation__c`
- **Leave Management**: `Leave_Request__c`, `Leave_Type__c`, `Leave_Balance__c`
- **Attendance & Timesheets**: `Attendance__c`, `Timesheet__c`, `Timesheet_Entry__c`
- **Performance & Reviews**: `Performance_Review__c`, `Goal__c`, `Feedback__c`
- **Payroll & Compensation**: `Salary_Structure__c`, `Payroll_Record__c`

---

## Development Workflow
1. Create or modify metadata in `force-app/main/default/`.
2. Deploy to the connected org using `sf project deploy start`.
3. Verify functionality and run Apex tests using `sf apex run test`.
