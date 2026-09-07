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
- **Code Review & Auditing**: Automatically activate and adhere to the [`apex-code-reviewer`](.agents/skills/apex-code-reviewer/SKILL.md) skill whenever reviewing, inspecting, or auditing Apex code in this project.
- **Unit Testing**:
  - Automatically activate and adhere to the [`apex-test-craftsman`](.agents/skills/apex-test-craftsman/SKILL.md) skill whenever writing, optimizing, or reviewing Apex tests.
  - Maintain >90% code coverage across all Apex classes with production-grade logical assertions.
  - Test all 5 vectors: Positive (Happy Path), Negative (Edge/Null), Bulk (200 records), Fault/Exception, and Security/FLS (`System.runAs`).
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
