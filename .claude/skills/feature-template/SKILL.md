---
name: feature-template
description: Template per documentare nuove feature prima dello sviluppo
---

# Feature Specification Template

> Utilisez ce template pour documenter une nouvelle feature AVANT de la développer.
> Ce document guidera l'agent IA (ou les développeurs) dans l'implémentation.

## Workflow des agents

```
┌─────────────────────────────────────────────────────────────────┐
│                    📋 SPECIFICATION PHASE                        │
├─────────────────────────────────────────────────────────────────┤
│ 1. @feature_specification_agent → génère ce document            │
│                         ↓                                        │
│ 2. @feature_reviewer_agent → review (score X/10)                │
│                         ↓                                        │
│    [Si score < 7 ou issues critiques: réviser]                  │
│                         ↓                                        │
│ 3. @feature_planner_agent → plan d'implémentation               │
├─────────────────────────────────────────────────────────────────┤
│                    🔴 RED PHASE (per PR)                         │
├─────────────────────────────────────────────────────────────────┤
│ 4. @tdd_red_agent → tests failing (Gherkin → RSpec)             │
├─────────────────────────────────────────────────────────────────┤
│                    🟢 GREEN PHASE (per PR)                       │
├─────────────────────────────────────────────────────────────────┤
│ 5. Agents spécialistes → implémentation minimale                │
│    • @model_agent, @migration_agent (database)                  │
│    • @service_agent, @form_agent (business logic)               │
│    • @policy_agent (authorization)                              │
│    • @controller_agent (endpoints)                              │
│    • @view_component_agent (UI components)                      │
│    • @tailwind_agent (styling with Tailwind CSS)                │
│    • @mailer_agent, @job_agent (async)                          │
├─────────────────────────────────────────────────────────────────┤
│                    🔵 REFACTOR PHASE (per PR)                    │
├─────────────────────────────────────────────────────────────────┤
│ 6. @tdd_refactoring_agent → améliore le code (tests verts)      │
│                         ↓                                        │
│ 7. @lint_agent → corrige le style (Rubocop)                     │
├─────────────────────────────────────────────────────────────────┤
│                    ✅ REVIEW PHASE (per PR)                      │
├─────────────────────────────────────────────────────────────────┤
│ 8. @review_agent → qualité du code (SOLID, patterns)            │
│                         ↓                                        │
│ 9. @security_agent → audit sécurité (Brakeman, vulnérabilités)  │
│                         ↓                                        │
│    [Si issues: retour à l'étape 5 ou 6]                         │
├─────────────────────────────────────────────────────────────────┤
│                    🚀 MERGE & DEPLOY                             │
├─────────────────────────────────────────────────────────────────┤
│ 10. Merge PR → branche d'intégration                            │
│                         ↓                                        │
│     [Répéter 4-10 pour chaque PR step]                          │
│                         ↓                                        │
│ 11. Merge feature branch → main                                 │
│                         ↓                                        │
│ 12. Deploy → production                                         │
└─────────────────────────────────────────────────────────────────┘
```

### Résumé par phase

| Phase | Agent(s) | Objectif | Validation |
|-------|----------|----------|------------|
| **Spec** | @feature_specification_agent | Créer la spec | - |
| **Review Spec** | @feature_reviewer_agent | Valider la spec | Score ≥ 7/10 |
| **Plan** | @feature_planner_agent | Planifier l'implémentation | - |
| **RED** | @tdd_red_agent | Écrire tests failing | Tests rouges |
| **GREEN** | Agents spécialistes | Code minimal | Tests verts |
| **REFACTOR** | @tdd_refactoring_agent | Améliorer le code | Tests verts |
| **LINT** | @lint_agent | Style & formatting | Rubocop clean |
| **REVIEW** | @review_agent | Qualité code | Pas d'issues HIGH/CRITICAL |
| **SECURITY** | @security_agent | Audit sécurité | Brakeman clean |
| **MERGE** | Developer | Intégrer le code | CI vert |

---

## 📋 Informations générales

**Nom de la feature :** `[Nom court et descriptif]`

**Ticket/Issue :** `#[numéro]`

**Priorité :** `[Haute / Moyenne / Basse]`

**Estimation :** `[Petite / Moyenne / Grande]` ou `[X jours]`

---

## 🎯 Objectif

**Problème à résoudre :**
> Décrivez en 2-3 phrases le problème métier ou utilisateur que cette feature résout.
> Exemple : "Les utilisateurs ne peuvent pas filtrer les restaurants par type de cuisine, ce qui rend la recherche difficile quand ils ont une envie spécifique."

**Valeur apportée :**
> Quel bénéfice concret pour l'utilisateur ou le business ?
> Exemple : "Amélioration de l'expérience utilisateur et augmentation du taux de conversion de 15%."

**Critères de succès :**
- [ ] Critère mesurable 1
- [ ] Critère mesurable 2
- [ ] Critère mesurable 3

---

## 👤 Personas concernés

Cochez les personas impactés :
- [ ] Visiteur (non authentifié)
- [ ] Utilisateur Connecté
- [ ] Propriétaire de Ressource (Entity Owner)
- [ ] Administrateur

> 📋 **Pour chaque persona coché**, documenter les permissions dans la section Policies ci-dessous.

### Matrice d'autorisation

| Action | Visiteur | Utilisateur | Propriétaire | Admin |
|--------|----------|-------------|--------------|-------|
| Voir | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ |
| Créer | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ |
| Modifier | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ |
| Supprimer | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ |

---

## 📝 User Stories

### Story principale
```
En tant que [persona],
Je veux [action],
Afin de [bénéfice].
```

**Critères d'acceptation :**
- [ ] Critère 1 (mesurable, vérifiable par oui/non)
- [ ] Critère 2 (mesurable, vérifiable par oui/non)
- [ ] Critère 3 (mesurable, vérifiable par oui/non)

> ⚠️ **Note:** Les critères doivent être testables et éviter les termes subjectifs comme "bon", "rapide", "intuitif".

### Scénarios Gherkin (Acceptance Criteria)

> 📋 Ces scénarios serviront de base pour les tests d'acceptance avec `@tdd_red_agent`.

```gherkin
Feature: [Nom de la feature]

  Background:
    Given [contexte commun]

  # Happy Path
  Scenario: [Scénario principal de succès]
    Given [précondition]
    When [action utilisateur]
    Then [résultat attendu]
    And [vérification supplémentaire]

  # Validation
  Scenario: [Validation des données]
    Given [précondition]
    When [action avec données invalides]
    Then [message d'erreur affiché]
    And [données préservées dans le formulaire]

  # Authorization
  Scenario: [Contrôle d'accès]
    Given [utilisateur non autorisé]
    When [tentative d'action protégée]
    Then [redirection ou message d'erreur]
```

### Stories secondaires (optionnel)
> Si la feature est complexe, listez les autres stories avec leurs propres scénarios Gherkin.

---

## ⚠️ Edge Cases & Gestion des erreurs

> 🔴 **OBLIGATOIRE:** Documenter au minimum 3 edge cases.

### Edge Cases Identifiés

| # | Type | Scénario | Comportement attendu | Message d'erreur |
|---|------|----------|---------------------|------------------|
| 1 | Input invalide | [Description] | [Comportement] | [Message] |
| 2 | Accès non autorisé | [Description] | [Comportement] | [Message] |
| 3 | État vide/null | [Description] | [Comportement] | [Message] |
| 4 | Erreur réseau/système | [Description] | [Comportement] | [Message] |
| 5 | Opération concurrente | [Description] | [Comportement] | [Message] |

### Scénarios Gherkin pour Edge Cases

```gherkin
  # Edge Case: Invalid Input
  Scenario: User submits invalid data
    Given [précondition]
    When [action avec données invalides]
    Then [comportement attendu]
    And [message d'erreur spécifique]

  # Edge Case: Unauthorized Access
  Scenario: Unauthorized user attempts action
    Given I am logged in as [persona non autorisé]
    When I attempt to [action protégée]
    Then I should see "[message d'erreur]"
    And I should be redirected to [destination]

  # Edge Case: Empty State
  Scenario: No data available
    Given [aucune donnée existe]
    When I visit [page]
    Then I should see "[message état vide]"
    And I should see [call to action]
```

---

## 🔄 Découpage en PRs incrémentales

> ⚠️ **IMPORTANT** : Ne jamais one-shot une grosse feature en une seule PR.
>
> Cette section est **obligatoire** pour toute feature estimée à plus d'une journée de dev.

### Branche d'intégration

**Nom de la branche :** `feature/[nom-de-la-feature]`

Cette branche contiendra l'intégralité de la feature mais ne sera mergée dans `main` qu'une fois toutes les PRs incrémentales validées.

### Plan de découpage

> Découpez votre feature en **5-10 petites PRs** maximum (idéalement 3-5).
> Chaque PR doit :
> - Faire moins de 400 lignes (idéalement 50-200)
> - Avoir un objectif unique et clair
> - Être fonctionnelle et testée (même si feature incomplète)
> - Pointer vers la branche d'intégration (pas main)

#### Step 1 : [Titre court]
**Branch:** `feature/[nom]-step-1-[description]`

**Objectif :**
> Description en 1 phrase de ce que fait cette PR.
> Exemple : "Ajouter la migration et la colonne cuisine_type à la table restaurants"

**Contenu :**
- [ ] Migration `add_cuisine_type_to_restaurants`
- [ ] Index sur la colonne
- [ ] Tests de migration (up/down)

**Estimation :** 30 min dev + 15 min review

**Tests inclus :**
- [ ] Migration réversible
- [ ] Index créé correctement

---

#### Step 2 : [Titre court]
**Branch:** `feature/[nom]-step-2-[description]`

**Objectif :**
> Exemple : "Ajouter les validations et le scope de filtrage au modèle Restaurant"

**Contenu :**
- [ ] Constante `CUISINE_TYPES`
- [ ] Validation `inclusion` sur `cuisine_type`
- [ ] Scope `by_cuisine`
- [ ] Tests unitaires du modèle

**Estimation :** 1h dev + 30 min review

**Tests inclus :**
- [ ] Tests de validation
- [ ] Tests du scope
- [ ] Edge cases (nil, valeur invalide)

---

#### Step 3 : [Titre court]
**Branch:** `feature/[nom]-step-3-[description]`

**Objectif :**
> Exemple : "Modifier le controller pour accepter le filtre cuisine"

**Contenu :**
- [ ] Modification de `RestaurantsController#index`
- [ ] Ajout du paramètre `cuisine` dans strong params
- [ ] Tests de request specs

**Estimation :** 1h dev + 30 min review

**Tests inclus :**
- [ ] Tests de controller avec/sans filtre
- [ ] Tests d'autorisation si applicable

---

#### Step 4 : [Titre court]
**Branch:** `feature/[nom]-step-4-[description]`

**Objectif :**
> Exemple : "Ajouter l'interface utilisateur de filtrage"

**Contenu :**
- [ ] Formulaire de filtre dans `index.html.erb`
- [ ] Turbo Frame pour le rechargement dynamique
- [ ] Styling Tailwind

**Estimation :** 2h dev + 1h review

**Tests inclus :**
- [ ] Tests de feature avec Capybara
- [ ] Tests JavaScript si interactions complexes

---

#### Step 5 : [Titre court] (optionnel)
**Branch:** `feature/[nom]-step-5-[description]`

**Objectif :**
> Exemple : "Tests d'intégration end-to-end et documentation"

**Contenu :**
- [ ] Tests d'intégration complets
- [ ] Documentation mise à jour
- [ ] Seeds mis à jour

**Estimation :** 1h dev + 30 min review

**Tests inclus :**
- [ ] Scénario utilisateur complet
- [ ] Tests de régression

---

### Stratégie de merge

```bash
# 1. Créer la branche d'intégration
git checkout -b feature/[nom-de-la-feature]
git push -u origin feature/[nom-de-la-feature]

# 2. Pour chaque step :
git checkout feature/[nom-de-la-feature]
git checkout -b feature/[nom]-step-X-[description]
# ... développer ...
git commit -m "feat: step X description"
git push -u origin feature/[nom]-step-X-[description]

# 3. Créer une PR vers la branche d'intégration
gh pr create --base feature/[nom-de-la-feature] \
  --title "[Step X/Y] Description courte" \
  --body "Part of #[issue]. Description détaillée."

# 4. Review + merge de la step
# 5. Répéter pour chaque step

# 6. Une fois toutes les steps mergées :
gh pr create --base main \
  --title "Feature: [Nom complet de la feature]" \
  --body "Closes #[issue]. All incremental PRs reviewed and merged."
```

### Checklist de découpage

- [ ] La feature est découpée en **3-10 steps maximum**
- [ ] Chaque step fait **moins de 400 lignes**
- [ ] Chaque step est **autonome et testée**
- [ ] L'ordre des steps est **logique** (dépendances respectées)
- [ ] Chaque step a une **estimation** de temps
- [ ] Le **plan complet** est documenté avant de commencer

### Règles de découpage

#### ✅ Bon découpage
- Migration seule (step 1)
- Modèle + validations (step 2)
- Controller + routes (step 3)
- Views + composants (step 4)
- Tests d'intégration (step 5)

#### ❌ Mauvais découpage
- Migration + modèle + controller + views (trop gros)
- Juste les validations sans tests (incomplet)
- Moitié du controller (pas autonome)
- Tous les tests à la fin (risqué)

### Pour les coding agents

Quand vous utilisez un coding agent (Claude Code, GitHub Copilot, etc.) :

**❌ Ne demandez pas :**
```
"Implémente complètement la feature de [nom]"
```

**✅ Demandez plutôt :**
```
"Implémente la Step 1 de la feature spec [nom] : [description step 1]"
```

Puis une fois la Step 1 reviewée et mergée :
```
"Implémente la Step 2 de la feature spec [nom] : [description step 2]"
```

Et ainsi de suite.

**Avantages :**
- 🎯 Contexte ciblé → moins d'erreurs
- ✅ Review rapide → feedback immédiat
- 🔁 Correction facile → pas de refonte totale
- 📈 Progression visible → confiance de l'équipe

---

## 🏗️ Cadrage technique

### Modèles impactés

#### Nouveaux modèles
```ruby
# Si création d'un nouveau modèle
class NewModel < ApplicationRecord
  # Attributs principaux
  # - attribute_name: type (contraintes)

  # Associations
  # belongs_to :xxx
  # has_many :yyy

  # Validations principales
  # validates :xxx, presence: true
end
```

#### Modifications de modèles existants
**Modèle :** `ExistingModel`

**Changements :**
- [ ] Ajout d'attribut : `new_attribute:string`
- [ ] Ajout de relation : `has_many :new_relation`
- [ ] Nouvelle validation : `validates :xxx, ...`
- [ ] Nouveau scope : `scope :by_xxx, -> { ... }`
- [ ] Nouvelle méthode : `def calculate_xxx`

### Règles de validation

> 🔴 **OBLIGATOIRE:** Pour chaque champ utilisateur, spécifier les règles de validation.

| Champ | Type | Requis | Règles de validation | Message d'erreur |
|-------|------|--------|----------------------|------------------|
| `name` | string | Oui | presence, length: 2..100 | "Le nom est obligatoire" |
| `email` | string | Oui | format: URI::MailTo::EMAIL_REGEXP | "Format email invalide" |
| `amount` | decimal | Oui | numericality: { greater_than: 0 } | "Le montant doit être positif" |
| `status` | string | Oui | inclusion: { in: STATUSES } | "Statut invalide" |
| `description` | text | Non | length: { maximum: 1000 } | "Description trop longue (max 1000)" |

### Migration(s)

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_feature_name.rb
class AddFeatureName < ActiveRecord::Migration[8.1]
  def change
    # Ajout de colonnes
    add_column :table_name, :column_name, :type, null: false, default: value

    # Ajout d'index
    add_index :table_name, :column_name

    # Création de table
    create_table :new_table do |t|
      t.string :name, null: false
      t.references :parent, foreign_key: true
      t.timestamps
    end
  end
end
```

**⚠️ Points d'attention migration :**
- [ ] Migration réversible (`up`/`down` ou méthode `change`)
- [ ] Index ajoutés sur les colonnes clés
- [ ] Valeurs par défaut définies si nécessaire
- [ ] Foreign keys avec `on_delete` approprié

### Controllers

#### Nouveaux controllers
- `NewController` avec actions : `index`, `show`, `new`, `create`, `edit`, `update`, `destroy`

#### Modifications de controllers existants
**Controller :** `ExistingController`

**Changements :**
- [ ] Nouvelle action : `custom_action`
- [ ] Modification des strong parameters
- [ ] Ajout de before_action
- [ ] Modification de la logique métier

**Strong parameters :**
```ruby
def model_params
  params.require(:model_name).permit(:attr1, :attr2, :attr3)
end
```

### Routes

```ruby
# config/routes.rb
resources :resource_name do
  # Routes imbriquées si nécessaire
  resources :nested_resource, only: [:index, :create, :destroy]

  # Routes custom
  member do
    post :custom_action
  end

  collection do
    get :custom_collection_action
  end
end
```

### Services (si logique complexe)

**Service :** `FeatureNameService`

**Responsabilité :**
> Décrivez en 1-2 phrases ce que fait ce service.

**Méthodes principales :**
```ruby
class FeatureNameService
  def initialize(params)
    @params = params
  end

  def call
    # Logique métier complexe ici
    # Retourne un résultat ou lève une exception
  end

  private

  def step_one
    # ...
  end
end
```

### Policies (Pundit)

**Policy :** `ModelPolicy`

**Nouvelles règles :**
```ruby
class ModelPolicy < ApplicationPolicy
  def action_name?
    # user.admin? || record.user == user
  end
end
```

### Views & Components

#### Nouvelles vues
- `app/views/resource_name/index.html.erb`
- `app/views/resource_name/show.html.erb`
- `app/views/resource_name/_form.html.erb`

#### Nouveaux components
**Component :** `FeatureNameComponent`

```ruby
class FeatureNameComponent < ViewComponent::Base
  def initialize(param:)
    @param = param
  end

  def render?
    # Condition d'affichage
  end
end
```

#### Modifications de vues existantes
- [ ] Vue à modifier : `path/to/view.html.erb`
- [ ] Type de modification : [Ajout d'un lien / Nouveau formulaire / Affichage de données]

### JavaScript (Stimulus)

#### Nouveaux controllers Stimulus
**Controller :** `feature_name_controller.js`

```javascript
import { Controller } from "@hotwire/stimulus"

export default class extends Controller {
  static targets = ["element"]
  static values = { param: String }

  connect() {
    // Initialisation
  }

  action() {
    // Logique
  }
}
```

### Jobs (Background)

**Job :** `FeatureNameJob`

```ruby
class FeatureNameJob < ApplicationJob
  queue_as :default

  def perform(param)
    # Traitement asynchrone
  end
end
```

**Déclenchement :**
- Où : `ModelName#method_name`
- Quand : `after_commit :enqueue_job`

---

## 🧪 Stratégie de tests

### Tests de modèle (RSpec)

**Fichier :** `spec/models/model_name_spec.rb`

**Tests à écrire :**
- [ ] Validations (presence, format, uniqueness, etc.)
- [ ] Associations (belongs_to, has_many, etc.)
- [ ] Scopes (vérifier les requêtes SQL)
- [ ] Méthodes métier (logique, edge cases)
- [ ] Callbacks (after_save, before_destroy, etc.)

**Exemples de tests :**
```ruby
RSpec.describe ModelName, type: :model do
  describe "validations" do
    it { should validate_presence_of(:attribute) }
    it { should validate_uniqueness_of(:attribute) }
  end

  describe "#custom_method" do
    it "returns expected result" do
      instance = create(:model_name)
      expect(instance.custom_method).to eq(expected_value)
    end
  end
end
```

### Tests de controller (Request specs)

**Fichier :** `spec/requests/controller_name_spec.rb`

**Tests à écrire :**
- [ ] Actions CRUD (index, show, create, update, destroy)
- [ ] Autorisations (utilisateur connecté, propriétaire, etc.)
- [ ] Redirections et flash messages
- [ ] Réponses HTTP (200, 302, 404, 422, etc.)

**Exemples de tests :**
```ruby
RSpec.describe "ResourceName", type: :request do
  let(:user) { create(:user) }
  let(:resource) { create(:resource_name, user: user) }

  describe "GET /resources/:id" do
    it "returns http success" do
      get resource_path(resource)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /resources" do
    context "with valid params" do
      it "creates a new resource" do
        expect {
          post resources_path, params: { resource_name: valid_attributes }
        }.to change(ResourceName, :count).by(1)
      end
    end
  end
end
```

### Tests d'intégration (Feature specs)

**Fichier :** `spec/features/feature_name_spec.rb`

**Scénarios à tester :**
- [ ] Parcours utilisateur complet (happy path)
- [ ] Cas d'erreur (formulaire invalide, accès refusé)
- [ ] Interactions JavaScript (si applicable)

**Exemples de tests :**
```ruby
RSpec.describe "Feature Name", type: :feature do
  scenario "user completes the feature workflow" do
    user = create(:user)
    login_as(user)

    visit new_resource_path
    fill_in "Name", with: "Example"
    click_button "Create"

    expect(page).to have_content("Resource créé avec succès")
    expect(page).to have_current_path(resource_path(ResourceName.last))
  end
end
```

### Tests de component

**Fichier :** `spec/components/component_name_component_spec.rb`

**Tests à écrire :**
- [ ] Rendu avec différents params
- [ ] Conditions d'affichage (`render?`)
- [ ] Contenu généré

### Tests de policy

**Fichier :** `spec/policies/policy_name_spec.rb`

**Tests à écrire :**
- [ ] Permissions par rôle
- [ ] Edge cases

```ruby
RSpec.describe ResourcePolicy, type: :policy do
  subject { described_class.new(user, resource) }

  context "for owner" do
    let(:user) { resource.user }
    it { should permit_action(:update) }
    it { should permit_action(:destroy) }
  end

  context "for other user" do
    let(:user) { create(:user) }
    it { should_not permit_action(:update) }
  end
end
```

---

## 🔒 Considérations de sécurité

- [ ] **Strong parameters** : tous les attributs sont filtrés
- [ ] **Autorisations Pundit** : toutes les actions sont protégées
- [ ] **Validations** : tous les inputs utilisateur sont validés
- [ ] **Injection SQL** : utiliser ActiveRecord, pas de SQL brut
- [ ] **XSS** : utiliser les helpers Rails (sanitize, escape)
- [ ] **CSRF** : tokens présents sur les formulaires
- [ ] **Mass assignment** : utiliser `permit` correctement
- [ ] **Données sensibles** : pas de logs ou affichage de secrets

---

## ⚡ Considérations de performance

- [ ] **N+1 queries** : utiliser `includes`/`preload`/`eager_load`
- [ ] **Index DB** : ajouter des index sur les colonnes requêtées
- [ ] **Cache** : identifier les données à mettre en cache
- [ ] **Background jobs** : tâches longues en asynchrone
- [ ] **Pagination** : limiter les résultats des listes
- [ ] **Requêtes lourdes** : optimiser avec `select`, `pluck`, `exists?`

---

## 📱 Considérations UI/UX

> 🔴 **OBLIGATOIRE pour features avec UI:** Documenter les états interactifs.

### Checklist UI/UX
- [ ] **Responsive** : design adapté mobile/tablet/desktop
- [ ] **Accessibilité** : labels, aria-labels, contraste (WCAG 2.1 AA minimum)
- [ ] **Feedback utilisateur** : flash messages, états de chargement
- [ ] **Validation côté client** : Stimulus + HTML5 validation
- [ ] **Error handling** : messages d'erreur clairs et actionnables

### États interactifs (Hotwire/Turbo)

| État | Description | Implémentation |
|------|-------------|----------------|
| **Loading** | Pendant le chargement | Turbo Frame avec spinner, `aria-busy="true"` |
| **Success** | Action réussie | Flash notice, Turbo Stream append/replace |
| **Error** | Échec de l'action | Flash alert, formulaire préservé, erreurs inline |
| **Empty** | Aucune donnée | Message explicatif + call-to-action |
| **Disabled** | Action non disponible | Bouton désactivé + tooltip explicatif |

### Messages utilisateur

| Contexte | Type | Message |
|----------|------|---------|
| Création réussie | success | "[Ressource] créé(e) avec succès" |
| Modification réussie | success | "[Ressource] mis(e) à jour" |
| Suppression réussie | success | "[Ressource] supprimé(e)" |
| Erreur validation | error | "Veuillez corriger les erreurs ci-dessous" |
| Non autorisé | error | "Vous n'êtes pas autorisé à effectuer cette action" |
| Non trouvé | error | "[Ressource] introuvable" |

---

## 🚀 Plan de déploiement

### Prérequis
- [ ] Migration testée (up & down)
- [ ] Seeds mis à jour si nécessaire
- [ ] Assets precompilés (si changements CSS/JS)
- [ ] Variables d'environnement ajoutées (si nécessaire)

### Étapes
1. Déployer le code
2. Lancer les migrations : `rails db:migrate`
3. Redémarrer les workers si jobs ajoutés
4. Vérifier les logs
5. Tester en production

### Rollback plan
> Comment revenir en arrière si problème ?
```bash
# Rollback de migration
rails db:rollback STEP=1

# Redéployer version précédente
kamal rollback
```

---

## 📚 Documentation à mettre à jour

- [ ] `README.md` : si feature majeure
- [ ] `.github/project.md` : si nouvelle fonctionnalité principale
- [ ] `.github/CONTRIBUTING.md` : si nouvelles conventions
- [ ] API docs : si endpoints exposés
- [ ] User guide : si feature visible utilisateur

---

## ✅ Checklist finale avant merge

### Code
- [ ] Code écrit et fonctionnel
- [ ] Rubocop passe sans erreurs
- [ ] Pas de code commenté ou de `binding.pry`
- [ ] Nomenclature respectée

### Tests
- [ ] Tous les tests passent
- [ ] Coverage maintenue (>90%)
- [ ] Tests unitaires écrits
- [ ] Tests d'intégration écrits
- [ ] Edge cases testés

### Sécurité
- [ ] Brakeman ne remonte pas de nouvelles vulnérabilités
- [ ] Bundler Audit OK
- [ ] Policies testées
- [ ] Strong parameters vérifiés

### Documentation
- [ ] Code commenté si logique complexe
- [ ] README mis à jour si nécessaire
- [ ] CHANGELOG.md mis à jour

### Review
- [ ] PR créée avec description claire
- [ ] Screenshots/GIF si changements UI
- [ ] Reviewer assigné
- [ ] CI/CD vert

---

## 💡 Notes & Questions

> Espace libre pour noter des questions, décisions techniques, ou points d'attention particuliers.

**Questions ouvertes :**
-

**Décisions techniques :**
-

**Points d'attention :**
-

**Dépendances externes :**
-

---

**Date de création :** `[YYYY-MM-DD]`

**Auteur :** `[@username]`

**Reviewers :** `[@username1, @username2]`

**Statut :** `[Draft / En Review / Ready for Dev / In Progress / Completed]`

---

## 📋 Critères de Review (@feature_reviewer_agent)

> Cette section récapitule les critères que `@feature_reviewer_agent` vérifiera.

### MUST HAVE (Bloquant si absent)
- [ ] Objectif et valeur clairement énoncés
- [ ] Personas identifiés
- [ ] User story principale documentée
- [ ] Critères d'acceptation testables (vérifiables par oui/non)
- [ ] Scénarios Gherkin pour acceptance tests
- [ ] Edge cases documentés (minimum 3)
- [ ] Matrice d'autorisation complète

### SHOULD HAVE (Recommandé)
- [ ] Tableau des règles de validation
- [ ] Composants techniques listés
- [ ] Changements base de données documentés
- [ ] Policies Pundit spécifiées
- [ ] Points d'intégration identifiés

### IF UI (Obligatoire si feature UI)
- [ ] États loading/error/empty/success documentés
- [ ] Messages utilisateur définis
- [ ] Comportement responsive spécifié
- [ ] Accessibilité considérée (WCAG 2.1 AA)

### IF Medium/Large (Obligatoire si > 1 jour)
- [ ] Découpage en PRs (3-10 steps)
- [ ] Chaque PR < 400 lignes (idéalement 50-200)
- [ ] Dépendances entre PRs claires
- [ ] Tests inclus dans chaque PR

```
