# 30-Point Apex Code Review Checklist

Use this exhaustive checklist when performing comprehensive Apex code reviews in the HRMS project.

---

## 1. Security & Data Integrity
1. **Sharing Declaration**: Class explicitly specifies `with sharing`, `without sharing`, or `inherited sharing`.
2. **User Mode Queries**: SOQL queries specify `WITH USER_MODE` or enforce FLS via `Security.stripInaccessible()`.
3. **SOQL Injection Immunity**: Queries utilize static bind variables (`:variableName`) or `String.escapeSingleQuotes()`.
4. **CRUD on DML**: `isCreateable()`, `isUpdateable()`, or `isDeletable()` describes are evaluated or handled via `USER_MODE`.
5. **Hardcoded IDs**: Zero hardcoded 15- or 18-character Salesforce record IDs or URLs.
6. **Encrypted Data Handling**: Sensitive employee data (SSN, Bank details, Salary) is masked or protected with Field-Level Security.

---

## 2. Performance & Governor Limits
7. **No SOQL in Loops**: Zero SOQL queries inside `for`, `while`, or `do-while` loops.
8. **No DML in Loops**: Zero DML operations inside loops; all records collected into lists and committed in bulk.
9. **Selective SOQL**: Filter criteria leverage indexed fields (Id, Name, RecordType, Foreign Keys, External IDs).
10. **Query Projections**: Only necessary fields are queried; avoid unbounded or unused fields.
11. **SOQL For-Loops**: Large datasets queried with `for (List<sObject> batch : [SELECT ...])` to preserve heap size.
12. **Collection Usage**: Maps and Sets utilized for O(1) relational lookups instead of nested loops (O(N^2)).
13. **CPU Time Optimization**: Heavy string manipulations use `String.join()` or `StringBuilder` patterns where necessary.
14. **Asynchronous Guardrails**: Queueable and Batch jobs check transaction limits (`Limits.getQueueableJobs()`).

---

## 3. Architecture & Modularity
15. **Trigger Pattern**: Triggers are 100% logic-free; delegating entirely to dedicated Trigger Handlers.
16. **Single Trigger per Object**: Exactly one trigger per sObject to prevent race conditions.
17. **Separation of Concerns**: Controllers only handle UI inputs/outputs; domain and calculation logic lives in Services.
18. **Reusability & DRY**: Common queries and helper logic are centralized in Selector or Utility classes.
19. **Magic String Prevention**: Constants, picklist values, and statuses defined in centralized constant classes.
20. **Invocable Encapsulation**: `@InvocableMethod`s accept bulk lists and return matching bulk lists with error flags.

---

## 4. Exception Handling & Robustness
21. **Transaction Atomicity**: Multi-object updates use Savepoints (`Database.setSavepoint()` and `rollback()`).
22. **No Empty Catch Blocks**: Exceptions are logged or handled; never swallowed silently (`catch (Exception e) {}`).
23. **User-Friendly LWC Errors**: `@AuraEnabled` methods wrap internal exceptions in informative `AuraHandledException`s.
24. **Specific Catch Blocks**: Catch specific exceptions (`QueryException`, `DmlException`) before general `Exception`.
25. **Null Safety**: Safe navigation operator (`?.`) or explicit null checks on collections, map lookups, and query results.

---

## 5. Testing & Verification
26. **Zero SeeAllData**: Complete test isolation without `(SeeAllData=true)`.
27. **Test Setup Pattern**: `@TestSetup` utilized for heavy record setup to minimize test execution time.
28. **Spring '23+ Assertions**: Modern `Assert.areEqual()`, `Assert.isTrue()`, `Assert.isNull()` with descriptive messages.
29. **5-Vector Coverage**: Positive, Negative, Bulk (200 records), Fault, and Security (`System.runAs`) tested.
30. **Coverage Metric**: >90% code coverage across all business logic branches.
