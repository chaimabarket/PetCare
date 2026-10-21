---
name: PetCare Community
colors:
  surface: '#f8f9ff'
  surface-dim: '#d0dbed'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e6eeff'
  surface-container-high: '#dee9fc'
  surface-container-highest: '#d9e3f6'
  on-surface: '#121c2a'
  on-surface-variant: '#3e4947'
  inverse-surface: '#27313f'
  inverse-on-surface: '#eaf1ff'
  outline: '#6e7977'
  outline-variant: '#bdc9c6'
  surface-tint: '#006a63'
  primary: '#005c55'
  on-primary: '#ffffff'
  primary-container: '#0f766e'
  on-primary-container: '#a3faef'
  inverse-primary: '#80d5cb'
  secondary: '#8c4e38'
  on-secondary: '#ffffff'
  secondary-container: '#feae92'
  on-secondary-container: '#793f2a'
  tertiary: '#7f4025'
  on-tertiary: '#ffffff'
  tertiary-container: '#9c573a'
  on-tertiary-container: '#ffe5db'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#9cf2e8'
  primary-fixed-dim: '#80d5cb'
  on-primary-fixed: '#00201d'
  on-primary-fixed-variant: '#00504a'
  secondary-fixed: '#ffdbcf'
  secondary-fixed-dim: '#ffb59c'
  on-secondary-fixed: '#380d01'
  on-secondary-fixed-variant: '#6f3723'
  tertiary-fixed: '#ffdbce'
  tertiary-fixed-dim: '#ffb598'
  on-tertiary-fixed: '#370e00'
  on-tertiary-fixed-variant: '#72361b'
  background: '#f8f9ff'
  on-background: '#121c2a'
  surface-variant: '#d9e3f6'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 34px
  headline-md:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
  headline-sm:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-mobile: 0.75rem
  margin: 1.5rem
  margin-mobile: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

The design system establishes a warm, composed, and trustworthy environment for pet owners, animal fosters, and veterinary partners. It balances professional caregiving standards with genuine emotional warmth, avoiding juvenile or playful clichés (such as exaggerated cartoon paws or chaotic pastel schemes) in favor of serene editorial clarity.

- **Design Style:** Modern Organic Minimalism. Clean structural surfaces, generous negative space, intentional typographic hierarchy, and warm organic undertones that convey empathy and reliable competence.
- **Tone:** Bienveillant, rassurant, moderne et accessible (Caring, reassuring, modern, and accessible).
- **Target Audience:** Modern pet parents, foster networks, shelters, and veterinary clinics needing straightforward navigation and clear status tracking.

## Colors

The palette grounds emotional moments in clinical dependability through a rich deep teal primary and an energetic, welcoming coral accent.

- **Fond d'application (Canvas):** `#F8FAF9` delivers a soft, organic off-white background that prevents the clinical glare of `#FFFFFF` while keeping contrast sharp.
- **Surfaces & Cartes:** `#FFFFFF` pure white to provide clear spatial isolation and crisp readability.
- **Teal Primaire (`#0F766E`):** Represents veterinary hygiene, reliability, and security. Used for primary navigation, primary action buttons, focused strokes, and authoritative badges.
- **Corail Accent (`#F4A58A`):** Used for emotional resonance, favorites, donations, adoptions, and highlight moments. 
  - *Accessibility Rule:* When displaying coral as text, iconography, or borders on light backgrounds, strictly use the darker accessible shade `#E07A5F` (WCAG AA compliant against white/canvas). Use `#F4A58A` for large filled shapes, background washes, and decorative badges with dark contrast text.
- **Typographie:**
  - Texte principal: `#1F2937` (Charcoal intense) for high-contrast legibility.
  - Texte secondaire / Métadonnées: `#6B7280` (Gris neutre doux).
- **Couleurs de Statut & Badges:**
  - *Disponible / Confirmé (Succès):* `#10B981` (Fond / Accent) et `#059669` (Texte / Bordure).
  - *En attente / Réservé (Alerte):* `#F59E0B` (Texte / Icône sur `#FEF3C7`).
  - *Adopté (Célébration):* `#F4A58A` (Fond badge sur `#FFF7F5`) et `#E07A5F` (Texte / Pictogrammes).
  - *Refusé / Annulé / Archivé (Inactif):* `#9CA3AF` (Bordures / Éléments désactivés) et `#6B7280` (Texte).
  - *Erreur / Critique:* `#DC2626` pour la validation de formulaires et alertes d'urgence.

## Typography

The typography uses Inter across all viewports to maintain technical precision, legibility under variable light conditions (such as walking a dog outdoors), and tight vertical metrics.

- **Titres & En-têtes:** Rendered in `Inter` semi-bold (600) and bold (700) with slight negative letter tracking (-0.015em) on headings larger than 20px to prevent visual sprawl.
- **Corps de texte:** Standardized at 400 weight with generous line-heights (1.5x) to maintain effortless reading for multi-line pet descriptions, medical histories, and care instructions.
- **Labels, Badges et Actions:** Rendered in 500 and 600 weights to guarantee optical balance at 11px to 14px sizes. Numbers, ages, and chip filters employ clear tabular figures where necessary.

## Layout & Spacing

The layout is built around a mobile-first 4-column grid that expands into an 8-column layout for tablets and 12-column layout for desktop/admin dashboards.

- **Mobile Viewports (< 640px):** 
  - Outer margin: `1rem` (16px).
  - Gutters: `0.75rem` (12px).
  - Single column lists and stacked card flows dominate. Horizontal carousels use edge bleed with `16px` padding snapping.
- **Tablet Viewports (640px - 1024px):** 
  - Outer margin: `1.5rem` (24px).
  - Gutters: `1rem` (16px).
  - Pet grids adopt 2 columns; complex profile pages split into a 1/3 sidebar and 2/3 main feed.
- **Spacing Rhythm:** Based on a strict 4px/8px module:
  - `space-xs` (4px): Micro-gaps between icons and text labels.
  - `space-sm` (8px): Internal chip padding, form field label gaps, tight list item separations.
  - `space-md` (16px): Internal card padding, spacing between stacked inputs.
  - `space-lg` (24px): Card margins and group section spacing.
  - `space-xl` (32px): Primary section header separations and viewport edge offsets.

## Elevation & Depth

Depth is treated with subtle, warm ambient shadows that blend softly into the `#F8FAF9` canvas, avoiding harsh dark drop shadows.

- **Niveau 0 (Surface Plate):** `background: #FFFFFF`, no shadow, optional border `1px solid #E5E7EB` for input containers and structural dividers.
- **Niveau 1 (Cards & Éléments au repos - `shadow-sm`):**
  - `box-shadow: 0 1px 3px 0 rgba(15, 23, 42, 0.04), 0 1px 2px -1px rgba(15, 23, 42, 0.03)`
  - Used for standard pet profile cards, article snippets, and community feed cards.
- **Niveau 2 (Cards interactives / Survol - `shadow-md`):**
  - `box-shadow: 0 4px 6px -1px rgba(15, 118, 110, 0.05), 0 2px 4px -2px rgba(15, 23, 42, 0.05)`
  - Subtle teal tinting in the shadow envelope grounds interactive states when cards are active or tapped.
- **Niveau 3 (Modales, Barres flottantes, Fiches tiroirs):**
  - `box-shadow: 0 10px 15px -3px rgba(15, 23, 42, 0.08), 0 4px 6px -4px rgba(15, 23, 42, 0.03)`
  - Used for bottom sheets (`bottom-sheet-modal`), toast alerts, and floating navigation bars.

## Shapes

The geometric identity relies on friendly, comfortable curves that express comfort without slipping into toy-like bubble aesthetics.

- **Cards & Panneaux principaux:** Strictly `16px` (`rounded-2xl` or `1rem`) corner radius. This balances softness with crisp photography framing.
- **Boutons & Champs de saisie:** `12px` (`rounded-xl` or `0.75rem`) for a tactile, touch-friendly presence on mobile screens.
- **Badges, Pastilles & Chips:** Fully rounded (`rounded-full` / `9999px`) to create clear shape differentiation between interactive chips and rectangular data cards.
- **Photos d'animaux & Avatars:** Avatars are circular (`rounded-full`); pet card thumbnails use `12px` internal radius within `16px` card frames or full top-bleed with `16px` top radii.

## Components

All components are designed with French microcopy and mobile ergonomics in mind (touch targets $\ge 44\text{px}$).

### 1. Boutons (Buttons)
- **Bouton Primaire ("Confirmer", "Adopter", "Prendre rendez-vous"):**
  - Background: `#0F766E`, text: `#FFFFFF`, border-radius: `12px`.
  - Hover/Active: `#115E59`. Focus ring: 2px offset with `#0F766E`.
  - Height: `48px` (mobile standard). Typography: `label-lg`.
- **Bouton Émotion / Coup de Cœur ("Favoris", "Faire un don"):**
  - Background: `#F4A58A`, text: `#1F2937`, border-radius: `12px`.
  - Hover/Active: `#E07A5F`, text: `#FFFFFF`.
- **Bouton Secondaire ("Retour", "Modifier"):**
  - Background: `transparent`, border: `1.5px solid #0F766E`, text: `#0F766E`.
- **Bouton Tertiaire / Neutre ("Passer", "Annuler"):**
  - Background: `transparent`, text: `#6B7280`.

### 2. Cartes d'Animaux (Pet Cards)
- **Structure:** White container (`#FFFFFF`), `16px` border-radius, `shadow-sm`.
- **Image:** 4:3 or 1:1 aspect ratio with top `16px` rounded corners.
- **Contenu:**
  - Nom de l'animal (`headline-sm`, `#1F2937`).
  - Badge de statut positionné en haut à droite en superposition de l'image.
  - Race, âge et distance (`body-sm`, `#6B7280`).
  - Bouton cœur d'action rapide utilisant l'accent corail accessible (`#E07A5F`).

### 3. Badges de Statut (Status Chips)
All status chips use a rounded-full pill format with a subtle background tint and high-contrast text:
- **Disponible / Confirmé:** Background `#D1FAE5`, text `#059669`.
- **En attente / Réservé:** Background `#FEF3C7`, text `#D97706`.
- **Adopté:** Background `#FFF0EB`, text `#E07A5F`.
- **Refusé / Archivé:** Background `#F3F4F6`, text `#6B7280`.

### 4. Chips de Filtrage (Filter Chips)
- **État inactif ("Chiens", "Chats", "Urgences"):** Background `#FFFFFF`, border: `1px solid #E5E7EB`, text: `#1F2937`.
- **État actif:** Background `#0F766E`, text: `#FFFFFF`, border: `1px solid #0F766E`.
- **Padding:** `8px 16px`, height: `36px`.

### 5. Champs de Saisie (Input Fields)
- **Normal:** Background `#FFFFFF`, border: `1px solid #D1D5DB`, radius `12px`, padding `12px 16px`, text `#1F2937`, placeholder `#9CA3AF`.
- **Focus:** Border: `2px solid #0F766E`, outline: none.
- **Erreur:** Border: `2px solid #DC2626`, helper text in `#DC2626` (`body-sm`).

### 6. Listes & Séparateurs (Lists & Dividers)
- List items feature a minimum height of `56px` for touch safety.
- Dividers use `#F3F4F6` with inset margins matching the text start line (skipping avatar width).

### 7. Cases à Cocher & Boutons Radio
- **Taille:** 20x20px with `6px` radius for checkboxes, full circle for radios.
- **Sélectionné:** Fill `#0F766E` with white checkmark/dot.
- **Non sélectionné:** Border `1.5px solid #D1D5DB`, background `#FFFFFF`.

### 8. Barre de Navigation Inférieure (Mobile Bottom Bar)
- Surface: `#FFFFFF` with top border `1px solid #F3F4F6` and elevation `shadow-md`.
- Items: 4 to 5 main sections ("Découvrir", "Communauté", "Mes Animaux", "Messages", "Profil").
- Active tab uses `#0F766E` with micro-dot indicator; inactive uses `#9CA3AF`.