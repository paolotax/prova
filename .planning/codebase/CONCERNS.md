# Codebase Concerns

**Analysis Date:** 2026-01-17

## Tech Debt

### Debug Statements in Production Code
- **Issue:** Multiple `puts "DEBUG: ..."` statements
- **Files:** `app/pdfs/foglio_scuola_pdf.rb` (lines 108, 124, 158, 183, 188, 192, 196)
- **Impact:** Pollutes logs, potential performance impact
- **Fix:** Remove debug puts, use `Rails.logger.debug` if needed

### Silent Exception Swallowing
- **Issue:** Bare `rescue` clauses that hide errors
- **Files:**
  - `app/pdfs/layout_pdf.rb:77` - Silent rescue in logo rendering
  - `app/services/italian_date_parser.rb:86, 99, 105` - Silent rescue swallows parsing errors
- **Impact:** Bugs go undetected
- **Fix:** Log errors or rescue specific exceptions

### Commented-out Code
- **Issue:** Large blocks of commented code throughout codebase
- **Files:** `app/models/appunto.rb` - Many commented scopes
- **Fix:** Remove if not needed, or document why preserved

## Security Considerations

### SQL Injection Risk
- **Risk:** User-defined SQL queries in Stat model
- **Files:** `app/models/stat.rb:40-44`
- **Mitigation:** Restrict who can create stats (admin-only via Avo)
- **Recommendation:** Add SQL query validation

### Uncontrolled constantize
- **Risk:** Arbitrary class instantiation from user input
- **Files:**
  - `app/controllers/tappe_controller.rb:195`
  - `app/controllers/filters_controller.rb:19`
- **Recommendation:** Whitelist allowed types before constantize

### html_safe Usage
- **Risk:** Potential XSS if user input reaches html_safe
- **Files:**
  - `app/controllers/tappe/bulk_actions_controller.rb:130`
  - `app/helpers/markdown_helper.rb:27`
- **Recommendation:** Sanitize before marking safe

## Performance Bottlenecks

### Large Controller Actions
- **Problem:** Complex PDF generation in request cycle
- **Files:**
  - `app/controllers/agenda_controller.rb` (380 lines)
  - `app/pdfs/documento_pdf.rb` (590 lines)
- **Improvement:** Extract to service objects, use background jobs

### Raw SQL in Controllers
- **Problem:** Complex SQL executed synchronously
- **Files:**
  - `app/controllers/agenda_controller.rb:165` - Crosstab query
  - `app/models/libro.rb:232, 249` - Inventory queries
- **Improvement:** Cache results, use materialized views

### Unbounded Queries
- **Problem:** `.all` called without limits
- **Files:** Various controllers for reference tables
- **Improvement:** Add pagination or cache reference data

## Fragile Areas

### Filter System Dynamic Loading
- **Files:** `app/controllers/concerns/filter_scoped.rb`
- **Why fragile:** Relies on naming conventions, constantize from controller names
- **Safe modification:** Test with non-existent filter types

### Polymorphic Associations
- **Files:** Multiple models use polymorphic `belongs_to`
- **Why fragile:** String type columns can get out of sync
- **Examples:**
  - `Documento.clientable_type`
  - `Tappa.tappable_type`
  - `Appunto.appuntabile_type`

## Test Coverage Gaps

**Very Low Coverage:** ~20 test files for 392 app files

### Critical Untested Areas (High Priority)
- Document/Invoice system - Financial calculations
- Import services - Data integrity
- Authorization policies - Security

### Medium Priority
- Filter system - Complex logic
- PDF generation - Layout correctness
- Agenda/Tappa system - Date logic

## Multi-tenancy Status

**In Progress:** Account-based multi-tenancy partially implemented

- **Files:** `app/models/account.rb`, `app/models/membership.rb`
- **Concern:** `AccountScoped` for model isolation
- **Branch:** `feature/multi-tenancy` active

## Dependencies

### Counter Cache Synchronization
- `fascicoli_count` and `confezioni_count` on Libro via counter_culture
- Risk: Can get out of sync if bulk operations bypass callbacks

### No Critical Dependency Issues Identified

---

*Concerns audit: 2026-01-17*
