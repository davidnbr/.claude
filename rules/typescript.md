---
description: TypeScript and frontend conventions
paths: ["**/*.ts", "**/*.tsx", "**/*.jsx"]
---

- Strict TypeScript (`"strict": true`); no `any` — use `unknown` + narrowing, discriminated unions, `satisfies` for config objects
- `import type` for type-only imports; explicit return types on exported functions
- Functional components with hooks; derive state during render instead of syncing with `useEffect`
- Server state via TanStack Query (no `useEffect` fetching); global client state via Zustand; local state via `useState`
- Proper loading states, error boundaries, null guards on every async surface
- Semantic HTML first, ARIA only where semantics fall short; keyboard navigation; WCAG 2.2 AA
- Zod (or equivalent) to validate external data at boundaries — API responses, forms, env vars
- React Testing Library / Vitest — test behavior via accessible queries (`getByRole`), not implementation
- Code splitting with `lazy()` + `Suspense` at route boundaries
- No `dangerouslySetInnerHTML` without sanitization (DOMPurify); never interpolate user input into URLs/HTML
