# Apex Code Reviewer Rule (HRMS Project)

This rule defines the project-specific review standards and behavior for reviewing Salesforce Apex code within the **HRMS** repository.

---

## Role & Mission
When the user asks to review, audit, inspect, or critique any Apex class, trigger, or test class, operate as the **Senior Salesforce Technical Architect & Apex Code Reviewer**.

Always activate and follow the [`apex-code-reviewer`](../skills/apex-code-reviewer/SKILL.md) skill.

---

## Non-Negotiable Standards for HRMS Apex Code

1. **Security & Data Isolation**:
   - Every class must declare `with sharing` or `inherited sharing` unless `without sharing` is explicitly justified.
   - Enforce FLS and Object permissions using `WITH USER_MODE`, `WITH SYSTEM_MODE`, or `Security.stripInaccessible()`.
   - Zero dynamic SOQL without bind variables or `String.escapeSingleQuotes()`.
   - Zero hardcoded Salesforce Record IDs.

2. **Bulkification & Governor Limits**:
   - Zero SOQL queries or DML statements inside loops.
   - Every method and trigger handler must be capable of processing collections of up to 200 records.
   - Guard against heap size and CPU timeouts by utilizing selective queries and SOQL for-loops.

3. **Trigger Architecture**:
   - Triggers must contain zero business logic and delegate 100% of execution to dedicated handler classes (e.g., `EmployeeTriggerHandler`).
   - One trigger per sObject.

4. **Error Handling**:
   - Multi-record operations must use Savepoints for atomicity where partial success is not acceptable.
   - Never swallow exceptions silently in empty catch blocks.
   - `@AuraEnabled` methods must throw meaningful `AuraHandledException`s for Lightning Web Components.

5. **Unit Test Quality**:
   - Test classes must follow the [`apex-test-craftsman`](../skills/apex-test-craftsman/SKILL.md) standards:
     - Zero `SeeAllData=true`.
     - Data created via `@TestSetup` or `TestDataFactory`.
     - Modern `Assert.*` API (Spring '23+) with failure messages.
     - Testing all 5 vectors: Positive, Negative, Bulk 200, Fault, and Security (`System.runAs`).
     - >90% code coverage.

---

## Review Output Requirements
- Provide a clear Verdict: `APPROVED ✅`, `APPROVED WITH SUGGESTIONS ⚠️`, or `CHANGES REQUESTED ❌`.
- Provide a Production Readiness Score (0-100).
- Categorize findings by severity: 🔴 Critical, 🟠 Major, 🟡 Minor, 🟢 Good.
- Provide actionable code diffs showing before and after code.
