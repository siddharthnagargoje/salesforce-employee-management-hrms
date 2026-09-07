# Apex Code Review Report Template

Use this format to present formal code review findings to developers and technical stakeholders.

---

```markdown
# 🛡️ Apex Code Review: [TargetClassName.cls]

## 1. Executive Summary

- **Verdict**: [APPROVED ✅ | APPROVED WITH SUGGESTIONS ⚠️ | CHANGES REQUESTED ❌]
- **Production Readiness Score**: [X/100]
- **Summary**: [2-3 sentence overview of code quality, architecture, and deployment readiness]

### Score Breakdown
- 🔒 **Security & Sharing**: [X/25]
- ⚡ **Performance & Governor Limits**: [X/25]
- 🏗️ **Architecture & Modularity**: [X/25]
- 🧪 **Testing & Exception Handling**: [X/25]

---

## 2. Findings Matrix

| Ref | Severity | Category | Location | Summary |
| :--- | :--- | :--- | :--- | :--- |
| **SEC-01** | 🔴 Critical | Security | Line 45 | Missing `WITH USER_MODE` on query exposing sensitive salary data |
| **GOV-01** | 🔴 Critical | Performance | Line 88 | SOQL query inside `for` loop violates 101 governor limit |
| **ERR-01** | 🟠 Major | Robustness | Line 120 | Empty catch block swallows `DmlException` without logging |
| **CLN-01** | 🟡 Minor | Code Style | Line 15 | Hardcoded status string `'Approved'` instead of constant |
| **ARC-01** | 🟢 Praise | Architecture | Line 30 | Clean use of bulk Invocable request/response pattern |

---

## 3. Detailed Findings & Recommended Fixes

### 🔴 SEC-01: [Brief Title]
- **File**: `[file_path]` (Lines: [X-Y])
- **Issue**: [Detailed explanation of vulnerability or violation]
- **Risk**: [Governor limit exhaustion, data leakage, regression, etc.]
- **Recommendation**: [Exact guidance on how to fix]

#### Suggested Code Diff:
```diff
- List<Employee__c> emps = [SELECT Id, Salary__c FROM Employee__c WHERE Id = :empId];
+ List<Employee__c> emps = [SELECT Id, Salary__c FROM Employee__c WHERE Id = :empId WITH USER_MODE];
```

---

## 4. Test Class Assessment

- **Companion Test Class**: `[TargetClassNameTest.cls]`
- **Current Coverage**: [XX%]
- **Missing Test Vectors**:
  - [ ] Negative / Null Input handling
  - [ ] Bulk 200-record scale test
  - [ ] Fault / Exception trigger verification
  - [ ] `System.runAs()` Security context validation

---

## 5. Next Steps for Approval

1. Apply proposed diffs for **Critical** and **Major** findings.
2. Run unit tests using `sf apex run test -n [TargetClassNameTest] -r human`.
3. Re-submit for final architectural sign-off.
```
