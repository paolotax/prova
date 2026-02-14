# Insegnanti Views Redesign — Design Doc

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign insegnanti views to leverage CattedraDisciplina mappings — group teachers by cattedra with per-teacher books, create persona show page, enrich classe show.

**Architecture:** Three view changes using existing CattedraDisciplina mappings to connect ANARPE cattedre to MIUR discipline/adozioni. Helper for compact class notation (inverse of parser). No new models needed.

**Tech Stack:** Rails ERB views, existing CSS (no Tailwind), Turbo frames for persona show.

---

## 1. Scuola Show — Tabella Insegnanti Raggruppata per Cattedra

### Current State
Flat table: Docente | Materia | Classi. No books, no grouping.

### New Design
Table grouped by cattedra (materia from persona_classi). Each group:

```
┌──────────────────────────────────────────────────────────────┐
│ LETTERE                                                       │  ← header cattedra (colspan)
├──────────────────────────────────────────────────────────────┤
│ Bellesia Elisa    2A 3F    "Il mio libro" Zanichelli         │
│ Bisi Francesca    13C      "Altro libro" Mondadori           │
│ Bonato Bianca     2F 3D    "Il mio libro" Zanichelli         │
├──────────────────────────────────────────────────────────────┤
│ MATEMATICA E SCIENZE                                          │
├──────────────────────────────────────────────────────────────┤
│ Bassoli Letizia   123E     "Mate oggi" DeAgostini            │
└──────────────────────────────────────────────────────────────┘
```

### Data Flow
1. Load persone docenti with persona_classi, ordered by posizione
2. Group by `persona_classi.materia` (cattedra)
3. For each docente, find discipline MIUR via `CattedraDisciplina.where(cattedra: materia, tipo_scuola:, account:)`
4. Find adozioni: `Adozione.where(classe: persona.classi, disciplina: discipline_miur).includes(:libro)`
5. Display: nome (link to persona show) | classi compatte (links) | libri (titolo + editore)

### Ordering
- Cattedre: by posizione of first teacher (same as matcher)
- Docenti within cattedra: by posizione (PDF import order)

### Compact Classes Helper
Inverse of parser's `parse_classi_compact`. Takes array of Classe objects, returns compact string.
Examples:
- `[1A, 2A]` → "12A"
- `[1A, 2A, 3F]` → "12A 3F"
- `[1E, 2E, 3E]` → "123E"
- `[3L, 4P, 5N]` → "3L 4P 5N"

Logic: group classes by sezione, within each sezione join the anni, output "anni+sezione" tokens separated by space.

### Files
- Modify: `app/views/scuole/container/_insegnanti.html.erb`
- Create: `app/helpers/classi_helper.rb` (compact notation helper)
- Modify: `app/views/scuole/show.html.erb` (pass tipo_scuola to partial)

---

## 2. Persona Show (New Page)

### Design
Standard header with back arrow to scuola.

**Info section**: Name, cattedra (materia), scuola link.

**Classi + Adozioni table**: For each class of the teacher, show:
- Classe (link to classe show)
- Books adopted in that class for the teacher's discipline (via CattedraDisciplina mapping)
- Each book: titolo, editore, stato adozione (mia, nuova, da_acquistare)

**Appunti section**: Entries linked to this persona via Appuntabile. Turbo frame lazy-loaded or inline.

### Files
- Create: `app/controllers/scuole/persone_controller.rb` (show action only, nested under scuole)
- Create: `app/views/scuole/persone/show.html.erb`
- Modify: `config/routes.rb` (add `resources :persone, only: [:show]` in scuole scope)

---

## 3. Classe Show — Docenti Arricchiti

### Current State
Docenti section shows: nome | materia. No books.

### New Design
Add books column: for each docente, show the books adopted in THIS class for their discipline.

Same CattedraDisciplina lookup: teacher's materia → mapped discipline → adozioni for this class + discipline → libro.

### Files
- Modify: `app/views/scuole/classi/show.html.erb` (docenti section)

---

## Implementation Tasks

### Task 1: Compact Classes Helper
- Create `app/helpers/classi_helper.rb` with `compact_classi(classi)` method
- Test with known inputs from ANARPE parsing

### Task 2: Scuola Show — Insegnanti Raggruppata
- Rewrite `_insegnanti.html.erb` partial
- Group persone by materia, show books per teacher
- Compact classi with helper, classi cliccabili

### Task 3: Persona Show Page
- Controller, view, route
- Classi + adozioni per disciplina
- Appunti collegati

### Task 4: Classe Show — Docenti con Libri
- Add books column to docenti section
- Same CattedraDisciplina lookup pattern
