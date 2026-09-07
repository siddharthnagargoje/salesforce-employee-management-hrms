---
name: apex-test-craftsman
description: >-
  Expert system for generating production-ready, enterprise-standard Apex test classes
  with rigorous code analysis, bulkification, boundary condition testing, mock frameworks,
  modern assertions, and >90% code coverage. Use this skill whenever the user asks to write,
  generate, improve, optimize, or fix Apex test classes or unit tests for any Apex class,
  trigger, batch, queueable, or invocable method.
---

# Apex Test Craftsman: Production-Grade Test Engineering

This skill defines the definitive procedure for engineering enterprise-grade, production-ready Salesforce Apex test classes. It ensures that generated tests are not merely hitting code coverage lines, but rigorously validating business logic, guarding against governor limits, asserting bulk operations, and adhering to modern Salesforce architectural best practices.

---

## The 4-Phase Test Engineering Workflow

When tasked with writing or optimizing an Apex test class, execute these four phases systematically:

```
┌─────────────────────────┐     ┌─────────────────────────┐
│ Phase 1: Code Analysis  │ ──> │ Phase 2: Test Matrix    │
│ Class topology & logic  │     │ Positive/Negative/Bulk  │
└─────────────────────────┘     └─────────────────────────┘
             │                               │
             ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│ Phase 3: Craft Test     │ ──> │ Phase 4: Deploy & Verify│
│ @TestSetup, Assertions  │     │ sf apex run test        │
└─────────────────────────┘     └─────────────────────────┘
```

---

## Phase 1: Deep Code & Complexity Analysis

Before writing a single line of test code, inspect the target Apex class and construct an analysis profile:

1. **Class Signature & Sharing**:
   - Sharing model: `with sharing`, `without sharing`, or `inherited sharing`.
   - Modifiers: `virtual`, `abstract`, `public`, `global`.
2. **Execution Context**:
   - Synchronous Controller (`@AuraEnabled`, Visualforce `ApexPages.StandardController`).
   - Invocable Action (`@InvocableMethod` for Salesforce Flow).
   - Asynchronous Apex (`Database.Batchable`, `Queueable`, `Schedulable`).
   - Database Trigger / Trigger Handler.
   - REST / SOAP Web Service (`@RestResource`, `@HttpGet`, `@HttpPost`).
3. **Database Operations & Governor Limits**:
   - SOQL queries (identify filter criteria, null-handling, aggregate expressions).
   - DML operations (`insert`, `update`, `delete`, `upsert`, `Database.insert(..., false)`).
   - Check if operations handle bulk collections (up to 200 records).
4. **Branching & Cyclomatic Complexity**:
   - Identify every conditional branch (`if`, `else if`, `else`, `switch on`, ternary operators).
   - Trace exception handling (`try / catch / finally`, custom exceptions, `AuraHandledException`).
5. **External Dependencies**:
   - HTTP Callouts (requires `HttpCalloutMock`).
   - Email dispatch (`Messaging.SingleEmailMessage`).
   - Platform Events / Change Data Capture.

---

## Phase 2: The Comprehensive Test Matrix

Design a structured test matrix covering five mandatory vectors:

| Vector | Purpose | Target Scenario |
| :--- | :--- | :--- |
| **1. Positive (Happy Path)** | Valid inputs produce expected database state and return values. | Standard valid arguments, expected status transitions, correct calculations. |
| **2. Negative & Edge** | Invalid inputs, null values, or missing relationships are handled gracefully without unhandled exceptions. | Passing `null`, empty lists, non-existent Record IDs, zero/negative quantities. |
| **3. Bulk Processing** | Ensures operations handle collections of 200 records without hitting governor limits (101 SOQL, 150 DML). | Bulk lists created in `@TestSetup` or method runtime processed in single invocation. |
| **4. Fault & Exception** | Verifies that `catch` blocks, rollback savepoints, and error logs trigger appropriately. | Induce DML exceptions (missing required fields) and assert error handling. |
| **5. Security & Context** | Validates CRUD/FLS compliance and user permissions. | `System.runAs(testUser)` to test role-based access or permission sets. |

---

## Phase 3: Test Implementation Standards

All generated test classes MUST strictly adhere to the following architecture:

### 1. Class Header & Annotations
```apex
/**
 * @description Comprehensive unit test suite for [TargetClassName]
 * @see [TargetClassName]
 */
@IsTest(IsParallel=true)
private class [TargetClassName]Test {
    // Test implementation
}
```
> [!NOTE]
> Use `@IsTest(IsParallel=true)` by default to speed up test execution. Remove `IsParallel=true` only if the test interacts with objects that do not support parallel execution (e.g., `User`, `Organization`, or custom settings with parallel lock contention).

### 2. Isolation & Zero `SeeAllData`
- **NEVER** use `(SeeAllData=true)`. Tests must run in full database isolation.
- Use `@TestSetup static void makeData()` to create shared records. `@TestSetup` records are rolled back after each test method, drastically reducing CPU time and governor limits.
- Reuse `TestDataFactory` for generating standard objects (`Employee__c`, `Department__c`, `Attendance__c`, etc.).

### 3. Modern Assertions (`Assert` Class)
Always use modern `Assert` methods (Salesforce Spring '23+). **Never use legacy `System.assert()` or `System.assertEquals()`**. Every assertion MUST include a descriptive failure message:

```apex
// Correct (Modern Assert Class):
Assert.areEqual(expectedValue, actualValue, 'Gross salary calculation mismatch for senior developer');
Assert.areNotEqual(unexpectedValue, actualValue, 'Status should have progressed past Draft');
Assert.isTrue(condition, 'Employee record should be flagged as active');
Assert.isFalse(condition, 'Email Sent flag should remain false on validation error');
Assert.isNull(result, 'Result should be null when invalid ID is supplied');
Assert.isNotNull(result, 'Payslip list must not be null');
Assert.fail('Execution should have thrown an AuraHandledException');
```

### 4. Method Naming & Structure (Arrange-Act-Assert)
Adopt the standard naming convention: `test<MethodName>_<Scenario>_<ExpectedResult>`:
```apex
@IsTest
static void testCalculateSalary_SeniorGrade_AppliesCorrectAllowance() {
    // 1. Arrange: Prepare inputs and context
    Employee__c emp = [SELECT Id, Designation__c, Salary__c FROM Employee__c WHERE Employee_Code__c = 'EMP-001' LIMIT 1];
    
    // 2. Act: Execute target method within clean governor limit window
    Test.startTest();
    Decimal netSalary = PayrollService.calculateNetSalary(emp.Id);
    Test.stopTest();
    
    // 3. Assert: Query resulting state and validate with modern assertions
    Assert.isNotNull(netSalary, 'Calculated salary must be returned');
    Assert.areEqual(85000.00, netSalary, 'Net salary should equal basic salary plus senior allowance');
}
```

### 5. Testing Asynchronous & Callout Logic
- **Async Execution**: Always wrap Batchable, Queueable, or Future invocations within `Test.startTest()` and `Test.stopTest()` to force synchronous completion before asserting.
- **HTTP Callouts**: Implement a mock class implementing `HttpCalloutMock` and register it using `Test.setMock(HttpCalloutMock.class, new MyHttpMock())`.
- **Flow Invocables**: Pass `List<InvocableRequest>` and assert the returned `List<InvocableResult>` as well as database state changes.

---

## Phase 4: Validation & Quality Gate

After generating the test class:

1. **Deploy Metadata**:
   ```bash
   sf project deploy start --metadata ApexClass:<TargetClassName>Test
   ```
2. **Execute Unit Tests**:
   ```bash
   sf apex run test --class-names <TargetClassName>Test --result-format human --code-coverage
   ```
3. **Quality Criteria**:
   - Pass Rate: **100%** (zero failures, zero unhandled errors).
   - Code Coverage: **>90%** across the target class.
   - Assertions: Every test method contains **at least one meaningful `Assert.*` statement**. Tests without assertions are strictly prohibited.

---

## Pattern Reference Library

For detailed code patterns, see:
- [Testing Invocable Actions, Controllers, and Batch Apex](./references/patterns.md)
- [Sample Production-Grade Test Class](./examples/SampleApexTest.cls)
